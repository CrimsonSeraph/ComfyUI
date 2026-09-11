@echo off
setlocal EnableExtensions EnableDelayedExpansion
title ComfyUI backend

rem ============================================================
rem  ComfyUI launcher - backend steps
rem    pull updates  -  sync deps  -  start ComfyUI  -  open app window
rem
rem  Called by start-comfyui.bat in its own console window.
rem  That window is started with cmd /k, so closing it stops the server.
rem
rem  Design rules:
rem    * every git pull uses --depth=1 shallow fetch
rem    * ANY pull/install failure only prints [WARN] and continues; never aborts
rem    * a dirty worktree or unpushed local commits make that repo be skipped
rem
rem  IMPORTANT - keep this file pure ASCII and keep the redirection characters
rem  out of rem/echo TEXT. cmd parses them as redirection even inside rem and
rem  echo, and a non-ASCII batch file breaks when the console code page is not
rem  the one it was saved in. ASCII keeps it working under any code page.
rem
rem  Env vars: see custom/README.md section 2.3
rem ============================================================

rem ---- locate repo root ----
for %%I in ("%~dp0..\..") do set "APP_DIR=%%~fI"
if defined COMFY_APP_DIR set "APP_DIR=%COMFY_APP_DIR%"
if not exist "%APP_DIR%\main.py" (
  echo [ERROR] ComfyUI repo root not found: "%APP_DIR%"
  echo         Set COMFY_APP_DIR to the repo path, or keep this script
  echo         inside the repo at custom\launcher\.
  exit /b 1
)
cd /d "%APP_DIR%"

set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

rem ---- paths and settings ----
set "PORT=%COMFY_PORT%"
if not defined PORT set "PORT=8188"

set "LISTEN=%COMFY_LISTEN%"
if not defined LISTEN set "LISTEN=127.0.0.1"

set "BRANCH=%COMFY_PULL_BRANCH%"
if not defined BRANCH set "BRANCH=master"

set "NODES_DIR=%COMFY_NODES_DIR%"
if not defined NODES_DIR set "NODES_DIR=%APP_DIR%\custom_nodes"

rem ---- extra launch args ----
rem  Defaults are the two switches this machine needs. COMFY_ARGS replaces them.
rem    --enable-manager               enable ComfyUI-Manager, needs comfyui_manager
rem    --use-pytorch-cross-attention  force native PyTorch cross attention
rem  Set COMFY_ARGS=- to launch with no extra args at all.
set "ARGS=%COMFY_ARGS%"
if not defined ARGS set "ARGS=--enable-manager --use-pytorch-cross-attention"
if "%ARGS%"=="-" set "ARGS="

rem ---- python interpreter ----
rem  Order: COMFY_PYTHON, then a python inside the repo, then python on PATH.
rem  No absolute path is hardcoded, so a moved or renamed checkout keeps working.
set "PY=%COMFY_PYTHON%"
if not defined PY if exist "%APP_DIR%\.venv\Scripts\python.exe" set "PY=%APP_DIR%\.venv\Scripts\python.exe"
if not defined PY if exist "%APP_DIR%\venv\Scripts\python.exe" set "PY=%APP_DIR%\venv\Scripts\python.exe"
if not defined PY if exist "%APP_DIR%\python_embeded\python.exe" set "PY=%APP_DIR%\python_embeded\python.exe"
if not defined PY (
  set "PY=python"
  rem  resolve through PATH so the banner shows which interpreter is really used
  for /f "delims=" %%P in ('where python 2^>nul') do if not defined PY_RESOLVED set "PY_RESOLVED=%%P"
  if defined PY_RESOLVED set "PY=!PY_RESOLVED!"
)
"%PY%" --version >nul 2>nul
if errorlevel 1 (
  echo [ERROR] cannot run python: "%PY%"
  echo         Set COMFY_PYTHON to the python.exe that ComfyUI uses, or put
  echo         that python on PATH. See custom/README.md section 1.
  exit /b 1
)

echo ============================================================
echo  ComfyUI launcher
echo    repo       : %APP_DIR%
echo    python     : %PY%
echo    address    : http://%LISTEN%:%PORT%
echo    nodes      : %NODES_DIR%
echo    extra args : %ARGS%
echo ============================================================
echo.

