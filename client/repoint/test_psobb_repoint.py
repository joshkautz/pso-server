#!/usr/bin/env python3
"""
Tests for psobb_repoint.py.

These build a synthetic binary that mirrors the documented layout of the
Tethealla TethVer12513 psobb.exe -- six "127.0.0.1" hostname slots at their real
offsets, surrounded by non-NUL filler -- so the repoint logic is verified
end-to-end WITHOUT needing the Sega-copyrighted client.

Run directly (no third-party deps):
    python3 scripts/test_psobb_repoint.py
or under pytest:
    pytest scripts/test_psobb_repoint.py
"""

import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import psobb_repoint as mod  # noqa: E402

SCRIPT = HERE / "psobb_repoint.py"

# Documented hostname-slot offsets and the byte window they live in.
SLOTS = [off for off, _ in mod.TETHEALLA_HOSTNAME_SLOTS]
REGION_START = 0x56D700
REGION_END = 0x56D7C0          # first byte of filler after the last slot
FILLER = 0xCC                  # stand-in for real code bytes (int3 padding)
SIZE = REGION_END + 64
STOCK = b"127.0.0.1"

# writable runs implied by the real spacing of the slots (string + trailing
# NULs up to the next non-NUL byte). The last run reaches the filler at
# REGION_END.
EXPECTED_RUNS = {
    0x56D70C: 0x56D724 - 0x56D70C,   # 24
    0x56D724: 0x56D750 - 0x56D724,   # 44
    0x56D750: 0x56D76C - 0x56D750,   # 28
    0x56D76C: 0x56D788 - 0x56D76C,   # 28
    0x56D788: 0x56D7A4 - 0x56D788,   # 28
    0x56D7A4: REGION_END - 0x56D7A4,  # 28
}


def build_teth_binary():
    """A stock-Tethealla-shaped binary: NUL-padded address region holding six
    '127.0.0.1' slots, everything else non-NUL filler."""
    buf = bytearray(bytes([FILLER]) * SIZE)
    for off in range(REGION_START, REGION_END):
        buf[off] = 0
    for off in SLOTS:
        buf[off:off + len(STOCK)] = STOCK
    return buf


def write_temp(tmp_path, data):
    p = tmp_path / "psobb.exe"
    p.write_bytes(bytes(data))
    return p


def run_cli(binary, *args):
    return subprocess.run(
        [sys.executable, str(SCRIPT), str(binary), *args],
        capture_output=True, text=True,
    )


# --- unit tests on the core helpers -----------------------------------------

def test_writable_run_matches_slot_spacing():
    data = bytes(build_teth_binary())
    for off, expected in EXPECTED_RUNS.items():
        assert mod.writable_run_at(data, off) == expected, hex(off)


def test_string_length_is_just_the_string():
    data = bytes(build_teth_binary())
    for off in SLOTS:
        assert mod.string_length_at(data, off) == len(STOCK)


def test_patch_fits_long_address_old_tool_would_reject():
    """13-char IP into a 9-char '127.0.0.1' slot: the whole point of the fix."""
    data = bytes(build_teth_binary())
    off = 0x56D724
    new = b"192.168.1.100"  # 13 bytes > len("127.0.0.1")
    out = mod.patch_in_place(data, off, new)
    assert len(out) == len(data)
    assert out[off:off + len(new)] == new
    assert out[off + len(new)] == 0                       # NUL-terminated
    assert out[0x56D750:0x56D750 + len(STOCK)] == STOCK   # next slot untouched
    assert out[REGION_END] == FILLER                      # filler untouched


def test_patch_clears_stale_tail_when_new_is_shorter():
    data = bytes(build_teth_binary())
    off = 0x56D724
    out = mod.patch_in_place(data, off, b"1.2.3.4")  # 7 bytes < 9
    run = EXPECTED_RUNS[off]
    assert out[off:off + 7] == b"1.2.3.4"
    assert out[off + 7:off + run] == b"\x00" * (run - 7)  # no "0.1" remnant


def test_patch_refuses_address_over_field_cap():
    data = bytes(build_teth_binary())
    too_long = b"x" * (mod.TETH_FIELD_WIDTH + 1)  # 22 bytes, cap is 21
    try:
        mod.patch_in_place(data, 0x56D724, too_long)
        assert False, "expected ValueError for over-cap address"
    except ValueError as e:
        assert "holds at most" in str(e)


