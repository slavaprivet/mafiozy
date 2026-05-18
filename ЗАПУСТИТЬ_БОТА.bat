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

REM Проверяем что venv реально рабочий — шим venv\Scripts\python.exe внутри
REM содержит путь к исходному интерпретатору, и если тот удалён/обновлён,
REM любой запуск падает с "did not find executable at ...". Если так —
REM сносим папку и создаём venv заново на текущем системном Python.
venv\Scripts\python.exe -c "import sys; sys.exit(0)" >nul 2>nul
if errorlevel 1 (
    echo [..] venv broken ^(referenced python is gone^), recreating...
    rmdir /s /q venv
    python -m venv venv
    if not exist "venv\Scripts\python.exe" goto :no_venv
)
echo [OK] venv ready

REM ── базовые зависимости ──────────────────────────────
echo [..] Checking telegram + aiosqlite...
venv\Scripts\python -c "import telegram, aiosqlite" 2>nul
if not errorlevel 1 goto :check_ptb_version
echo     installing python-telegram-bot + aiosqlite ...
REM Зовём pip МОДУЛЕМ (python -m pip), а не venv\Scripts\pip.exe — иначе
REM в путях с кириллицей шим pip.exe ломается ("Fatal error in launcher:
REM Unable to create process ...").
venv\Scripts\python -m pip install --disable-pip-version-check "python-telegram-bot>=22.0" aiosqlite==0.19.0
venv\Scripts\python -c "import telegram, aiosqlite" 2>nul
if errorlevel 1 goto :base_failed
goto :base_ok

:check_ptb_version
REM Python 3.13+ + старые python-telegram-bot 21.x → AttributeError на
REM _Updater__polling_cleanup_cb (Updater имеет __slots__ без этого слота).
REM Фикс — 22.0+. Проверяем версию и форс-апгрейдим если ниже.
venv\Scripts\python -c "import telegram, sys; v=telegram.__version__.split('.'); sys.exit(0 if int(v[0])>=22 else 1)" 2>nul
if not errorlevel 1 goto :base_ok
echo [..] python-telegram-bot устарел ^(нужен 22.0+ для Python 3.13/3.14^), обновляю...
venv\Scripts\python -m pip install --disable-pip-version-check --upgrade "python-telegram-bot>=22.0"
venv\Scripts\python -c "import telegram, sys; v=telegram.__version__.split('.'); sys.exit(0 if int(v[0])>=22 else 1)" 2>nul
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

REM ── Auto-deploy hub.html + demo_isometric.html на GitHub Pages ───
REM Чтобы Telegram-WebApp всегда видел свежий HTML. Без этого юзер
REM правит локально, но TG читает с GitHub Pages — там старая версия.
REM NO_PAUSE=1 — скрипты пропускают интерактивные input(); <nul даёт
REM сразу EOF на stdin если они всё-таки запросят.
if exist ".token" (
    set NO_PAUSE=1
    echo.
    echo [..] Деплой hub.html на GitHub Pages...
    venv\Scripts\python github_upload_hub.py <nul
    if errorlevel 1 (
        echo [!] Деплой hub.html не прошёл — мини-апп будет на старой версии.
    ) else (
        echo [OK] hub.html задеплоен.
    )
    echo.
    echo [..] Деплой demo_isometric.html на GitHub Pages...
    venv\Scripts\python github_upload_iso.py <nul
    if errorlevel 1 (
        echo [!] Деплой demo_isometric.html не прошёл — боёвка на старой версии.
    ) else (
        echo [OK] demo_isometric.html задеплоен.
    )
    set NO_PAUSE=
    echo.
) else (
    echo [!] .token не найден — пропускаю авто-деплой HTML.
    echo     Положи GitHub Personal Access Token ^(ghp_...^) в файл .token
    echo     рядом со скриптом, чтобы при каждом запуске hub.html и
    echo     demo_isometric.html автоматически уезжали на GitHub Pages.
    echo.
)

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