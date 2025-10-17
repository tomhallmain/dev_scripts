@REM Data processing batch functions for dev_scripts
@REM Data processing functions like ds:fit, ds:join, ds:pivot, ds:agg, etc.
@REM This batch script executes the corresponding PowerShell module

@echo off
setlocal

REM Get the directory where this batch file is located
set "BATCH_DIR=%~dp0"
set "POWERSHELL_DIR=%BATCH_DIR%..\w_powershell"

REM Check if PowerShell module exists
if not exist "%POWERSHELL_DIR%\Data.ps1" (
    echo Error: PowerShell Data module not found at %POWERSHELL_DIR%\Data.ps1
    exit /b 1
)

REM Execute PowerShell module with arguments
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%POWERSHELL_DIR%\Data.ps1" %*

REM Preserve exit code
exit /b %ERRORLEVEL%
