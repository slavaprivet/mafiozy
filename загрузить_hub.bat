@echo off
title GitHub Upload - hub.html
color 0E
cd /d "%~dp0"

echo.
echo  ================================================
echo   Заливаю hub.html на GitHub + сверяю обратно
echo  ================================================
echo.

REM ── ищем python ──
where python >nul 2>&1
if %errorlevel% equ 0 (
    python github_upload_hub.py
    goto :end
)

if exist "venv\Scripts\python.exe" (
    echo [..] Использую venv\python ...
    venv\Scripts\python.exe github_upload_hub.py
    goto :end
)

echo [!] Python не найден.
echo     Установи Python с https://python.org/downloads/
echo     либо запусти сначала ЗАПУСТИТЬ_БОТА.bat — он создаст venv.

:end
pause
