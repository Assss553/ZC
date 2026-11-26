# One-time setup: Python venv + backend deps, frontend deps/build, Electron deps. Run as a NORMAL user.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
& "$PSScriptRoot\check-env.ps1"
Push-Location "$root\backend"
if (-not (Test-Path .venv)) { python -m venv .venv }
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Pop-Location
Push-Location "$root\frontend"; npm install; npm run build; Pop-Location
if (Test-Path "$root\desktop\renderer") { Remove-Item -Recurse -Force "$root\desktop\renderer" }
Copy-Item -Recurse "$root\frontend\dist" "$root\desktop\renderer"
Push-Location "$root\desktop"; npm install; Pop-Location
Write-Host "`nSetup complete. Start with: scripts\run.bat" -ForegroundColor Green
