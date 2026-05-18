@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================================
echo  Запуск Мафиози-бота с туннелем
echo  Папка: %CD%
echo ============================================================
echo.

REM Проверка .bot-token
if not exist ".bot-token" (
    echo [!] Файл .bot-token не найден.
    if exist "bot-token-backup.txt" (
        echo     Копирую из bot-token-backup.txt...
        copy /Y "bot-token-backup.txt" ".bot-token" >nul
    ) else if exist "%USERPROFILE%\Desktop\bot-token-backup.txt" (
        echo     Копирую с десктопа bot-token-backup.txt...
        copy /Y "%USERPROFILE%\Desktop\bot-token-backup.txt" ".bot-token" >nul
    ) else (
        echo     bot-token-backup.txt тоже не найден.
        echo     Создай вручную: получи токен у @BotFather и положи в .bot-token
        echo.
        pause
        exit /b 1
    )
)

REM Проверка Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [!] Python не найден в PATH.
    echo     Установи python.org/downloads и при установке отметь "Add to PATH".
    echo.
    pause
    exit /b 1
)

echo Запускаю start_with_tunnel.py ...
echo.
python start_with_tunnel.py

echo.
echo ============================================================
echo  Бот завершился. Код выхода: %ERRORLEVEL%
echo ============================================================
echo  Если бот упал — прокрути вывод выше, там traceback.
echo  Самые частые причины:
echo    1. Конфликт getUpdates — другой инстанс бота запущен.
echo       Закрой все остальные окна с ботом.
echo    2. Нет пакетов: pip install python-telegram-bot aiosqlite aiohttp
echo    3. Туннель не поднялся — провайдер режет. Посмотри cloudflared.log.
echo ============================================================
pause
