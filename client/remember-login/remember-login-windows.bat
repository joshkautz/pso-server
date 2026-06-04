@echo off
setlocal EnableDelayedExpansion
REM ============================================================
REM  Remember my PSO Blue Burst UserID (Windows)
REM
REM  Saves your UserID so the login screen pre-fills it every
REM  launch. PSO stores the password separately and *encrypted*
REM  (the game's launcher sets it, not a plain registry value),
REM  so a script can't bake it in - type it once each session, or
REM  enable save-password in the launcher. See README.md.
REM ============================================================
echo.
echo   PSO Blue Burst - remember my UserID
echo   ------------------------------------

REM The client rewrites these keys on exit, so it must be closed.
tasklist /fi "imagename eq Psobb.exe" 2>nul | find /i "Psobb.exe" >nul
if not errorlevel 1 (
  echo   ERROR: Psobb.exe is running. Close the game first, then re-run.
  echo.
  pause
  exit /b 1
)

set "USERID="
set /p "USERID=  UserID: "
if "!USERID!"=="" (echo   No UserID entered - aborting.& pause& exit /b 1)

reg add "HKCU\Software\SonicTeam\PSOBB" /v ACCOUNT       /t REG_SZ    /d "!USERID!" /f >nul
reg add "HKCU\Software\SonicTeam\PSOBB" /v ACCOUNT_CHECK /t REG_DWORD /d 1          /f >nul

echo.
echo   Done. Your UserID will be pre-filled at the login screen.
echo   Type your password once each session (or enable save-password in the launcher).
echo.
pause