if defined COMFY_DRY_RUN (
  echo [DRY RUN] nothing will actually be executed:
  echo   1. shallow pull main repo  : git fetch --depth=1 origin %BRANCH%
  echo                               git reset --hard FETCH_HEAD
  echo   2. shallow pull node repos : same, for every .git dir under %NODES_DIR%
  echo   3. sync dependencies       : only when something really changed
  echo   4. start server            : "%PY%" main.py --listen %LISTEN% --port %PORT% %ARGS%
  if not defined COMFY_NO_BROWSER echo   5. open app window         : msedge.exe --app=http://127.0.0.1:%PORT%
  echo [DRY RUN] done. Close this window.
  exit /b 0
)

rem ============================================================
rem  step 1 - shallow pull the ComfyUI repo
rem ============================================================
set "MAIN_UPDATED=0"
if defined COMFY_NO_PULL (
  echo [SKIP] COMFY_NO_PULL is set, skipping main repo update.
) else (
  call :pull_repo "%APP_DIR%" "%BRANCH%" "ComfyUI"
  if "!PULL_CHANGED!"=="1" set "MAIN_UPDATED=1"
)

rem ============================================================
rem  step 2 - shallow pull every git repo under custom_nodes
rem           non-git dirs installed by Manager are skipped
rem ============================================================
set "NODES_UPDATED=0"
set "CHANGED_NODES="
if defined COMFY_NO_PULL (
  echo [SKIP] COMFY_NO_PULL is set, skipping node repo updates.
) else (
  if not exist "%NODES_DIR%" (
    echo [WARN] custom_nodes dir not found: "%NODES_DIR%", skipping.
  ) else (
    set "NODE_COUNT=0"
    set "NODE_SKIPPED=0"
    for /d %%D in ("%NODES_DIR%\*") do (
      if exist "%%D\.git" (
        call :pull_repo "%%D" "" "%%~nxD"
        set /a NODE_COUNT+=1
        if "!PULL_CHANGED!"=="1" (
          set "NODES_UPDATED=1"
          set "CHANGED_NODES=!CHANGED_NODES! "%%D""
        )
      ) else (
        set /a NODE_SKIPPED+=1
      )
    )
    echo [OK]   node scan done: !NODE_COUNT! git repo[s], !NODE_SKIPPED! non-git dir[s] skipped.
  )
)

rem ============================================================
rem  step 3 - sync dependencies, only when something changed
rem ============================================================
if defined COMFY_NO_INSTALL (
  echo [SKIP] COMFY_NO_INSTALL is set, skipping dependency sync.
) else (
  if "!MAIN_UPDATED!!NODES_UPDATED!"=="00" (
    echo [SKIP] nothing changed, skipping dependency sync.
  ) else (
    if "!MAIN_UPDATED!"=="1" (
      echo [STEP 3] main repo changed, syncing deps: pip install -r requirements.txt
      "%PY%" -m pip install -r "%APP_DIR%\requirements.txt"
      if errorlevel 1 echo [WARN] main dependency sync failed, check the log above.
    )
    if defined CHANGED_NODES (
      for %%D in (!CHANGED_NODES!) do (
        if exist "%%~D\requirements.txt" (
          echo [STEP 3] node %%~nxD changed, syncing its deps
          "%PY%" -m pip install -r "%%~D\requirements.txt"
          if errorlevel 1 echo [WARN] dependency sync failed for node %%~nxD.
        )
      )
    )
  )
)

rem ============================================================
rem  step 4 - start ComfyUI
rem ============================================================
if defined COMFY_NO_START (
  echo [SKIP] COMFY_NO_START is set, not starting the server.
  exit /b 0
)

echo [STEP 4] starting ComfyUI
echo          "%PY%" main.py --listen %LISTEN% --port %PORT% %ARGS%
echo          Close this window to stop the server. Ctrl+C also works.
echo.

if defined COMFY_NO_BROWSER goto :run_server
if not exist "%PS%" (
  echo [WARN] PowerShell not found, open http://127.0.0.1:%PORT% manually.
  goto :run_server
)
echo          Will open the app window once the port is ready.
start "" "%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-app.ps1" -Port %PORT%

:run_server
"%PY%" main.py --listen %LISTEN% --port %PORT% %ARGS%

echo.
echo ComfyUI exited with code %ERRORLEVEL%. This window can be closed.
exit /b 0

