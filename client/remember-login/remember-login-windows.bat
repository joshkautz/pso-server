@echo off
setlocal EnableDelayedExpansion
REM ============================================================
REM  Remember my PSO Blue Burst login (Windows)
REM
REM  Pre-fills the UserID + password on the client's login
REM  screen so you don't retype them every launch. Writes three
REM  values under HKCU\Software\SonicTeam\PSOBB (the same keys the
REM  client itself uses). Re-run any time to change them.
REM ============================================================
echo.
echo   PSO Blue Burst - remember my login
echo   -----------------------------------
echo   Enter the UserID and password the admin gave you.
echo.

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
set "PASSWD="
set /p "PASSWD=  Password: "
if "!PASSWD!"=="" (echo   No password entered - aborting.& pause& exit /b 1)

reg add "HKCU\Software\SonicTeam\PSOBB" /v ACCOUNT       /t REG_SZ    /d "!USERID!" /f >nul
reg add "HKCU\Software\SonicTeam\PSOBB" /v PASSWORD      /t REG_SZ    /d "!PASSWD!" /f >nul
reg add "HKCU\Software\SonicTeam\PSOBB" /v ACCOUNT_CHECK /t REG_DWORD /d 1          /f >nul

echo.
echo   Done. Launch Psobb.exe - your login will be pre-filled.
echo.
pause
