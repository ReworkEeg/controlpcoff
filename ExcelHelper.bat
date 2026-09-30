@echo off
:: language: batch, file: detach_host.bat, run: double-click (user) - auto-elevates via UAC
:: *watch - unjoin domain + sc delete require admin; script self-elevates through UAC*
:: *save as ANSI or OEM 866 (cp866). Do NOT save with UTF-8 BOM - it breaks the first line*
title mad_whitether69
setlocal EnableExtensions EnableDelayedExpansion

:: ============================================================
::   BANNER
:: ============================================================
cls
echo.
echo                        _        _                      _ _   _                __   ___
echo   _ __ ___   __ _  __^| ^| ___  ^| ^|__  _   _  __      _(_) ^|_^| ^|__   ___ _ __ / /_ / _ \
echo  ^| '_ ` _ \ / _` ^|/ _` ^|/ _ \ ^| '_ \^| ^| ^| ^| \ \ /\ / / ^| __^| '_ \ / _ \ '__^| '_ \ (_) ^|
echo  ^| ^| ^| ^| ^| ^| (_^| ^| (_^| ^|  __/ ^| ^|_) ^| ^|_^| ^|  \ V  V /^| ^| ^|_^| ^| ^| ^|  __/ ^|  ^| (_) \__, ^|
echo  ^|_^| ^|_^| ^|_^|\__,_^|\__,_^|\___^| ^|_.__/ \__, ^|   \_/\_/ ^|_^|\__^|_^| ^|_^|\___^|_^|   \___/  /_/
echo                                      ^|___/
echo.
echo  ==============================================================
echo    DETACH HOST - cut this machine from its managing host
echo  ==============================================================
echo.

:: ============================================================
::   MENU
:: ============================================================
:MENU
echo   ----------------------------------------------
echo    SELECT MODE
echo   ----------------------------------------------
echo    1  Quiet        - user layer only (no admin, no beeps)
echo    2  Full         - user + system (needs UAC)
echo    3  Dry-run      - show what WOULD be done, no changes
echo    4  Revert       - re-enable telemetry services and rejoin-friendly state
echo    5  Exit
echo   ----------------------------------------------
set "MODE="
set /p "MODE=  choice [1-5]: "
if not defined MODE goto :MENU
if "%MODE%"=="1" goto :QUIET
if "%MODE%"=="2" goto :FULL
if "%MODE%"=="3" goto :DRYRUN
if "%MODE%"=="4" goto :REVERT
if "%MODE%"=="5" goto :EXIT
echo   [!] not 1-5, try again.
echo.
goto :MENU

:: ============================================================
::   PRIVILEGE CHECK (shared)
:: ============================================================
:CHECK_ADMIN
net session >nul 2>&1
if errorlevel 1 (
  set "IS_ADMIN=0"
) else (
  set "IS_ADMIN=1"
)
exit /b 0

:: ============================================================
::   MODE 1: QUIET - user layer only
:: ============================================================
:QUIET
call :CHECK_ADMIN
echo.
echo [*] mode: QUIET (user layer only)
echo.
call :USER_LAYER
echo.
echo [*] quiet mode done. system services untouched.
echo.
pause
goto :MENU

:: ============================================================
::   MODE 2: FULL - user + system, self-elevate
:: ============================================================
:FULL
call :CHECK_ADMIN
echo.
echo [*] mode: FULL
echo.
call :USER_LAYER

if "%IS_ADMIN%"=="1" (
  echo [*] already admin - running system layer...
  call :SYSTEM_LAYER
  goto :FULL_DONE
)

echo ==============================================================
echo   FULL DETACH NEEDS ADMIN (UAC)
echo   A prompt will appear - click "Yes".
echo ==============================================================
echo.
call :ASK_ELEVATE
if "%ANSWER%"=="N" goto :FULL_USERONLY

powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
goto :EXIT

:FULL_USERONLY
echo [!] UAC declined. user layer kept. system services untouched.
goto :FULL_DONE

:FULL_DONE
echo.
echo [*] full mode done. reboot in 15 sec to apply. cancel: shutdown /a
shutdown /r /t 15 /c "detach_host: reboot to apply"
goto :EXIT

:: ============================================================
::   MODE 3: DRY-RUN - no changes, just prints
:: ============================================================
:DRYRUN
echo.
echo [*] mode: DRY-RUN - nothing will be changed.
echo.
echo   WOULD do (user layer):
echo     - net use * /delete
echo     - taskkill AnyDesk, RustDesk, TeamViewer, ScreenConnect, Atera, ...
echo     - reg delete HKCU\...\Run entries for RMM
echo     - schtasks /delete for RMM tasks
echo     - taskkill OneDrive, Teams
echo.
echo   WOULD do (system layer, needs admin):
echo     - wmic ... unjoindomainorreworkgroup
echo     - sc stop/config disabled/delete for RMM services
echo     - sc stop/config disabled for DiagTrack, dmwappushservice, WerSvc
echo     - reg add HKLM ... AllowTelemetry = 0
echo     - sc stop/config disabled for CcmExec, smstsmgr, IntuneManagementExtension, MicrosoftMonitoringAgent
echo     - reg add HKLM ... NoAutoUpdate = 1
echo     - wevtutil cl System
echo     - shutdown /r /t 15
echo.
pause
goto :MENU

:: ============================================================
::   MODE 4: REVERT - put services back to auto
:: ============================================================
:REVERT
call :CHECK_ADMIN
echo.
echo [*] mode: REVERT
if "%IS_ADMIN%"=="0" (
  echo [!] revert needs admin. relaunching via UAC...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  goto :EXIT
)
echo [*] re-enabling telemetry services...
sc config DiagTrack start= auto >nul 2>&1
sc start DiagTrack >nul 2>&1
sc config dmwappushservice start= auto >nul 2>&1
sc start dmwappushservice >nul 2>&1
sc config WerSvc start= demand >nul 2>&1
sc config CcmExec start= auto >nul 2>&1
sc config smstsmgr start= auto >nul 2>&1
sc config IntuneManagementExtension start= auto >nul 2>&1
sc config MicrosoftMonitoringAgent start= auto >nul 2>&1
echo [*] re-enabling Windows Update...
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /f >nul 2>&1
echo [*] telemetry policy to default...
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /f >nul 2>&1
echo [*] re-enabling OneDrive autostart entry placeholder...
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /t REG_SZ /d "\"%%LOCALAPPDATA%%\Microsoft\OneDrive\OneDrive.exe\" /background" /f >nul 2>&1
echo [*] revert done. RMM agents you deleted must be reinstalled manually.
echo.
pause
goto :MENU

:: ============================================================
::   ASK (fixed - no beep, loops on bad key)
:: ============================================================
:ASK_ELEVATE
set "ANSWER="
:ASK_ELEVATE_LOOP
choice /c YN /n /m "  elevate? [Y/N]: "
if errorlevel 2 (
  set "ANSWER=N"
  exit /b 0
)
if errorlevel 1 (
  set "ANSWER=Y"
  exit /b 0
)
goto :ASK_ELEVATE_LOOP

:: ============================================================
::   USER LAYER (unchanged logic)
:: ============================================================
:USER_LAYER
echo [*] 1/6 user: dropping network shares to host...
net use * /delete /y >nul 2>&1

echo [*] 2/6 user: killing RMM and telemetry processes...
for %%P in (
  AnyDesk.exe RustDesk.exe TeamViewer.exe tv_w32.exe tv_x64.exe
  ScreenConnect.ClientService.exe ScreenConnect.WindowsClient.exe
  AteraAgent.exe SplashtopStreamer.exe LogMeIn.exe GoToAssist.exe
  NinjaRMMAgent.exe MeshAgent.exe TacticalAgent.exe AWAgent.exe
  ZohoMeeting.exe OneDrive.exe Teams.exe
) do taskkill /f /im %%P >nul 2>&1

echo [*] 3/6 user: cleaning user autostart entries...
for /f "tokens=*" %%V in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" 2^>nul ^| findstr /i "AnyDesk RustDesk TeamViewer ScreenConnect Atera Splashtop LogMeIn GoToAssist NinjaRMM Mesh Tactical AWAgent Zoho"') do (
  set "LINE=%%V"
  for /f "tokens=1" %%K in ("!LINE!") do reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "%%K" /f >nul 2>&1
)
for /f "tokens=*" %%V in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce" 2^>nul ^| findstr /i "AnyDesk RustDesk TeamViewer ScreenConnect Atera Splashtop LogMeIn"') do (
  set "LINE=%%V"
  for /f "tokens=1" %%K in ("!LINE!") do reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v "%%K" /f >nul 2>&1
)

