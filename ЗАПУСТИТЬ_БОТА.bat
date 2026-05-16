@echo off
chcp 65001 > nul
title Mafiozi - Bot Launcher (with tunnel)
color 0A
cd /d "%~dp0"

echo.
echo  ================================
echo   Mafiozi - launching bot + tunnel
echo  ================================
echo.

python --version >nul 2>&1
if errorlevel 1 goto :no_python
echo [OK] Python found
echo.

if not exist "venv\Scripts\python.exe" (
    echo [..] Creating venv...
    python -m venv venv
)
if not exist "venv\Scripts\python.exe" goto :no_venv
echo [OK] venv ready

REM ── базовые зависимости ──────────────────────────────
echo [..] Checking telegram + aiosqlite...
venv\Scripts\python -c "import telegram, aiosqlite" 2>nul
if not errorlevel 1 goto :base_ok
echo     installing python-telegram-bot + aiosqlite ...
REM Зовём pip МОДУЛЕМ (python -m pip), а не venv\Scripts\pip.exe — иначе
REM в путях с кириллицей шим pip.exe ломается ("Fatal error in launcher:
REM Unable to create process ...").
venv\Scripts\python -m pip install --disable-pip-version-check "python-telegram-bot>=21.0" aiosqlite==0.19.0
venv\Scripts\python -c "import telegram, aiosqlite" 2>nul
if errorlevel 1 goto :base_failed

:base_ok
echo [OK] base deps OK

REM ── aiohttp ──────────────────────────────────────────
echo [..] Checking aiohttp...
venv\Scripts\python -c "import aiohttp" 2>nul
if not errorlevel 1 goto :aiohttp_ok
echo     installing aiohttp ...
venv\Scripts\python -m pip install --disable-pip-version-check aiohttp
venv\Scripts\python -c "import aiohttp" 2>nul
if errorlevel 1 goto :aiohttp_warn
echo [OK] aiohttp installed
goto :aiohttp_done

:aiohttp_ok
echo [OK] aiohttp present
goto :aiohttp_done

:aiohttp_warn
echo [!] WARN: aiohttp install failed.
echo     Бот запустится, но мини-апп будет закрываться при найме/увольнении.

:aiohttp_done
echo.

if not exist ".bot-token" goto :no_token
echo [OK] .bot-token present
echo.

echo [..] Checking bot file syntax...
venv\Scripts\python check_bot.py
if errorlevel 1 goto :bot_broken

echo.
echo [..] Starting Cloudflare tunnel + bot...
echo      Stop with Ctrl+C or close this window
echo.
venv\Scripts\python start_with_tunnel.py
if errorlevel 1 goto :bot_crashed
goto :end_ok

:no_python
echo [!] Python not found. Get it from: https://python.org/downloads/
pause
exit /b 1

:no_venv
echo [!] Failed to create venv.
pause
exit /b 1

:base_failed
echo [!] Failed to install base deps.
pause
exit /b 1

:no_token
echo [!] File .bot-token not found.
echo     Create it and paste the @BotFather token on one line.
pause
exit /b 1

:bot_broken
echo [!] Bot file is broken.
pause
exit /b 1

:bot_crashed
echo.
echo [!] Bot crashed. Scroll up for the error.
pause
exit /b 1

:end_ok
pause
exit /b 0