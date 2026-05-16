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
if errorlevel 1 goto :fetch_failed

REM Считаем сколько коммитов между нами и origin/main
set NEW_COMMITS=0
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
if errorlevel 1 goto :pull_failed

echo.
echo  ✅ ГОТОВО! Свежак на диске.
goto :show_files

:already_fresh
echo  ✅ У тебя уже самая свежая версия — качать нечего.
goto :show_files

:show_files
echo.
echo  ─────────────────────────────────────────
echo  Что лежит в папке (ключевые файлы):
echo  ─────────────────────────────────────────
call :show_one demo_isometric.html
call :show_one battle.html
call :show_one hub.html
call :show_one creator.html
call :show_one mafiozi_bot.py
call :show_one index.html
echo.
pause
exit /b 0

:show_one
if exist "%~1" (
    echo    %~1  [%~z1 байт]
) else (
    echo    %~1  [НЕТ НА ДИСКЕ]
)
exit /b 0

:fetch_failed
echo.
echo  [!] Не удалось связаться с гитхабом. Проверь интернет.
pause
exit /b 1

:pull_failed
echo.
echo  [!] Не удалось скачать чисто (возможно у тебя коммиты ушли в сторону).
echo      Позови на помощь.
pause
exit /b 1