echo [*] 4/6 user: killing user scheduled tasks...
for /f "tokens=*" %%T in ('schtasks /query /fo LIST 2^>nul ^| findstr /i "AnyDesk TeamViewer ScreenConnect Atera Splashtop LogMeIn NinjaRMM Mesh Tactical"') do (
  schtasks /end /tn "%%T" >nul 2>&1
  schtasks /delete /tn "%%T" /f >nul 2>&1
)

echo [*] 5/6 user: killing OneDrive and Teams sync...
taskkill /f /im OneDrive.exe >nul 2>&1
taskkill /f /im Teams.exe >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /t REG_SZ /d "" /f >nul 2>&1

echo [*] 6/6 user: done.
exit /b 0

:: ============================================================
::   SYSTEM LAYER (admin)
:: ============================================================
:SYSTEM_LAYER
echo [*] 1/7 admin: unjoining domain...
wmic computersystem where "name='%COMPUTERNAME%'" call unjoindomainorreworkgroup >nul 2>&1

echo [*] 2/7 admin: stopping and deleting RMM services...
for %%S in (
  "ScreenConnect Client" "ScreenConnect Client (.*)" AteraAgent "Splashtop*"
  TeamViewer LogMeIn "GoToAssist*" RManService KaseyaAgent NinjaRMMAgent
  "Datto*" "TacticalRMM*" "Mesh Agent" "ConnectWiseControl*" AWAgent
  "ZohoMeeting*" AnyDesk RustDesk
) do (
  sc stop %%S >nul 2>&1
  sc config %%S start= disabled >nul 2>&1
  sc delete %%S >nul 2>&1
)

echo [*] 3/7 admin: Windows telemetry...
sc stop DiagTrack >nul 2>&1
sc config DiagTrack start= disabled >nul 2>&1
sc stop dmwappushservice >nul 2>&1
sc config dmwappushservice start= disabled >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
sc stop WerSvc >nul 2>&1
sc config WerSvc start= disabled >nul 2>&1

echo [*] 4/7 admin: SCCM / Intune / SCOM clients...
sc stop CcmExec >nul 2>&1
sc config CcmExec start= disabled >nul 2>&1
sc stop smstsmgr >nul 2>&1
sc config smstsmgr start= disabled >nul 2>&1
sc stop IntuneManagementExtension >nul 2>&1
sc config IntuneManagementExtension start= disabled >nul 2>&1
sc stop MicrosoftMonitoringAgent >nul 2>&1
sc config MicrosoftMonitoringAgent start= disabled >nul 2>&1

echo [*] 5/7 admin: WSUS and auto-update from host...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f >nul 2>&1

echo [*] 6/7 admin: clearing System log (sc delete traces)...
wevtutil cl System >nul 2>&1

echo [*] 7/7 admin: done.
exit /b 0

:: ============================================================
:EXIT
endlocal
exit /b 0
