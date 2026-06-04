#!/usr/bin/env python3
"""
psobb_repoint.py
Repoint a PSOBB (Tethealla-lineage) client binary at a different server.

The server hostname/IP in the unpacked Tethealla client is stored as one or
more NUL-terminated ASCII strings inside psobb.exe (and the online.exe
launcher). This tool finds that string and overwrites it in place, NUL-padding
the leftover bytes of the original field so the file length and every other
offset stay identical -- the only safe way to patch a string into a PE binary
without rebuilding it.

Field capacity is measured as the current string PLUS its trailing run of NUL
padding (not just the string length), so a real-world address such as
192.168.1.100 fits where the default "127.0.0.1" used to sit. The write is
capped at --max-len (default 21, the documented width of the Tethealla hostname
fields) so we never overflow the game's fixed-size buffer at runtime, and it
never extends past the trailing NUL run, so the adjacent field is never
clobbered.

Subcommands:
  scan    List address-like strings (IPv4 + hostnames) so you can find the
          current target.
  teth    One-shot: repoint every "127.0.0.1" slot in a stock Tethealla client
          to your server (recommended for the Tethealla TethVer12513 client).
  find    Replace an existing address string with a new one.
  offset  Write a new address at a known byte offset (e.g. 0x56D724).

A .bak copy is written before any modification unless --no-backup is given.

This tool operates on whatever binary YOU supply; it contains no game code.

Examples:
  python3 psobb_repoint.py psobb.exe scan
  python3 psobb_repoint.py psobb.exe --dry-run teth --replace 192.168.1.100
  python3 psobb_repoint.py psobb.exe teth --replace pso.example.net
  python3 psobb_repoint.py online.exe find --find 127.0.0.1 --replace 203.0.113.10
  python3 psobb_repoint.py psobb.exe offset --offset 0x56D724 --replace 10.0.0.5
"""

import argparse
import re
import shutil
import sys
from pathlib import Path

# Tokens that look like hostnames but are really embedded filenames; skip them in scan.
SKIP_SUFFIX = {b"dll", b"exe", b"ini", b"dat", b"bin", b"prs", b"txt",
               b"log", b"sys", b"cfg", b"tmp", b"dmp", b"db"}

# Stock connection address baked into every hostname slot of the unpacked
# Tethealla TethVer12513 client. newserv's Tethealla client ships pointing here.
DEFAULT_TETH_ADDRESS = "127.0.0.1"

# Documented width (bytes, NUL excluded) of each hostname field in the
# Tethealla psobb.exe. The game reads at most this many bytes into a fixed
# buffer, so an address longer than this overflows at runtime even though there
# is more NUL padding physically available. This is the default --max-len.
TETH_FIELD_WIDTH = 21

# The six hostname slots in the Tethealla psobb.exe, by documented offset.
# (Reference / sanity-check data; the 'teth' command discovers slots by value,
# so it still works if a particular build's offsets drift slightly.)
TETHEALLA_HOSTNAME_SLOTS = [
    (0x56D70C, "Database Hostname 1"),
    (0x56D724, "Database Hostname 2"),
    (0x56D750, "Patch Server Hostname 1"),
    (0x56D76C, "Patch Server Hostname 2"),
    (0x56D788, "Patch Server Hostname 3"),
    (0x56D7A4, "Patch Server Hostname 4"),
]

# Byte window the hostname slots live in; used only to flag any stray
# "127.0.0.1" match that lands outside the expected address block.
TETH_REGION_START = 0x56D700
TETH_REGION_END = 0x56D7C0


def make_backup(path):
    bak = Path(str(path) + ".bak")
    if not bak.exists():
        shutil.copy2(path, bak)
        print(f"  backup written: {bak}")
    else:
        print(f"  backup already exists, leaving it untouched: {bak}")


def validate_address(addr):
    if not addr:
        raise ValueError("address is empty")
    b = addr.encode("ascii", "strict")
    if b"\x00" in b:
        raise ValueError("address must not contain NUL bytes")
    if any(c < 0x20 or c > 0x7E for c in b):
        raise ValueError("address must be printable ASCII")
    return b


