#!/usr/bin/env python3
r"""
remember-login.py - bake your PSO Blue Burst UserID + password into the client so
the login screen pre-fills BOTH every launch.

The password is stored exactly the way the game stores it: a 48-byte REG_BINARY
value under HKCU\Software\SonicTeam\PSOBB\PASSWORD, equal to the password run
through PSOBB's custom 4-round Blowfish keyed by the UserID. That cipher was
reverse-engineered from Psobb.exe; its constant tables are embedded below, so this
script is fully self-contained (no game files, no dependencies beyond Python 3).

USAGE
  python3 remember-login.py
        Interactive: asks for your UserID + password and writes them into your
        local install (the PSOBB.app Wine registry on macOS, or the Windows
        registry).

  python3 remember-login.py --emit USERID PASSWORD [OUTDIR]
        Admin helper: writes two ready-to-use files a friend can run with NO
        dependencies -
          USERID.reg            (Windows: double-click to import)
          USERID-macos.command  (macOS: double-click to apply to PSOBB.app)
        Hand these to the player privately (they encode the password).
"""
import base64, struct, sys, os, glob, subprocess, platform, time

# --- BB cipher constant tables (P-array + S-boxes, extracted from Psobb.exe) ---
_TABLES_B64 = (
"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"
)
MASK = 0xFFFFFFFF
BLOCK_LEN = 0x30  # 48 bytes


def _tables():
    raw = base64.b64decode(_TABLES_B64)
    P = list(struct.unpack_from('<18I', raw, 0))
    S = [list(struct.unpack_from('<256I', raw, 72 + i * 1024)) for i in range(4)]
    return P, S


def _swap16(w):
    return ((w & 0xFF) << 8) | ((w >> 8) & 0xFF)


class _Cipher:
    """PSOBB saved-password cipher (BB Blowfish; 16-round key schedule, 4-round encrypt)."""

    def __init__(self, key: bytes):
        P, S = _tables()
        self.p = list(P)
        for i in range(18):
            T = self.p[i]
            plo = _swap16(T & 0xFFFF)
            phi = (((T >> 16) & 0xFFFF) ^ plo) & 0xFFFF
            self.p[i] = ((phi << 16) | plo) & MASK
        self.s = [list(S[b]) for b in range(4)]
        L = len(key)
        for i in range(18):
            k = ((key[(i * 4 + 3) % L]) |
                 (key[(i * 4 + 2) % L] << 8) |
                 (key[(i * 4 + 1) % L] << 16) |
                 (key[(i * 4 + 0) % L] << 24)) & MASK
            self.p[i] ^= k
        v1 = v2 = 0
        for i in range(0, 18, 2):
            v1, v2 = self._ib(v1, v2)
            self.p[i] = v1
            self.p[i + 1] = v2
        for b in range(4):
            for j in range(0, 256, 2):
                v1, v2 = self._ib(v1, v2)
                self.s[b][j] = v1
                self.s[b][j + 1] = v2

    def _F(self, x):
        x &= MASK
        e = self.s[0][(x >> 24) & 0xFF]
        e = (e + self.s[1][(x >> 16) & 0xFF]) & MASK
        e ^= self.s[2][(x >> 8) & 0xFF]
        e = (e + self.s[3][x & 0xFF]) & MASK
        return e

    def _ib(self, L, R):  # 16-round key-schedule block
        for i in range(0, 16, 2):
            L ^= self.p[i]
            R = (R ^ self._F(L)) & MASK
            R ^= self.p[i + 1]
            L = (L ^ self._F(R)) & MASK
        L ^= self.p[16]
        R ^= self.p[17]
        return R & MASK, L & MASK

    def _eb(self, L, R):  # 4-round encrypt block
        for i in range(4):
            L ^= self.p[i]
            R = (R ^ self._F(L)) & MASK
            L, R = R, L
        L, R = R, L
        R ^= self.p[4]
        L ^= self.p[5]
        return L & MASK, R & MASK

    def encrypt(self, buf: bytes) -> bytes:
        out = bytearray()
        for i in range(0, len(buf), 8):
            L, R = struct.unpack_from('<II', buf, i)
            L, R = self._eb(L, R)
            out += struct.pack('<II', L, R)
        return bytes(out)


