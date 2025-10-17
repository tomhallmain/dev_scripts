@REM Master setup script for dev_scripts batch aliases
@REM This script sets up all doskey aliases for PowerShell functions

@echo off
setlocal

REM Get the directory where this batch file is located
set "BATCH_DIR=%~dp0"

REM Check if this is an install/verbose run
if "%1"=="--install" (
    echo Setting up dev_scripts batch aliases...
    echo.
)

REM Load all module aliases (silently unless installing)
if "%1"=="--install" (
    call "%BATCH_DIR%\Core.bat"
    call "%BATCH_DIR%\File.bat"
    call "%BATCH_DIR%\Data.bat"
    call "%BATCH_DIR%\Git.bat"
    call "%BATCH_DIR%\System.bat"
    call "%BATCH_DIR%\Web.bat"
    echo.
    echo All dev_scripts aliases have been set up successfully!
    echo You can now use commands like: ds:commands, ds:help, ds:vi, ds:git_status, etc.
    echo.
    echo To make these aliases permanent, run: setup_all_aliases.bat --register
    echo.
) else (
    call "%BATCH_DIR%\Core.bat" >nul 2>&1
    call "%BATCH_DIR%\File.bat" >nul 2>&1
    call "%BATCH_DIR%\Data.bat" >nul 2>&1
    call "%BATCH_DIR%\Git.bat" >nul 2>&1
    call "%BATCH_DIR%\System.bat" >nul 2>&1
    call "%BATCH_DIR%\Web.bat" >nul 2>&1
)

REM Handle registry registration
if "%1"=="--register" (
    echo Registering dev_scripts aliases for automatic startup...
    set "SCRIPT_PATH=%BATCH_DIR%setup_all_aliases.bat"
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Command Processor" /v "AutoRun" /t REG_SZ /d "%SCRIPT_PATH%" /f >nul 2>&1
    if %ERRORLEVEL%==0 (
        echo Successfully registered dev_scripts aliases for automatic startup.
        echo Aliases will be available in all new command prompt sessions.
    ) else (
        echo Failed to register aliases. You may need to run as administrator.
    )
    echo.
)