def find_all(data, needle):
    """Byte offsets of every (possibly overlapping) occurrence of needle."""
    offsets, start = [], 0
    while True:
        i = data.find(needle, start)
        if i == -1:
            break
        offsets.append(i)
        start = i + 1
    return offsets


def string_length_at(data, offset):
    """Length of the NUL-terminated string at offset (NUL excluded)."""
    end = data.find(b"\x00", offset)
    if end == -1:
        raise ValueError(f"no NUL terminator after offset 0x{offset:08X}; refusing")
    return end - offset


def writable_run_at(data, offset):
    """Bytes that can be safely overwritten at offset without shifting any
    meaningful data: the current NUL-terminated string plus the run of NUL
    padding that follows it, stopping at the next non-NUL byte.

    For a stock "127.0.0.1" field this is far larger than 9 -- it spans the
    string and all of its trailing padding -- which is what lets a longer
    address fit in place.
    """
    end = data.find(b"\x00", offset)
    if end == -1:
        raise ValueError(f"no NUL terminator after offset 0x{offset:08X}; refusing")
    i, n = end, len(data)
    while i < n and data[i] == 0:
        i += 1
    return i - offset


def patch_in_place(data, offset, new_bytes, max_len=TETH_FIELD_WIDTH):
    """Overwrite the NUL-padded field at offset with new_bytes.

    The field is rewritten across its entire writable run (string + trailing
    NULs) as new_bytes followed by NUL padding, so no stale tail of the old
    value survives and the file length is unchanged. new_bytes must fit within
    min(writable run, max_len); max_len caps it at the game's fixed buffer size
    (pass max_len=0 to disable the cap and use the full NUL run).
    """
    run = writable_run_at(data, offset)
    limit = min(run, max_len) if max_len else run
    if len(new_bytes) > limit:
        raise ValueError(
            f"new address is {len(new_bytes)} bytes but the field at "
            f"0x{offset:08X} holds at most {limit} "
            f"(NUL-padded run {run}, field cap {max_len or 'none'}). "
            f"Use a shorter hostname or a raw IP so it fits without shifting "
            f"the binary."
        )
    out = bytearray(data)
    out[offset:offset + run] = new_bytes + b"\x00" * (run - len(new_bytes))
    return bytes(out)


def cmd_scan(data, args):
    ipv4 = re.compile(rb"(?<![\d.])((?:\d{1,3}\.){3}\d{1,3})(?![\d.])")
    host = re.compile(rb"([A-Za-z0-9][A-Za-z0-9.\-]{3,253}\.[A-Za-z]{2,24})")
    found = []
    for m in ipv4.finditer(data):
        found.append((m.start(), m.group(1)))
    for m in host.finditer(data):
        val = m.group(1)
        if val.rsplit(b".", 1)[-1].lower() in SKIP_SUFFIX:
            continue
        found.append((m.start(), val))
    found.sort()
    if not found:
        print("No address-like strings found.")
        return
    documented = {off for off, _ in TETHEALLA_HOSTNAME_SLOTS}
    print(f"Found {len(found)} candidate(s):")
    for off, val in found:
        note = ""
        for slot_off, label in TETHEALLA_HOSTNAME_SLOTS:
            if off == slot_off:
                note = f"   <- Tethealla {label}"
                break
        print(f"  0x{off:08X}  {val.decode('ascii', 'replace')}{note}")
    print("\nThe real connection target is usually a NUL-terminated string and")
    print("may appear more than once (database + patch server slots). In a stock")
    print(f"Tethealla client every slot reads '{DEFAULT_TETH_ADDRESS}'; use the 'teth'")
    print("command to repoint them all at once.")
    if not (documented & {off for off, _ in found}):
        print("\nNote: none of the documented Tethealla hostname offsets matched, so")
        print("this may not be a stock TethVer12513 psobb.exe (or it was already")
        print("repointed). Patch by value with 'teth'/'find' rather than 'offset'.")


