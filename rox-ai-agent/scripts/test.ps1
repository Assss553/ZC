$root = Split-Path -Parent $PSScriptRoot
Push-Location "$root\backend"; .\.venv\Scripts\python.exe -m pytest -q tests; Pop-Location
Push-Location "$root\frontend"; npx tsc -b; Pop-Location
