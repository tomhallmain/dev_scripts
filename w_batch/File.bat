@REM File operations batch functions for dev_scripts
@REM File operations like ds:vi, ds:grepvi, ds:cd, ds:searchx, etc.
@REM This batch script sets up doskey aliases for File functions

@echo off
setlocal

REM Get the directory where this batch file is located
set "BATCH_DIR=%~dp0"
set "POWERSHELL_DIR=%BATCH_DIR%..\w_powershell"

REM Check if PowerShell module exists
if not exist "%POWERSHELL_DIR%\File.ps1" (
    echo Error: PowerShell File module not found at %POWERSHELL_DIR%\File.ps1
    exit /b 1
)

REM Set up doskey aliases for File functions
doskey ds:vi=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\File.ps1'; ds:vi $*}"
doskey ds:grepvi=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\File.ps1'; ds:grepvi $*}"
doskey ds:gvi=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\File.ps1'; ds:grepvi $*}"
doskey ds:cd=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\File.ps1'; ds:cd $*}"
doskey ds:searchx=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\File.ps1'; ds:searchx $*}"
doskey ds:select=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\File.ps1'; ds:select $*}"
doskey ds:insert=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\File.ps1'; ds:insert $*}"
doskey ds:filename_str=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\File.ps1'; ds:filename_str $*}"

REM Only show messages during install
if "%1"=="--install" (
    echo File function aliases created successfully!
    echo Available commands: ds:vi, ds:grepvi, ds:gvi, ds:cd, ds:searchx, ds:select, ds:insert, ds:filename_str
)
