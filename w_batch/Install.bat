@REM Installation script for dev_scripts batch aliases
@REM This script installs and registers the aliases for automatic startup

@echo off
setlocal

echo Installing dev_scripts batch aliases...
echo.

REM Run the setup with install flag
call "%~dp0setup_all_aliases.bat" --install

echo.
echo Installation complete!
echo.
echo To make aliases permanent (available in all new command prompts), run:
echo   setup_all_aliases.bat --register
echo.
echo Or run this installer again with --register flag:
echo   install.bat --register
echo.

REM Handle registry registration if requested
if "%1"=="--register" (
    call "%~dp0setup_all_aliases.bat" --register
)

pause