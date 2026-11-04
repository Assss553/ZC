@echo off
title GameBoost
rem ============================================================
rem  GameBoost launcher - just double-click this file.
rem ============================================================

rem --- ask for administrator rights if we do not have them yet
fltmc >nul 2>&1
if errorlevel 1 (
    echo Asking for administrator rights...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

if not exist "%~dp0GameBoost.ps1" (
    echo GameBoost.ps1 was not found next to this file.
    echo Extract the whole ZIP first, then run GameBoost.bat again.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0GameBoost.ps1" %*
