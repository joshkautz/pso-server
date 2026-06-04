#!/usr/bin/env bash
# Remember your PSO Blue Burst login (UserID + password) on macOS.
# This just runs remember-login.py (which does the work and needs Python 3).
cd "$(dirname "$0")"
if command -v python3 >/dev/null 2>&1; then
  python3 remember-login.py
else
  echo
  echo "  This helper needs Python 3 to save your password."
  echo "  Easiest fix: ask the admin for your personal login file"
  echo "  (yourname-macos.command) and double-click that instead."
  echo "  Or install Python 3 from https://www.python.org/ and re-run."
  echo
  read -r -p "  Press Enter to close. "
fi