rem ============================================================
rem  :pull_repo
rem    %1 = repo dir   %2 = branch, empty means current branch   %3 = label
rem  Returns PULL_CHANGED=1 when code was really updated.
rem  Every failure path only warns and returns.
rem ============================================================
:pull_repo
set "PULL_CHANGED=0"
set "REPO_DIR=%~1"
set "REPO_NAME=%~3"
set "REPO_BRANCH=%~2"

if not exist "%REPO_DIR%\.git" (
  echo [WARN] %REPO_NAME%: not a git repo, skipping.
  goto :eof
)

git -C "%REPO_DIR%" rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (
  echo [WARN] %REPO_NAME%: not a git work tree, skipping.
  goto :eof
)

if not defined REPO_BRANCH (
  for /f "delims=" %%B in ('git -C "%REPO_DIR%" rev-parse --abbrev-ref HEAD 2^>nul') do set "REPO_BRANCH=%%B"
)
if not defined REPO_BRANCH (
  echo [WARN] %REPO_NAME%: cannot determine current branch, skipping.
  goto :eof
)
if "%REPO_BRANCH%"=="HEAD" (
  echo [WARN] %REPO_NAME%: detached HEAD, skipping.
  goto :eof
)

rem worktree must be clean, otherwise skip to protect local edits
git -C "%REPO_DIR%" diff --quiet HEAD >nul 2>nul
if errorlevel 1 (
  echo [WARN] %REPO_NAME%: worktree has uncommitted changes, skipping.
  goto :eof
)

rem remember origin/branch and HEAD before fetching, to detect unpushed commits
set "TRACKED_TIP="
for /f "delims=" %%C in ('git -C "%REPO_DIR%" rev-parse origin/%REPO_BRANCH% 2^>nul') do set "TRACKED_TIP=%%C"
set "LOCAL_TIP="
for /f "delims=" %%C in ('git -C "%REPO_DIR%" rev-parse HEAD 2^>nul') do set "LOCAL_TIP=%%C"

rem shallow fetch --depth=1: only the latest commit of that branch
git -C "%REPO_DIR%" fetch --depth=1 origin %REPO_BRANCH% >nul 2>nul
if errorlevel 1 (
  echo [WARN] %REPO_NAME%: git fetch --depth=1 failed, keeping local version.
  goto :eof
)

set "REMOTE_TIP="
for /f "delims=" %%C in ('git -C "%REPO_DIR%" rev-parse FETCH_HEAD 2^>nul') do set "REMOTE_TIP=%%C"
if not defined REMOTE_TIP (
  echo [WARN] %REPO_NAME%: cannot resolve remote commit, keeping local version.
  goto :eof
)

if "%LOCAL_TIP%"=="%REMOTE_TIP%" (
  echo [OK]   %REPO_NAME%: up to date %REPO_BRANCH%@%LOCAL_TIP:~0,8%
  goto :eof
)

rem HEAD differs from the pre-fetch origin/branch means unpushed local commits
if not defined TRACKED_TIP (
  echo [WARN] %REPO_NAME%: no origin/%REPO_BRANCH% ref, cannot judge local commits, skipping.
  goto :eof
)
if not "%LOCAL_TIP%"=="%TRACKED_TIP%" (
  if not defined COMFY_PULL_FORCE (
    echo [WARN] %REPO_NAME%: local commits are not pushed, skipping.
    echo        Set COMFY_PULL_FORCE=1 to align to remote anyway, local commits will be lost.
    goto :eof
  )
  echo [WARN] %REPO_NAME%: COMFY_PULL_FORCE=1, aligning to remote, local commits will be lost.
)

git -C "%REPO_DIR%" reset --hard FETCH_HEAD >nul 2>nul
if errorlevel 1 (
  echo [WARN] %REPO_NAME%: git reset failed, keeping local version.
  goto :eof
)
echo [OK]   %REPO_NAME%: updated to %REPO_BRANCH%@%REMOTE_TIP:~0,8%
set "PULL_CHANGED=1"

if defined COMFY_GC (
  git -C "%REPO_DIR%" reflog expire --expire=now --all >nul 2>nul
  git -C "%REPO_DIR%" gc --prune=now --quiet >nul 2>nul
)
goto :eof
