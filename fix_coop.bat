@echo off
title Fix coop sessions
cd /d "%~dp0"
venv\Scripts\python.exe fix_coop.py
pause
