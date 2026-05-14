@echo off
chcp 65001 > nul
title Скачать свежие изменения с GitHub
cd /d "%~dp0"
color 0B

echo.
echo  ═══════════════════════════════════════
echo    СКАЧАТЬ свежее с GitHub
echo  ═══════════════════════════════════════
echo.

REM Проверка что есть незакоммиченные локальные изменения
git diff --quiet
set UNSTAGED=%errorlevel%
git diff --cached --quiet
set STAGED=%errorlevel%

if not "%UNSTAGED%"=="0" goto :has_changes
if not "%STAGED%"=="0" goto :has_changes
goto :do_pull

:has_changes
echo  [!] У тебя есть НЕсохранённые изменения:
echo  ─────────────────────────────────────────
git status --short
echo  ─────────────────────────────────────────
echo.
echo  Если сейчас скачать — твои правки могут затереться.
echo  Сначала нажми СОХРАНИТЬ.bat, потом возвращайся сюда.
echo.
pause
exit /b

:do_pull
echo  [..] Подтягиваю с GitHub...
echo.
git pull
if errorlevel 1 (
    echo.
    echo  [!] Не удалось скачать. Проверь интернет.
    echo      Если не понятно что делать — позови на помощь.
    pause
    exit /b 1
)

echo.
echo  ✅ Готово! У тебя свежая версия.
echo.
pause