def test_patch_refuses_when_run_too_small_even_without_cap():
    # "127.0.0.1\0" then non-NUL filler -> writable run is only 10.
    data = STOCK + b"\x00" + bytes([FILLER]) * 16
    try:
        mod.patch_in_place(data, 0, b"this.is.way.too.long", max_len=0)
        assert False, "expected ValueError when address exceeds the NUL run"
    except ValueError as e:
        assert "run" in str(e)


def test_max_len_cap_can_be_disabled():
    data = bytes(build_teth_binary())
    off = 0x56D724  # run is 44, so up to 44 bytes are writable with cap off
    new = b"a" * 30
    out = mod.patch_in_place(data, off, new, max_len=0)
    assert out[off:off + 30] == new
    assert len(out) == len(data)


def test_validate_address_rejects_bad_input():
    for bad in ["", "has space\tweird"]:
        try:
            mod.validate_address(bad)
            assert False, f"expected rejection of {bad!r}"
        except ValueError:
            pass
    assert mod.validate_address("10.0.0.5") == b"10.0.0.5"


# --- end-to-end CLI tests ----------------------------------------------------

def _patched_all_slots(binary_path, addr):
    out = binary_path.read_bytes()
    abytes = addr.encode()
    for off in SLOTS:
        if out[off:off + len(abytes)] != abytes or out[off + len(abytes)] != 0:
            return False
    return True


def test_cli_teth_repoints_every_slot(tmp_path):
    binary = write_temp(tmp_path, build_teth_binary())
    original_len = binary.stat().st_size
    r = run_cli(binary, "teth", "--replace", "192.168.1.100")
    assert r.returncode == 0, r.stderr
    assert _patched_all_slots(binary, "192.168.1.100")
    assert binary.stat().st_size == original_len
    assert (tmp_path / "psobb.exe.bak").exists()         # backup made
    # filler immediately after the region is preserved
    assert binary.read_bytes()[REGION_END] == FILLER


def test_cli_dry_run_writes_nothing(tmp_path):
    binary = write_temp(tmp_path, build_teth_binary())
    before = binary.read_bytes()
    r = run_cli(binary, "--dry-run", "teth", "--replace", "10.0.0.5")
    assert r.returncode == 0, r.stderr
    assert binary.read_bytes() == before
    assert not (tmp_path / "psobb.exe.bak").exists()


def test_cli_teth_rejects_oversize_hostname(tmp_path):
    binary = write_temp(tmp_path, build_teth_binary())
    before = binary.read_bytes()
    r = run_cli(binary, "teth", "--replace", "this-name-is-way-too-long.example.com")
    assert r.returncode != 0
    assert "hold at most" in (r.stderr + r.stdout)
    assert binary.read_bytes() == before                 # untouched on failure


def test_cli_find_handles_address_longer_than_default(tmp_path):
    binary = write_temp(tmp_path, build_teth_binary())
    r = run_cli(binary, "find", "--find", "127.0.0.1", "--replace", "192.168.1.100")
    assert r.returncode == 0, r.stderr
    assert _patched_all_slots(binary, "192.168.1.100")


def test_cli_offset_targets_documented_slot(tmp_path):
    binary = write_temp(tmp_path, build_teth_binary())
    r = run_cli(binary, "offset", "--offset", "0x56D724", "--replace", "10.0.0.5")
    assert r.returncode == 0, r.stderr
    out = binary.read_bytes()
    assert out[0x56D724:0x56D724 + 8] == b"10.0.0.5"
    assert out[0x56D70C:0x56D70C + len(STOCK)] == STOCK  # other slots left alone


def test_cli_scan_finds_and_labels_slots(tmp_path):
    binary = write_temp(tmp_path, build_teth_binary())
    r = run_cli(binary, "scan")
    assert r.returncode == 0, r.stderr
    assert "127.0.0.1" in r.stdout
    assert "Database Hostname 2" in r.stdout               # offset label printed


def _main():
    import tempfile
    tests = [(n, o) for n, o in sorted(globals().items())
             if n.startswith("test_") and callable(o)]
    failures = 0
    for name, fn in tests:
        try:
            if "tmp_path" in fn.__code__.co_varnames[:fn.__code__.co_argcount]:
                with tempfile.TemporaryDirectory() as d:
                    fn(Path(d))
            else:
                fn()
            print(f"  PASS  {name}")
        except Exception as e:  # noqa: BLE001 - test runner surfaces everything
            failures += 1
            print(f"  FAIL  {name}: {e}")
    total = len(tests)
    print(f"\n{total - failures}/{total} passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(_main())