def password_blob(user_id: str, password: str) -> bytes:
    """The exact 48-byte REG_BINARY value the game stores for this UserID+password."""
    key = user_id.encode('ascii').ljust(BLOCK_LEN, b'\0')[:BLOCK_LEN]
    pt = password.encode('ascii').ljust(BLOCK_LEN, b'\0')[:BLOCK_LEN]
    return _Cipher(key).encrypt(pt)


def _validate(user_id, password):
    user_id.encode('ascii'); password.encode('ascii')  # raise on non-ASCII
    if not user_id or not password:
        raise SystemExit("UserID and password must both be non-empty.")
    if len(user_id) > 16 or len(password) > 16:
        raise SystemExit("UserID and password are max 16 characters each.")


# ---------- macOS: edit the PSOBB.app Wine registry ----------

def _find_app():
    for c in [os.path.expanduser("~/Applications/Sikarugir/PSOBB.app"),
              "/Applications/PSOBB.app",
              os.path.expanduser("~/Applications/PSOBB.app"),
              os.path.expanduser("~/Desktop/PSOBB.app")]:
        if os.path.isdir(c):
            return c
    return None


def _edit_user_reg(reg_path, user_id, blob):
    """Set ACCOUNT / ACCOUNT_CHECK / PASSWORD in a Wine user.reg, in place."""
    hexcsv = ",".join("%02x" % b for b in blob)
    lines = open(reg_path, "r", encoding="utf-8", errors="surrogateescape").read().split("\n")
    out, inblk, seen = [], False, {"a": False, "c": False, "p": False}

    def flush():
        if inblk:
            if not seen["a"]: out.append('"ACCOUNT"="%s"' % user_id)
            if not seen["c"]: out.append('"ACCOUNT_CHECK"=dword:00000001')
            if not seen["p"]: out.append('"PASSWORD"=hex:%s' % hexcsv)

    for ln in lines:
        if ln.strip() == "" and inblk:
            flush(); inblk = False; out.append(ln); continue
        if ln.startswith("["):
            inblk = ("SonicTeam" in ln and "PSOBB" in ln)
            seen = {"a": False, "c": False, "p": False}
            out.append(ln); continue
        if inblk and ln.startswith('"ACCOUNT"='):
            out.append('"ACCOUNT"="%s"' % user_id); seen["a"] = True; continue
        if inblk and ln.startswith('"ACCOUNT_CHECK"='):
            out.append('"ACCOUNT_CHECK"=dword:00000001'); seen["c"] = True; continue
        if inblk and ln.startswith('"PASSWORD"='):
            out.append('"PASSWORD"=hex:%s' % hexcsv); seen["p"] = True; continue
        out.append(ln)
    if inblk:
        flush()
    open(reg_path, "w", encoding="utf-8", errors="surrogateescape").write("\n".join(out))


def _apply_macos(user_id, password):
    app = _find_app()
    if not app:
        app = input("  Couldn't find PSOBB.app - drag it here and press Enter: ").strip().strip('"').rstrip("/")
        app = os.path.expanduser(app)
    reg = os.path.join(app, "Contents/SharedSupport/prefix/user.reg")
    if not os.path.isfile(reg):
        raise SystemExit("  Not a PSOBB.app I recognize (no Wine registry at %s)" % reg)
    if subprocess.run(["pgrep", "-if", "Psobb.exe"], capture_output=True).returncode == 0:
        raise SystemExit("  PSOBB is running. Close the game window first, then re-run.")
    import shutil
    shutil.copy(reg, reg + ".bak-" + time.strftime("%Y%m%d%H%M%S"))
    _edit_user_reg(reg, user_id, password_blob(user_id, password))
    print("  Done. UserID and password will be pre-filled at the login screen.")


# ---------- Windows: write the registry directly ----------

def _apply_windows(user_id, password):
    blob = password_blob(user_id, password)
    key = r"HKCU\Software\SonicTeam\PSOBB"
    subprocess.run(["reg", "add", key, "/v", "ACCOUNT", "/t", "REG_SZ", "/d", user_id, "/f"], check=True)
    subprocess.run(["reg", "add", key, "/v", "ACCOUNT_CHECK", "/t", "REG_DWORD", "/d", "1", "/f"], check=True)
    subprocess.run(["reg", "add", key, "/v", "PASSWORD", "/t", "REG_BINARY", "/d", blob.hex(), "/f"], check=True)
    print("  Done. UserID and password will be pre-filled at the login screen.")


# ---------- admin: emit zero-dependency artifacts ----------

