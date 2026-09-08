@echo off
setlocal enabledelayedexpansion

echo ====================================================
echo           Starting Stora Django Backend
echo ====================================================

:: Find ADB
set "ADB_BIN="
where adb >nul 2>nul
if %errorlevel% equ 0 (
    set "ADB_BIN=adb"
) else if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    set "ADB_BIN=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
)

if defined ADB_BIN (
    echo [ADB] Configuring reverse port forwarding: tcp:8000 to tcp:8000...
    "%ADB_BIN%" reverse tcp:8000 tcp:8000 >nul 2>nul
    if !errorlevel! equ 0 (
        echo [ADB] Connected device port 8000 forwarded to host PC.
    ) else (
        echo [ADB] Note: No active Android USB device found or reverse failed.
    )
) else (
    echo [ADB] Warning: adb not found in PATH or Android SDK.
)

:: Show host IP
echo.
echo [NETWORK] Wi-Fi IP check:
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /i "IPv4"') do (
    echo   Found IP:%%i
)

echo.
echo [SERVER] Starting server on 0.0.0.0:8000 (all interfaces)...
echo [SERVER] Press Ctrl+C to stop the server.
echo.

cd /d "%~dp0stora_backend_inner"

if exist "..\.venv\Scripts\python.exe" (
    "..\.venv\Scripts\python.exe" manage.py runserver 0.0.0.0:8000
) else if exist "venv\Scripts\python.exe" (
    "venv\Scripts\python.exe" manage.py runserver 0.0.0.0:8000
) else (
    python manage.py runserver 0.0.0.0:8000
)

pause
