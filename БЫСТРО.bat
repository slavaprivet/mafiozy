@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================================
echo  Дешёвый помощник (Groq/DeepSeek) — лёгкие задачи мимо Opus
echo ============================================================
echo  Примеры: "где логика ограбления банка?"  /  "что делает render?"
echo  (правки с применением — из терминала: python quick.py -e "..." --yes)
echo.
set /p TASK="Задача: "
if "%TASK%"=="" goto :eof
echo.
python quick.py "%TASK%"
echo.
pause