def _emit(user_id, password, outdir="."):
    _validate(user_id, password)
    blob = password_blob(user_id, password)
    hexcsv = ",".join("%02x" % b for b in blob)
    reg_path = os.path.join(outdir, user_id + ".reg")
    with open(reg_path, "w", newline="\r\n") as f:
        f.write("Windows Registry Editor Version 5.00\r\n\r\n"
                "[HKEY_CURRENT_USER\\Software\\SonicTeam\\PSOBB]\r\n"
                '"ACCOUNT"="%s"\r\n' % user_id +
                '"ACCOUNT_CHECK"=dword:00000001\r\n'
                '"PASSWORD"=hex:%s\r\n' % hexcsv)
    cmd_path = os.path.join(outdir, user_id + "-macos.command")
    with open(cmd_path, "w") as f:
        f.write("#!/usr/bin/env bash\n"
                "# Pre-fills the PSO Blue Burst login for %s. Double-click to apply.\n" % user_id +
                "set -euo pipefail\n"
                'UID_=%r; HEX=%r\n' % (user_id, hexcsv) +
                'APP=""\n'
                'for c in "$HOME/Applications/Sikarugir/PSOBB.app" "/Applications/PSOBB.app" "$HOME/Applications/PSOBB.app" "$HOME/Desktop/PSOBB.app"; do [ -d "$c" ] && { APP="$c"; break; }; done\n'
                '[ -n "$APP" ] || { read -r -p "Drag PSOBB.app here and press Enter: " APP; APP="${APP%%\\\"}"; APP="${APP#\\\"}"; APP="${APP%%/}"; APP="${APP/#\\~/$HOME}"; }\n'
                'REG="$APP/Contents/SharedSupport/prefix/user.reg"\n'
                '[ -f "$REG" ] || { echo "No Wine registry at $REG"; exit 1; }\n'
                'pgrep -if "Psobb.exe" >/dev/null 2>&1 && { echo "Close PSOBB first."; exit 1; }\n'
                'cp "$REG" "$REG.bak-$(date +%%Y%%m%%d%%H%%M%%S)"\n'
                "awk -v U=\"$UID_\" -v H=\"$HEX\" '\n"
                '  function flush(){ if(inblk){ if(!a)print "\\"ACCOUNT\\"=\\"" U "\\""; if(!c)print "\\"ACCOUNT_CHECK\\"=dword:00000001"; if(!p)print "\\"PASSWORD\\"=hex:" H } }\n'
                '  /^[ \\t]*$/        { if(inblk){ flush(); inblk=0 } print; next }\n'
                '  /^\\[/             { inblk=($0 ~ /SonicTeam.*PSOBB/)?1:0; a=0;c=0;p=0; print; next }\n'
                '  inblk && /^"ACCOUNT"=/       { print "\\"ACCOUNT\\"=\\"" U "\\"";            a=1; next }\n'
                '  inblk && /^"ACCOUNT_CHECK"=/ { print "\\"ACCOUNT_CHECK\\"=dword:00000001"; c=1; next }\n'
                '  inblk && /^"PASSWORD"=/      { print "\\"PASSWORD\\"=hex:" H;               p=1; next }\n'
                '                    { print }\n'
                "  END               { flush() }\n"
                "' \"$REG\" > \"$REG.new\" && mv \"$REG.new\" \"$REG\"\n"
                'echo "Done - launch PSOBB; your UserID and password are pre-filled."\n')
    os.chmod(cmd_path, 0o755)
    print("Wrote:\n  %s\n  %s" % (reg_path, cmd_path))


def main(argv):
    if len(argv) >= 2 and argv[1] == "--emit":
        if len(argv) < 4:
            raise SystemExit("usage: remember-login.py --emit USERID PASSWORD [OUTDIR]")
        _emit(argv[2], argv[3], argv[4] if len(argv) > 4 else ".")
        return
    print("  PSO Blue Burst - remember my login")
    print("  -----------------------------------")
    try:
        import getpass
        user_id = input("  UserID: ").strip()
        password = getpass.getpass("  Password: ")
    except (EOFError, KeyboardInterrupt):
        raise SystemExit("\n  aborted.")
    _validate(user_id, password)
    sysname = platform.system()
    if sysname == "Darwin":
        _apply_macos(user_id, password)
    elif sysname == "Windows":
        _apply_windows(user_id, password)
    else:
        raise SystemExit("  Unsupported OS %r - use --emit and apply the file manually." % sysname)


if __name__ == "__main__":
    main(sys.argv)
