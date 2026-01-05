@echo off
:: RStudio Server Docker - Web Installer Launcher
:: Windows

setlocal enabledelayedexpansion

echo.
echo   RStudio Server Docker Installer
echo   ================================
echo.

:: Check Node.js
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo   Error: Node.js is not installed.
    echo.
    echo   Please install Node.js first:
    echo     - Download from: https://nodejs.org/
    echo     - Or use: winget install OpenJS.NodeJS.LTS
    echo.
    pause
    exit /b 1
)

:: Get script directory
set "SCRIPT_DIR=%~dp0"
set "INSTALLER_DIR=%SCRIPT_DIR%installer"

:: Install dependencies if needed
if not exist "%INSTALLER_DIR%\node_modules" (
    echo   Installing dependencies...
    cd /d "%INSTALLER_DIR%"
    call npm install
    echo.
)

:: Start the installer
echo   Starting installer...
echo.
cd /d "%INSTALLER_DIR%"
npm start
