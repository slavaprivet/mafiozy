@echo off
chcp 65001 > nul
title Mafiozi Demo (локальный браузер)
color 0E
cd /d "%~dp0"

echo.
echo  ═══════════════════════════════════════
echo    MAFIOZI — Демо-версия (без бота)
echo  ═══════════════════════════════════════
echo.

REM ── проверка venv ──
if not exist "venv\Scripts\python.exe" (
    echo  [!] venv не найден. Сначала запусти ЗАПУСТИТЬ_БОТА.bat один раз — он создаст venv.
    pause
    exit /b 1
)

echo  [..] Открываю в браузере главное меню (hub.html)...
echo       Бизнес, инвентарь, магазин, работа — всё в демо-режиме.
echo.
echo       Чтобы потестить БОЙ с разными пушками — запусти БОЙ_ДЕМО.bat
echo.
echo  Чтобы остановить — закрой это окно (Ctrl+C).
echo.
echo  ───────────────────────────────────────
echo.

REM Открываем браузер с небольшой задержкой, чтобы сервер успел подняться
start "" cmd /c "timeout /t 1 /nobreak >nul & start http://localhost:8765/demo_index.html"

REM Поднимаем простой HTTP-сервер
venv\Scripts\python.exe -m http.server 8765