def cmd_teth(data, args):
    new = validate_address(args.replace)
    if len(new) > TETH_FIELD_WIDTH:
        raise ValueError(
            f"'{args.replace}' is {len(new)} chars; Tethealla hostname fields "
            f"hold at most {TETH_FIELD_WIDTH}. Use a raw IP or a hostname of "
            f"{TETH_FIELD_WIDTH} characters or fewer (or point the client at a "
            f"short name and resolve it to newserv via DNS/hosts)."
        )
    old = DEFAULT_TETH_ADDRESS.encode("ascii")
    matches = find_all(data, old)
    if not matches:
        print(f"No '{DEFAULT_TETH_ADDRESS}' slots found. This may not be a stock")
        print("Tethealla client, or it was already repointed. Run 'scan' to inspect.")
        sys.exit(1)
    print(f"Found {len(matches)} '{DEFAULT_TETH_ADDRESS}' slot(s); "
          f"repointing to '{args.replace}'.")
    out = data
    for off in matches:
        in_region = TETH_REGION_START <= off <= TETH_REGION_END
        tag = "" if in_region else "   [outside documented address region - verify]"
        out = patch_in_place(out, off, new, TETH_FIELD_WIDTH)
        print(f"  0x{off:08X} -> '{args.replace}'{tag}")
    finish(out, args)


def cmd_find(data, args):
    old = validate_address(args.find)
    new = validate_address(args.replace)
    matches = find_all(data, old)
    if not matches:
        print(f"'{args.find}' not found. Run the 'scan' command to see what the")
        print("client currently points at.")
        sys.exit(1)
    print(f"Found '{args.find}' at {len(matches)} location(s).")
    out = data
    for off in matches:
        run = writable_run_at(out, off)
        out = patch_in_place(out, off, new, args.max_len)
        print(f"  0x{off:08X}: '{args.find}' -> '{args.replace}' "
              f"(writable run {run} bytes, cap {args.max_len or 'none'})")
    finish(out, args)


def cmd_offset(data, args):
    new = validate_address(args.replace)
    off = args.offset
    cur_len = string_length_at(data, off)
    current = data[off:off + cur_len].decode("ascii", "replace")
    run = writable_run_at(data, off)
    print(f"  0x{off:08X}: current '{current}' (string {cur_len} bytes, "
          f"writable run {run}) -> '{args.replace}'")
    out = patch_in_place(data, off, new, args.max_len)
    finish(out, args)


def finish(out, args):
    if args.dry_run:
        print("\n[dry-run] no file written.")
        return
    if not args.no_backup:
        make_backup(args.binary)
    Path(args.binary).write_bytes(out)
    print(f"\nWrote patched binary: {args.binary}")


def main():
    p = argparse.ArgumentParser(
        description="Repoint a PSOBB client binary at a new server (safe, in-place).")
    p.add_argument("binary", help="path to psobb.exe / online.exe")
    p.add_argument("--dry-run", action="store_true", help="show changes, write nothing")
    p.add_argument("--no-backup", action="store_true", help="do not write a .bak copy")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("scan", help="list address-like strings in the binary")
    s.set_defaults(func=cmd_scan)

    t = sub.add_parser("teth",
                       help="repoint every stock '127.0.0.1' slot (Tethealla client)")
    t.add_argument("--replace", required=True, help="your server's IP or short hostname")
    t.set_defaults(func=cmd_teth)

    f = sub.add_parser("find", help="replace an existing address string")
    f.add_argument("--find", required=True, help="current address in the binary")
    f.add_argument("--replace", required=True, help="your server's IP or hostname")
    f.add_argument("--max-len", type=int, default=TETH_FIELD_WIDTH,
                   help=f"max bytes to write into each field (default {TETH_FIELD_WIDTH}, "
                        f"0 = no cap)")
    f.set_defaults(func=cmd_find)

    o = sub.add_parser("offset", help="write a new address at a known offset")
    o.add_argument("--offset", required=True, type=lambda x: int(x, 0),
                   help="byte offset, e.g. 0x56D724")
    o.add_argument("--replace", required=True, help="your server's IP or hostname")
    o.add_argument("--max-len", type=int, default=TETH_FIELD_WIDTH,
                   help=f"max bytes to write into the field (default {TETH_FIELD_WIDTH}, "
                        f"0 = no cap)")
    o.set_defaults(func=cmd_offset)

    args = p.parse_args()
    try:
        data = Path(args.binary).read_bytes()
        args.func(data, args)
    except (ValueError, OSError) as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
