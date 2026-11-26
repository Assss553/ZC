# Copies this project to C:\rox-ai-agent (as requested) and runs setup there.
$root = Split-Path -Parent $PSScriptRoot
$target = "C:\rox-ai-agent"
if ((Resolve-Path $root).Path -ne $target) {
  robocopy $root $target /E /XD node_modules .venv dist renderer .git | Out-Null
}
& "$target\scripts\setup.ps1"
