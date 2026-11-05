@echo off
title ROX
rem ============================================================
rem  ROX launcher - just double-click this file.
rem ============================================================

rem --- ask for administrator rights if we do not have them yet
fltmc >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

if not exist "%~dp0ROX.ps1" (
    echo ROX.ps1 was not found next to this file.
    echo Extract the whole ZIP first, then run ROX.bat again.
    pause
    exit /b 1
)

start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0ROX.ps1"
