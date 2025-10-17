@REM Core batch functions for dev_scripts
@REM Core utility functions like ds:commands, ds:help, ds:fail, etc.
@REM This batch script sets up doskey aliases for Core functions

@echo off
setlocal

REM Get the directory where this batch file is located
set "BATCH_DIR=%~dp0"
set "POWERSHELL_DIR=%BATCH_DIR%..\w_powershell"

REM Check if PowerShell module exists
if not exist "%POWERSHELL_DIR%\Core.ps1" (
    echo Error: PowerShell Core module not found at %POWERSHELL_DIR%\Core.ps1
    exit /b 1
)

REM Set up doskey aliases for Core functions
doskey ds:commands=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Core.ps1'; ds:commands $*}"
doskey ds:help=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Core.ps1'; ds:help $*}"
doskey ds:fail=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Core.ps1'; ds:fail $*}"
doskey ds:tmp=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Core.ps1'; ds:tmp $*}"
doskey ds:test=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Core.ps1'; ds:test $*}"
doskey ds:nset=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Core.ps1'; ds:nset $*}"
doskey ds:pipe_check=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Core.ps1'; ds:pipe_check $*}"
doskey ds:cp=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Core.ps1'; ds:cp $*}"
doskey ds:rev=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Core.ps1'; ds:rev $*}"
doskey ds:join_by=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Core.ps1'; ds:join_by $*}"
doskey ds:embrace=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Core.ps1'; ds:embrace $*}"
doskey ds:path_elements=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Core.ps1'; ds:path_elements $*}"

REM Only show messages during install
if "%1"=="--install" (
    echo Core function aliases created successfully!
    echo Available commands: ds:commands, ds:help, ds:fail, ds:tmp, ds:test, ds:nset, ds:pipe_check, ds:cp, ds:rev, ds:join_by, ds:embrace, ds:path_elements
)
