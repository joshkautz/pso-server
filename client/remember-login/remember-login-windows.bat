@echo off
REM Remember your PSO Blue Burst login (UserID + password) on Windows.
REM This just runs remember-login.py (which does the work and needs Python 3).
cd /d "%~dp0"
where py >nul 2>&1 && ( py remember-login.py & goto :eof )
where python >nul 2>&1 && ( python remember-login.py & goto :eof )
echo.
echo   This helper needs Python 3 to save your password.
echo   Easiest fix: ask the admin for your personal login file (yourname.reg)
echo   and double-click that instead.
echo   Or install Python 3 from https://www.python.org/ and re-run.
echo.
pause
