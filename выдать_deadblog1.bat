@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo === Выдача @deadblog1: 100 гранат + 30 молотовых ===
python grant_deadblog1.py
echo.
pause
