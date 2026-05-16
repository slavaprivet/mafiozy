@echo off
title GitHub Upload - demo_isometric.html
color 0E
cd /d "%~dp0"

echo.
echo  ================================================
echo   Заливаю demo_isometric.html на GitHub + сверяю
echo  ================================================
echo.

REM ── ищем python ──
where python >nul 2>&1
if %errorlevel% equ 0 (
    python github_upload_iso.py
    goto :end
)

if exist "venv\Scripts\python.exe" (
    echo [..] Использую venv\python ...
    venv\Scripts\python.exe github_upload_iso.py
    goto :end
)

echo [!] Python не найден.
echo     Установи Python с https://python.org/downloads/
echo     либо запусти сначала ЗАПУСТИТЬ_БОТА.bat — он создаст venv.

:end
pause
