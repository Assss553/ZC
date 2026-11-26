# Builds a Windows installer: backend -> PyInstaller exe, frontend -> static files, Electron -> NSIS setup.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Push-Location "$root\backend"
.\.venv\Scripts\python.exe -m pip install pyinstaller
.\.venv\Scripts\pyinstaller.exe --noconfirm --name rox-backend --onedir --noconsole `
  --collect-submodules rox --collect-submodules uvicorn --collect-submodules keyring `
  --hidden-import keyring.backends.Windows --hidden-import win32ctypes.core --hidden-import cv2 --hidden-import pyautogui --hidden-import pygetwindow `
  run_backend.py
Pop-Location
Push-Location "$root\frontend"; npm run build; Pop-Location
if (Test-Path "$root\desktop\renderer") { Remove-Item -Recurse -Force "$root\desktop\renderer" }
Copy-Item -Recurse "$root\frontend\dist" "$root\desktop\renderer"
Push-Location "$root\desktop"; npm run dist; Pop-Location
Write-Host "Installer: desktop\dist\ROX AI Agent Setup *.exe" -ForegroundColor Green
