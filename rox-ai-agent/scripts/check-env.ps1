# Checks Windows 11, Python, Node.js, Git and admin status.
$ErrorActionPreference = "Continue"
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "OS: $($os.Caption) build $($os.BuildNumber)"
if ([int]$os.BuildNumber -lt 22000) { Write-Warning "Windows 11 (build 22000+) recommended." }
foreach ($t in @("python","node","npm","git")) {
  $c = Get-Command $t -ErrorAction SilentlyContinue
  if ($c) { Write-Host ("{0,-7} OK  {1}" -f $t, (& $t --version 2>&1 | Select-Object -First 1)) } else { Write-Warning "$t NOT FOUND" }
}
$py = (& python -c "import sys;print(sys.version_info>=(3,10))" 2>$null)
if ($py -ne "True") { Write-Warning "Python 3.10+ required (https://www.python.org/downloads/ — tick 'Add to PATH')." }
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($admin) { Write-Warning "You are running as Administrator. Run ROX as a normal user." } else { Write-Host "Running as normal user: OK" }
