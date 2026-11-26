# Zips the project source and the user data (DB, logs, file backups). API keys stay in Credential Manager and are NOT included.
$root = Split-Path -Parent $PSScriptRoot
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$dest = Join-Path $env:USERPROFILE "Documents\ROX-Backups"; New-Item -ItemType Directory -Force $dest | Out-Null
$src = Get-ChildItem $root -Exclude node_modules,.venv,dist,renderer
Compress-Archive -Path $src.FullName -DestinationPath "$dest\rox-source-$stamp.zip"
$data = Join-Path $env:LOCALAPPDATA "ROX-AI-Agent"
if (Test-Path $data) { Compress-Archive -Path "$data\*" -DestinationPath "$dest\rox-data-$stamp.zip" }
Write-Host "Backup saved to $dest"
