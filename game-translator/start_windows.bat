@echo off
chcp 65001 >nul
python -m pip install -r requirements.txt
python rox_translator.py
pause
