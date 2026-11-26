@echo off
:: يشغل السكربت كمسؤول تلقائياً
net session >nul 2>&1 || (powershell -Command "Start-Process '%~f0' -Verb RunAs" & exit /b)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0FPS-Tweak.ps1"
pause
