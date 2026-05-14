@echo off
title Mafiozi - Bot Launcher (with tunnel)
color 0A
cd /d "%~dp0"

echo.
echo  ================================
echo   Mafiozi - launching bot + tunnel
echo  ================================
echo.

python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Python not found. Get it from: https://python.org/downloads/
    pause
    exit /b
)
echo [OK] Python found
echo.

if not exist "venv\Scripts\python.exe" (
    echo [..] Creating venv...
    python -m venv venv
    if %errorlevel% neq 0 (
        echo [!] Failed to create venv.
        pause
        exit /b
    )
    echo [OK] venv created
)

REM ── базовые зависимости (без них бот не стартует) ──
echo [..] Checking telegram + aiosqlite...
venv\Scripts\python -c "import telegram, aiosqlite" 2>nul
if %errorlevel% neq 0 (
    echo     installing python-telegram-bot + aiosqlite ...
    venv\Scripts\pip install "python-telegram-bot>=21.0" aiosqlite==0.19.0
    if %errorlevel% neq 0 (
        echo [!] Failed to install base deps.
        pause
        exit /b
    )
)
echo [OK] base deps OK

REM ── aiohttp (нужен для HTTP-API: найм/увольнение БЕЗ закрытия мини-аппа) ──
echo [..] Checking aiohttp...
venv\Scripts\python -c "import aiohttp" 2>nul
if %errorlevel% neq 0 (
    echo     installing aiohttp ...
    venv\Scripts\pip install aiohttp
    if %errorlevel% neq 0 (
        echo [!] WARN: aiohttp install failed.
        echo     Бот запустится, но мини-апп будет закрываться при найме/увольнении.
        echo     Чтобы исправить позже — выполни вручную в этой папке:
        echo       venv\Scripts\pip install aiohttp
        echo.
        REM не прерываемся, продолжаем без HTTP-API
    ) else (
        echo [OK] aiohttp installed
    )
) else (
    echo [OK] aiohttp present
)
echo.

if not exist ".bot-token" (
    echo [!] File .bot-token not found.
    echo     Create it and paste the @BotFather token on one line.
    pause
    exit /b
)
echo [OK] .bot-token present
echo.

echo [..] Checking bot file syntax...
venv\Scripts\python check_bot.py
if %errorlevel% neq 0 (
    echo [!] Bot file is broken.
    pause
    exit /b
)

echo.
echo [..] Starting Cloudflare tunnel + bot...
echo      Stop with Ctrl+C or close this window
echo.
venv\Scripts\python start_with_tunnel.py

if %errorlevel% neq 0 (
    echo.
    echo [!] Bot crashed. Scroll up for the error.
)
pause
