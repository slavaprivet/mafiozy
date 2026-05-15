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

REM Проверка незакоммиченных локальных изменений
git diff --quiet
set UNSTAGED=%errorlevel%
git diff --cached --quiet
set STAGED=%errorlevel%

if not "%UNSTAGED%"=="0" goto :has_changes
if not "%STAGED%"=="0" goto :has_changes
goto :do_fetch

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

:do_fetch
echo  [1/3] Спрашиваю гитхаб что там нового...
git fetch origin
if errorlevel 1 (
    echo.
    echo  [!] Не удалось связаться с гитхабом. Проверь интернет.
    pause
    exit /b 1
)

REM Считаем сколько коммитов между нами и origin/main
for /f %%i in ('git rev-list --count HEAD..origin/main') do set NEW_COMMITS=%%i

echo.
if "%NEW_COMMITS%"=="0" goto :already_fresh

echo  [2/3] Новых коммитов на гитхабе: %NEW_COMMITS%
echo.
echo  Что прилетит:
echo  ─────────────────────────────────────────
git log --oneline HEAD..origin/main
echo  ─────────────────────────────────────────
echo.
echo  Файлы которые обновятся:
echo  ─────────────────────────────────────────
git diff --name-status HEAD..origin/main
echo  ─────────────────────────────────────────
echo.

echo  [3/3] Качаю...
git pull --ff-only
if errorlevel 1 (
    echo.
    echo  [!] Не удалось скачать чисто (возможно у тебя коммиты ушли в сторону).
    echo      Позови на помощь.
    pause
    exit /b 1
)

echo.
echo  ✅ ГОТОВО! Свежак на диске.
goto :show_files

:already_fresh
echo  ✅ У тебя уже самая свежая версия — качать нечего.

:show_files
echo.
echo  ─────────────────────────────────────────
echo  Что лежит в папке (ключевые файлы):
echo  ─────────────────────────────────────────
for %%F in (demo_isometric.html battle.html battle_tactical.html hub.html creator.html mafiozi_bot.py index.html) do (
    if exist "%%F" (
        for %%S in ("%%F") do echo    %%F  ^[%%~zS байт^]
    ) else (
        echo    %%F  ^[НЕТ НА ДИСКЕ^]
    )
)
echo.
pause
