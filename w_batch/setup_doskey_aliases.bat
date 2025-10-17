@REM Generate doskey aliases for all PowerShell functions
@REM This script creates doskey aliases that call PowerShell functions

@echo off
setlocal

REM Get the directory where this batch file is located
set "BATCH_DIR=%~dp0"
set "POWERSHELL_DIR=%BATCH_DIR%..\w_powershell"

echo Creating doskey aliases for PowerShell functions...

REM Create doskey aliases for Core functions
echo Creating Core function aliases...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Core.ps1'; Get-Command ds:* | ForEach-Object { $funcName = $_.Name; $aliasCmd = 'doskey ' + $funcName + '=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \"& {. ''%POWERSHELL_DIR%\Core.ps1''; ds:' + $funcName + ' $*}\"'; Invoke-Expression $aliasCmd}}"

REM Create doskey aliases for File functions
echo Creating File function aliases...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\File.ps1'; Get-Command ds:* | ForEach-Object { $funcName = $_.Name; $aliasCmd = 'doskey ' + $funcName + '=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \"& {. ''%POWERSHELL_DIR%\File.ps1''; ds:' + $funcName + ' $*}\"'; Invoke-Expression $aliasCmd}}"

REM Create doskey aliases for Data functions
echo Creating Data function aliases...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Data.ps1'; Get-Command ds:* | ForEach-Object { $funcName = $_.Name; $aliasCmd = 'doskey ' + $funcName + '=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \"& {. ''%POWERSHELL_DIR%\Data.ps1''; ds:' + $funcName + ' $*}\"'; Invoke-Expression $aliasCmd}}"

REM Create doskey aliases for Git functions
echo Creating Git function aliases...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Git.ps1'; Get-Command ds:* | ForEach-Object { $funcName = $_.Name; $aliasCmd = 'doskey ' + $funcName + '=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \"& {. ''%POWERSHELL_DIR%\Git.ps1''; ds:' + $funcName + ' $*}\"'; Invoke-Expression $aliasCmd}}"

REM Create doskey aliases for System functions
echo Creating System function aliases...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\System.ps1'; Get-Command ds:* | ForEach-Object { $funcName = $_.Name; $aliasCmd = 'doskey ' + $funcName + '=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \"& {. ''%POWERSHELL_DIR%\System.ps1''; ds:' + $funcName + ' $*}\"'; Invoke-Expression $aliasCmd}}"

REM Create doskey aliases for Web functions
echo Creating Web function aliases...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& {. '%POWERSHELL_DIR%\Web.ps1'; Get-Command ds:* | ForEach-Object { $funcName = $_.Name; $aliasCmd = 'doskey ' + $funcName + '=powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \"& {. ''%POWERSHELL_DIR%\Web.ps1''; ds:' + $funcName + ' $*}\"'; Invoke-Expression $aliasCmd}}"

echo.
echo Doskey aliases created successfully!
echo You can now use commands like: ds:commands, ds:help, ds:vi, etc.
echo.
echo Note: These aliases are only active in this command prompt session.
echo To make them permanent, add this script to your startup or run it each time.

pause
