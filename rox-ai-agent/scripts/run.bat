@echo off
REM Start ROX AI Agent (development build)
cd /d "%~dp0..\desktop"
if not exist renderer\index.html (
  echo Run scripts\setup.ps1 first.
  pause
  exit /b 1
)
call npx electron .
