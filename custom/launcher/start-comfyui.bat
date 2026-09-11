@echo off
setlocal EnableExtensions EnableDelayedExpansion
title ComfyUI Launcher

rem ============================================================
rem  ComfyUI launcher - entry point
rem    checks the repo and the port, then either opens the app window
rem    or starts the backend console which pulls updates and runs the server
rem
rem  IMPORTANT - keep this file pure ASCII and keep the redirection characters
rem  out of rem/echo TEXT. cmd parses them as redirection even inside rem and
rem  echo, and a non-ASCII batch file breaks when the console code page is not
rem  the one it was saved in. ASCII keeps it working under any code page.
rem ============================================================

rem ---- port, override with COMFY_PORT ----
set "PORT=%COMFY_PORT%"
if not defined PORT set "PORT=8188"
set "URL=http://127.0.0.1:%PORT%"

rem ---- repo root is two levels above this script: repo\custom\launcher\ ----
for %%I in ("%~dp0..\..") do set "APP_DIR=%%~fI"
if defined COMFY_APP_DIR set "APP_DIR=%COMFY_APP_DIR%"
for %%I in ("%~dp0.") do set "LAUNCHER_DIR=%%~fI"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if not exist "%APP_DIR%\main.py" (
  echo [ERROR] ComfyUI repo root not found: "%APP_DIR%"
  echo         Keep this script at repo\custom\launcher\, or set COMFY_APP_DIR.
  echo         Script location: %LAUNCHER_DIR%
  echo.
  pause
  exit /b 1
)

rem ---- is the port already listening? then just open the app window ----
set "IS_RUNNING=0"
if exist "%PS%" (
  "%PS%" -NoProfile -NonInteractive -Command "if (Get-NetTCPConnection -State Listen -LocalPort %PORT% -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }" >nul 2>nul
  if not errorlevel 1 set "IS_RUNNING=1"
)
if "%IS_RUNNING%"=="0" (
  netstat -ano | findstr /c:":%PORT% " | findstr /c:"LISTENING" >nul 2>nul
  if not errorlevel 1 set "IS_RUNNING=1"
)

if "%IS_RUNNING%"=="1" (
  echo ComfyUI is already running at %URL%, opening the app window.
  goto open_app
)

echo ComfyUI is not running. Starting the backend console window, which will
echo pull updates, sync dependencies and launch the server. The app window
echo opens automatically once the port is ready.
start "ComfyUI backend" /d "%APP_DIR%" cmd /k ""%~dp0_backend.cmd""
exit /b 0

:open_app
if defined COMFY_NO_BROWSER exit /b 0
if not exist "%PS%" (
  echo [WARN] PowerShell not found, opening %URL% with the default browser.
  start "" "%URL%"
  exit /b 0
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-app.ps1" -Port %PORT%
exit /b 0
