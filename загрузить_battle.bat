@echo off
title GitHub Upload
cd /d "%~dp0"
echo Starting...
venv\Scripts\python.exe github_upload.py
if %errorlevel% neq 0 (
    echo.
    echo Python error! Code: %errorlevel%
    pause
)
