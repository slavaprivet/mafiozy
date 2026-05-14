@echo off
chcp 65001 > nul
title Сохранить изменения на GitHub
cd /d "%~dp0"
color 0A

echo.
echo  ═══════════════════════════════════════
echo    СОХРАНИТЬ изменения на GitHub
echo  ═══════════════════════════════════════
echo.

REM Проверка что вообще есть что коммитить
git status --porcelain > "%temp%\_gitstatus.txt"
for /f %%i in ('type "%temp%\_gitstatus.txt" ^| find /c /v ""') do set CHANGES=%%i

if "%CHANGES%"=="0" (
    echo  Нет изменений с прошлого сохранения.
    echo  Сохранять нечего.
    echo.
    pause
    exit /b
)

echo  Изменены файлы:
echo  ─────────────────────────────────────────
git status --short
echo  ─────────────────────────────────────────
echo.
echo  Опиши коротко, что ты сделал.
echo  (несколько слов, можно по-русски)
echo.
set "MSG="
set /p MSG="  Описание: "

if "%MSG%"=="" set "MSG=Обновление"

echo.
echo  [1/4] Закрепляю твои изменения...
git add .
git commit -m "%MSG%"
if errorlevel 1 (
    echo.
    echo  [!] Не удалось создать запись. Что-то пошло не так.
    pause
    exit /b 1
)

echo.
echo  [2/4] Проверяю не появилось ли свежее у напарника...
git pull --rebase
if errorlevel 1 (
    echo.
    echo  [!] КОНФЛИКТ: ты и напарник правили один кусок кода.
    echo      Откатываю, чтобы ничего не сломать...
    git rebase --abort
    echo.
    echo      Что делать:
    echo      1. Сначала нажми СКАЧАТЬ.bat (но он скажет что есть изменения)
    echo      2. Позови на помощь — нужно разрешить конфликт вручную.
    echo.
    pause
    exit /b 1
)

echo.
echo  [3/4] Отправляю на GitHub...
git push
if errorlevel 1 (
    echo.
    echo  [!] Не удалось отправить. Проверь интернет.
    echo      Если просит логин — введи свои GitHub-данные.
    pause
    exit /b 1
)

echo.
echo  ✅ Готово! Изменения улетели на GitHub.
echo     https://github.com/slavaprivet/mafiozy
echo.
pause
