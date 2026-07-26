@echo off
chcp 65001 >nul
title Установка Ruflo для Мафиози

echo ==========================================
echo   Установка Ruflo для проекта Мафиози
echo ==========================================
echo.

:: Переходим в папку проекта
cd /d "%~dp0"
echo [1/4] Папка проекта: %CD%
echo.

:: Проверяем node
echo [2/4] Проверяем Node.js...
node --version
if %errorlevel% neq 0 (
    echo ОШИБКА: Node.js не установлен!
    echo Скачай с https://nodejs.org/ и запусти снова.
    pause
    exit /b 1
)
npm --version
echo Node.js OK
echo.

:: Устанавливаем Ruflo
echo [3/4] Устанавливаем Ruflo...
call npx ruflo@latest init
if %errorlevel% neq 0 (
    echo.
    echo Попытка установки через npm...
    call npm install -g ruflo@latest
    if %errorlevel% neq 0 (
        echo ОШИБКА при установке Ruflo
        pause
        exit /b 1
    )
    call ruflo init
)
echo.

:: Добавляем MCP-сервер Ruflo в Claude Code
echo [4/4] Регистрируем Ruflo как MCP-сервер в Claude Code...
call claude mcp add ruflo -- npx ruflo@latest mcp start
if %errorlevel% neq 0 (
    echo Предупреждение: не удалось зарегистрировать MCP (возможно уже есть)
)
echo.

echo ==========================================
echo   Готово! Ruflo установлен.
echo   Теперь открой Claude Code в папке Мафиози
echo   и используй /ruflo или /sparc команды.
echo ==========================================
echo.
pause
