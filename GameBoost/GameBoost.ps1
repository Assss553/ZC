<#
================================================================================
  GameBoost  -  one-click gaming optimizer for Windows 10 / 11
--------------------------------------------------------------------------------
  * Makes a System Restore point and backs up EVERY value it changes to
    C:\ProgramData\GameBoost\backup.json, so menu option [6] can undo it all.
  * Uses only built-in Windows settings. The only download is the official
    GPU vendor updater app (through winget) so the GPU driver updates itself.
  * Start it with GameBoost.bat (double-click). Command line:
        GameBoost.ps1 -Mode Menu | Apply | CleanRam | Status | Restore
================================================================================
#>
[CmdletBinding()]
param(
    [ValidateSet('Menu', 'Apply', 'CleanRam', 'Status', 'Restore')]
    [string]$Mode = 'Menu'
)

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

# ----------------------------------------------------------------- elevation
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'GameBoost needs administrator rights - asking Windows...' -ForegroundColor Yellow
    $argList = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Mode {1}' -f $PSCommandPath, $Mode
    try {
        Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs -ErrorAction Stop
    } catch {
        Write-Host 'Administrator rights were not given. Right-click GameBoost.bat > Run as administrator.' -ForegroundColor Red
        Start-Sleep -Seconds 6
    }
    exit
}

if ([Environment]::OSVersion.Version.Major -lt 10) {
    Write-Host 'GameBoost supports Windows 10 and Windows 11 only.' -ForegroundColor Red
    Start-Sleep -Seconds 6
    exit 1
}

# ----------------------------------------------------------------- constants
$script:Version         = '1.0'
$script:DataDir         = Join-Path $env:ProgramData 'GameBoost'
$script:BackupFile      = Join-Path $script:DataDir 'backup.json'
$script:LogFile         = Join-Path $script:DataDir 'log.txt'
$script:SchemeGuid      = 'd3a1f00d-6a3e-4c5b-9b7e-0b005e0b0057'   # our own copy of the plan
$script:UltimateGuid    = 'e9a42b02-d5df-448d-aa00-03f14749eb61'   # Ultimate Performance
$script:HighGuid        = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'   # High Performance
$script:BalancedGuid    = '381b4222-f694-41f0-9685-ff5bb260df2e'   # Balanced
$script:BestPerfOverlay = 'ded574b5-45a0-4f42-8737-46345c09c238'   # "Best performance" power mode
$script:ShortcutName    = 'GameBoost - Clean RAM.lnk'
$script:RegTypes        = @('DWord', 'QWord', 'String', 'ExpandString', 'MultiString', 'Binary')

if (-not (Test-Path -LiteralPath $script:DataDir)) {
    New-Item -ItemType Directory -Path $script:DataDir -Force | Out-Null
}

# ----------------------------------------------------------------- native helpers (C# 5, compiled on demand)
$script:NativeCode = @'
using System;
using System.Runtime.InteropServices;

public static class GameBoostNative
{
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr handle);

    [DllImport("psapi.dll", SetLastError = true)]
    public static extern bool EmptyWorkingSet(IntPtr process);

    [DllImport("powrprof.dll")]
    public static extern uint PowerSetActiveOverlayScheme(Guid overlay);

    [DllImport("powrprof.dll")]
    public static extern uint PowerGetEffectiveOverlayScheme(out Guid overlay);

    [DllImport("ntdll.dll")]
    private static extern int NtSetSystemInformation(int infoClass, ref int info, int length);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool LookupPrivilegeValue(string system, string name, out long luid);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool AdjustTokenPrivileges(IntPtr token, bool disableAll, ref TokenPrivileges newState,
                                                     int length, IntPtr previous, IntPtr returnLength);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetCurrentProcess();

    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    private struct TokenPrivileges
    {
        public int Count;
        public long Luid;
        public int Attributes;
    }

    public static bool EnablePrivilege(string name)
    {
        IntPtr token;
        // TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY
        if (!OpenProcessToken(GetCurrentProcess(), 0x0028, out token)) return false;
        try
        {
            TokenPrivileges tp = new TokenPrivileges();
            tp.Count = 1;
            tp.Attributes = 2; // SE_PRIVILEGE_ENABLED
            if (!LookupPrivilegeValue(null, name, out tp.Luid)) return false;
            return AdjustTokenPrivileges(token, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
        }
        finally
        {
            CloseHandle(token);
        }
    }

    // Frees the standby list (cached RAM) - same thing RAMMap "Empty Standby List" does.
    public static int PurgeStandbyList()
    {
        EnablePrivilege("SeProfileSingleProcessPrivilege");
        int command = 4;                                            // MemoryPurgeStandbyList
        return NtSetSystemInformation(80, ref command, sizeof(int)); // SystemMemoryListInformation
    }
}
'@

function Initialize-Native {
    if ('GameBoostNative' -as [type]) { return $true }
    try {
        Add-Type -TypeDefinition $script:NativeCode -Language CSharp -ErrorAction Stop
        return $true
    } catch {
        Write-Log "Add-Type failed: $($_.Exception.Message)"
        return $false
    }
}

# ----------------------------------------------------------------- output helpers
function Write-Log([string]$Text) {
    try {
        Add-Content -LiteralPath $script:LogFile -Value ('{0}  {1}' -f (Get-Date -Format 's'), $Text) -ErrorAction Stop
    } catch { }
}
function Write-Step([string]$Text)      { Write-Host ''; Write-Host (' >> ' + $Text) -ForegroundColor Cyan; Write-Log "STEP $Text" }
function Write-Ok([string]$Text)        { Write-Host ('    [OK] ' + $Text) -ForegroundColor Green }
function Write-Info([string]$Text)      { Write-Host ('         ' + $Text) -ForegroundColor Gray }
function Write-Skip([string]$Text)      { Write-Host ('    [--] ' + $Text) -ForegroundColor DarkGray }
function Write-Attention([string]$Text) { Write-Host ('    [!!] ' + $Text) -ForegroundColor Yellow; Write-Log "WARN $Text" }

function Write-Banner {
    Clear-Host
    $line = ' ' + ('=' * 62)
    Write-Host $line -ForegroundColor DarkCyan
    Write-Host ('    G A M E B O O S T   v{0}   -   more FPS, less lag, less RAM' -f $script:Version) -ForegroundColor Cyan
    Write-Host $line -ForegroundColor DarkCyan
}

function Wait-Enter {
    Write-Host ''
    [void](Read-Host ' Press Enter to continue')
}

# Reads an answer and turns Arabic / Persian digits into 0-9 (works with an Arabic keyboard).
function Read-Choice([string]$Prompt) {
    $s  = [string](Read-Host $Prompt)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.Trim().ToCharArray()) {
        $code = [int]$ch
        if ($code -ge 0x0660 -and $code -le 0x0669)     { [void]$sb.Append([char](48 + $code - 0x0660)) }
        elseif ($code -ge 0x06F0 -and $code -le 0x06F9) { [void]$sb.Append([char](48 + $code - 0x06F0)) }
        else                                            { [void]$sb.Append($ch) }
    }
    return $sb.ToString().ToLower()
}

# ----------------------------------------------------------------- backup / undo storage
function New-EmptyBackup {
    $script:Backup = [ordered]@{
        Version      = $script:Version
        Created      = (Get-Date).ToString('s')
        PowerScheme  = $null
        PowerOverlay = $null
        Registry     = New-Object System.Collections.ArrayList
        CreatedKeys  = New-Object System.Collections.ArrayList
        Services     = New-Object System.Collections.ArrayList
        Tasks        = New-Object System.Collections.ArrayList
    }
}

function Import-Backup {
    New-EmptyBackup
    if (-not (Test-Path -LiteralPath $script:BackupFile)) { return }
    try {
        $j = Get-Content -LiteralPath $script:BackupFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Attention "Backup file could not be read: $($_.Exception.Message)"
        return
    }
    if ($j.Created)      { $script:Backup.Created      = $j.Created }
    if ($j.PowerScheme)  { $script:Backup.PowerScheme  = $j.PowerScheme }
    if ($j.PowerOverlay) { $script:Backup.PowerOverlay = $j.PowerOverlay }
    foreach ($section in 'Registry', 'CreatedKeys', 'Services', 'Tasks') {
        foreach ($e in @($j.$section)) {
            if ($null -ne $e) { [void]$script:Backup[$section].Add($e) }
        }
    }
}

function Export-Backup {
    try {
        $script:Backup | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $script:BackupFile -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Attention "Could not save the backup file: $($_.Exception.Message)"
    }
}

function ConvertTo-Hex([byte[]]$Bytes) {
    if (-not $Bytes) { return '' }
    return (($Bytes | ForEach-Object { $_.ToString('X2') }) -join '')
}

function ConvertFrom-Hex([string]$Hex) {
    $count = [int]($Hex.Length / 2)
    $bytes = New-Object byte[] $count
    for ($i = 0; $i -lt $count; $i++) { $bytes[$i] = [Convert]::ToByte($Hex.Substring($i * 2, 2), 16) }
    return , $bytes
}

# Remembers the ORIGINAL value once (re-running GameBoost never overwrites the original).
function Save-RegValue([string]$Path, [string]$Name) {
    foreach ($e in $script:Backup.Registry) {
        if ($e.Path -eq $Path -and $e.Name -eq $Name) { return }
    }
    $entry = [pscustomobject]@{ Path = $Path; Name = $Name; Existed = $false; Type = ''; Value = $null }
    if (Test-Path -LiteralPath $Path) {
        $key = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
        if ($key -and (@($key.GetValueNames()) -contains $Name)) {
            $kind = $key.GetValueKind($Name).ToString()
            $raw  = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if ($kind -eq 'Binary') { $raw = ConvertTo-Hex $raw }
            $entry.Existed = $true
            $entry.Type    = $kind
            $entry.Value   = $raw
        }
    }
    [void]$script:Backup.Registry.Add($entry)
}

function Set-Reg {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [ValidateSet('DWord', 'QWord', 'String', 'ExpandString', 'MultiString', 'Binary')]
        [string]$Type = 'DWord'
    )
    try {
        Save-RegValue -Path $Path -Name $Name
        if (-not (Test-Path -LiteralPath $Path)) {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
            if ($script:Backup.CreatedKeys -notcontains $Path) { [void]$script:Backup.CreatedKeys.Add($Path) }
        }
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Log "Set-Reg failed: $Path | $Name : $($_.Exception.Message)"
    }
}

function Set-ServiceStartup([string]$Name, [string]$Startup) {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
    if (-not (Test-Path -LiteralPath $regPath)) { return $false }
    $p = Get-ItemProperty -LiteralPath $regPath -ErrorAction SilentlyContinue
    if ($null -eq $p -or $null -eq $p.Start) { return $false }
    $target = 3
    $scMode = 'demand'
    if ($Startup -eq 'Disabled') { $target = 4; $scMode = 'disabled' }
    if ([int]$p.Start -eq $target) { return $true }

    $known = $false
    foreach ($s in $script:Backup.Services) { if ($s.Name -eq $Name) { $known = $true; break } }
    if (-not $known) {
        [void]$script:Backup.Services.Add([pscustomobject]@{
            Name    = $Name
            Start   = [int]$p.Start
            Delayed = [int]$p.DelayedAutostart
        })
    }
    $null = & sc.exe config $Name start= $scMode 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Log "sc config $Name failed (exit $LASTEXITCODE)"
        return $false
    }
    Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    return $true
}

function Disable-TaskSafe([string]$TaskPath, [string]$TaskName) {
    $t = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $t -or [string]$t.State -eq 'Disabled') { return $false }
    try {
        Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop | Out-Null
        [void]$script:Backup.Tasks.Add([pscustomobject]@{ TaskPath = $TaskPath; TaskName = $TaskName })
        return $true
    } catch {
        Write-Log "Task $TaskPath$TaskName could not be disabled: $($_.Exception.Message)"
        return $false
    }
}

# ----------------------------------------------------------------- info helpers
function Get-RamTotalMB {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if (-not $os) { return 0 }
    return [math]::Round($os.TotalVisibleMemorySize / 1KB)
}

function Get-RamInUseMB {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if (-not $os) { return 0 }
    $totalMB = $os.TotalVisibleMemorySize / 1KB
    $availMB = $null
    try { $availMB = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory -ErrorAction Stop).AvailableMBytes } catch { }
    if (-not $availMB) { $availMB = $os.FreePhysicalMemory / 1KB }
    return [math]::Round($totalMB - $availMB)
}

function Get-ActiveSchemeGuid {
    $o = (powercfg /getactivescheme) -join ' '
    $m = [regex]::Match($o, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
    if ($m.Success) { return $m.Value.ToLower() }
    return $null
}

function Test-SchemeExists([string]$Guid) {
    return ((powercfg /list) -join "`n") -match [regex]::Escape($Guid)
}

function Test-SystemDriveIsSsd {
    try {
        $part = Get-Partition -DriveLetter ($env:SystemDrive.TrimEnd(':')) -ErrorAction Stop
        $disk = Get-PhysicalDisk -ErrorAction Stop | Where-Object { $_.DeviceId -eq [string]$part.DiskNumber } | Select-Object -First 1
        if ($disk -and [string]$disk.MediaType -eq 'HDD') { return $false }
    } catch { }
    return $true
}

function Test-AppInstalled([string]$Pattern) {
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($r in $roots) {
        $hit = Get-ItemProperty -Path $r -ErrorAction SilentlyContinue |
               Where-Object { $_.DisplayName -and $_.DisplayName -match $Pattern } |
               Select-Object -First 1
        if ($hit) { return $true }
    }
    return $false
}

# Installs an app with winget. Tries the given ids, then looks the id up by exact name.
function Install-WithWinget([string[]]$Ids, [string]$ExactName) {
    if (-not (Get-Command 'winget.exe' -ErrorAction SilentlyContinue)) { return $false }
    $candidates = New-Object System.Collections.Generic.List[string]
    foreach ($i in $Ids) { if ($i) { $candidates.Add($i) } }
    if ($ExactName) {
        $out = & winget.exe search --name $ExactName --source winget --accept-source-agreements 2>$null
        foreach ($line in @($out)) {
            $m = [regex]::Match([string]$line, '^\s*' + [regex]::Escape($ExactName) + '\s{2,}(\S+)\s', 'IgnoreCase')
            if ($m.Success -and -not $candidates.Contains($m.Groups[1].Value)) { $candidates.Add($m.Groups[1].Value) }
        }
    }
    foreach ($id in $candidates) {
        Write-Info "Installing $id with winget (official package)..."
        & winget.exe install --id $id --exact --silent --source winget --accept-package-agreements --accept-source-agreements | Out-Host
        if ($LASTEXITCODE -eq 0) { return $true }
    }
    return $false
}

# ================================================================= APPLY STEPS

function New-SafetyRestorePoint {
    Write-Step 'Safety first: creating a System Restore point'
    try {
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' 0
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'GameBoost - before tweaks' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Ok 'Restore point created'
    } catch {
        Write-Attention "No restore point ($($_.Exception.Message)). Continuing - GameBoost still keeps its own backup for Undo."
    }
}

function Set-CpuPowerPlan {
    Write-Step 'CPU: maximum-performance power plan (Windows drives the CPU automatically)'
    $active = Get-ActiveSchemeGuid
    if ($active -and $active -ne $script:SchemeGuid -and -not $script:Backup.PowerScheme) {
        $script:Backup.PowerScheme = $active
    }

    if (-not (Test-SchemeExists $script:SchemeGuid)) {
        $null = powercfg /duplicatescheme $script:UltimateGuid $script:SchemeGuid 2>&1
        if (-not (Test-SchemeExists $script:SchemeGuid)) {
            $null = powercfg /duplicatescheme $script:HighGuid $script:SchemeGuid 2>&1
        }
    }

    if (Test-SchemeExists $script:SchemeGuid) {
        $null = powercfg /changename $script:SchemeGuid 'GameBoost' 'Maximum performance for gaming (GameBoost)' 2>&1
        # Plugged in (AC): full speed, no core parking, no PCIe/USB power saving.
        $ac = @(
            @('SUB_PROCESSOR', 'PROCTHROTTLEMIN', 100),
            @('SUB_PROCESSOR', 'PROCTHROTTLEMAX', 100),
            @('SUB_PROCESSOR', 'CPMINCORES', 100),
            @('SUB_PCIEXPRESS', 'ASPM', 0),
            @('2a737441-1930-4402-8d77-b2bebba308a3', '48e6b7a6-50f5-4782-a5d4-53bb8f07e226', 0),
            @('SUB_DISK', 'DISKIDLE', 0)
        )
        foreach ($s in $ac) { $null = powercfg /setacvalueindex $script:SchemeGuid $s[0] $s[1] $s[2] 2>&1 }
        # On battery (laptops) let the CPU slow down when idle so the battery is not drained.
        $null = powercfg /setdcvalueindex $script:SchemeGuid SUB_PROCESSOR PROCTHROTTLEMIN 5 2>&1
        $null = powercfg /setactive $script:SchemeGuid 2>&1
    }

    if ((Get-ActiveSchemeGuid) -eq $script:SchemeGuid) {
        Write-Ok 'GameBoost power plan active: CPU runs at full speed while plugged in'
        return
    }

    # Laptops with Modern Standby only allow "Balanced" -> switch its power mode to "Best performance".
    if (Initialize-Native) {
        try {
            $cur = [guid]::Empty
            [void][GameBoostNative]::PowerGetEffectiveOverlayScheme([ref]$cur)
            if (-not $script:Backup.PowerOverlay) { $script:Backup.PowerOverlay = $cur.ToString() }
            if ([GameBoostNative]::PowerSetActiveOverlayScheme([guid]$script:BestPerfOverlay) -eq 0) {
                Write-Ok 'Power mode set to "Best performance"'
                return
            }
        } catch { Write-Log "Overlay: $($_.Exception.Message)" }
    }
    Write-Attention 'Could not change the power plan on this PC (kept Windows default)'
}

function Set-GameAndGpuSettings {
    Write-Step 'Games: Game Mode ON, background recording OFF, games get top CPU/GPU priority'
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'HistoricalCaptureEnabled' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0

    $mm = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    Set-Reg $mm 'SystemResponsiveness' 10
    Set-Reg $mm 'NetworkThrottlingIndex' (-1)          # 0xFFFFFFFF = no network throttling
    $games = "$mm\Tasks\Games"
    Set-Reg $games 'GPU Priority' 8
    Set-Reg $games 'Priority' 6
    Set-Reg $games 'Scheduling Category' 'High' 'String'
    Set-Reg $games 'SFIO Priority' 'High' 'String'
    Write-Ok 'Game Mode ON, Game DVR recording OFF, multimedia scheduler favours games'

    Write-Step 'GPU: hardware-accelerated GPU scheduling + optimizations for windowed games'
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2
    $dx  = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    $cur = ''
    if (Test-Path -LiteralPath $dx) {
        $cur = [string](Get-ItemProperty -LiteralPath $dx -Name 'DirectXUserGlobalSettings' -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
    }
    $pairs = [ordered]@{}
    foreach ($part in ($cur -split ';')) {
        if ($part -match '^\s*([^=]+?)\s*=\s*(.*?)\s*$') { $pairs[$Matches[1]] = $Matches[2] }
    }
    $pairs['SwapEffectUpgradeEnable'] = '1'
    $newValue = (($pairs.GetEnumerator() | ForEach-Object { '{0}={1}' -f $_.Key, $_.Value }) -join ';') + ';'
    Set-Reg $dx 'DirectXUserGlobalSettings' $newValue 'String'
    Write-Ok 'GPU scheduling ON (works on GTX 10xx / RX 5000 / Intel Arc and newer, after restart)'
}

function Set-CpuScheduling {
    Write-Step 'CPU: the game window gets more CPU time than background apps'
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 38   # 0x26
    Write-Ok 'Foreground priority boost set'
}

function Disable-ExtraServices {
    Write-Step 'Services: turn off the ones a gaming PC does not need'
    $disable = [ordered]@{
        'DiagTrack'        = 'Telemetry (sends usage data to Microsoft)'
        'dmwappushservice' = 'Telemetry push messages'
        'MapsBroker'       = 'Offline maps downloader'
        'RetailDemo'       = 'Shop demo mode'
        'Fax'              = 'Fax'
        'wisvc'            = 'Windows Insider'
        'WpcMonSvc'        = 'Parental controls monitor'
        'WerSvc'           = 'Error reporting'
        'WMPNetworkSvc'    = 'Media Player network sharing'
        'WSearch'          = 'Search indexer (uses a lot of RAM and disk)'
    }
    if (Test-SystemDriveIsSsd) {
        $disable['SysMain'] = 'SysMain / Superfetch (fills RAM with preloaded apps)'
    } else {
        Write-Skip 'SysMain kept ON because Windows is on a hard disk (HDD)'
    }
    $manual = [ordered]@{
        'PcaSvc'      = 'Program Compatibility Assistant'
        'TrkWks'      = 'Distributed Link Tracking'
        'edgeupdate'  = 'Edge updater (Edge still updates)'
        'edgeupdatem' = 'Edge updater'
    }
    $printers = @(Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -notmatch 'PDF|XPS|OneNote|Fax|Send To' })
    if ($printers.Count -eq 0) {
        $manual['Spooler'] = 'Print spooler (no printer found)'
    } else {
        Write-Skip 'Print spooler kept ON (a printer is installed)'
    }
    foreach ($k in @($disable.Keys)) { if (Set-ServiceStartup $k 'Disabled') { Write-Ok ('Off    : ' + $disable[$k]) } }
    foreach ($k in @($manual.Keys))  { if (Set-ServiceStartup $k 'Manual')   { Write-Ok ('Manual : ' + $manual[$k]) } }
}

function Disable-TelemetryTasks {
    Write-Step 'Scheduled tasks: stop background telemetry jobs (fewer CPU spikes while playing)'
    $tasks = @(
        @('\Microsoft\Windows\Application Experience\', 'Microsoft Compatibility Appraiser'),
        @('\Microsoft\Windows\Application Experience\', 'ProgramDataUpdater'),
        @('\Microsoft\Windows\Application Experience\', 'MareBackup'),
        @('\Microsoft\Windows\Application Experience\', 'PcaPatchDbTask'),
        @('\Microsoft\Windows\Customer Experience Improvement Program\', 'Consolidator'),
        @('\Microsoft\Windows\Customer Experience Improvement Program\', 'UsbCeip'),
        @('\Microsoft\Windows\Autochk\', 'Proxy'),
        @('\Microsoft\Windows\DiskDiagnostic\', 'Microsoft-Windows-DiskDiagnosticDataCollector'),
        @('\Microsoft\Windows\Feedback\Siuf\', 'DmClient'),
        @('\Microsoft\Windows\Feedback\Siuf\', 'DmClientOnScenarioDownload'),
        @('\Microsoft\Windows\Windows Error Reporting\', 'QueueReporting'),
        @('\Microsoft\Windows\Maps\', 'MapsUpdateTask'),
        @('\Microsoft\Windows\Maps\', 'MapsToastTask')
    )
    $n = 0
    foreach ($t in $tasks) { if (Disable-TaskSafe $t[0] $t[1]) { $n++ } }
    if ($n -gt 0) { Write-Ok "$n background tasks disabled" } else { Write-Skip 'Nothing to change' }
}

function Disable-StartupApps {
    Write-Step 'Startup: heavy apps no longer auto-start (they still open normally when YOU open them)'
    $patterns = @(
        '^MicrosoftEdgeAutoLaunch', 'Teams', '^Spotify', 'Skype', 'CCleaner', 'Browser ?Assistant',
        'uTorrent|BitTorrent', '^Steam$', 'EpicGamesLauncher', '^EADM$|EA ?Desktop|^EA ?App$|^Origin$',
        'Ubisoft|Uplay', 'Battle\.net', '^Discord$', 'Overwolf',
        'AdobeGCInvoker|Adobe Creative Cloud|CCXProcess|AdobeAAMUpdater', 'iTunesHelper', '^Cortana'
    )
    $rx = '(' + ($patterns -join ')|(') + ')'
    $approvedRoot = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    $disabledBytes = [byte[]](@(3, 0, 0, 0) + [BitConverter]::GetBytes([DateTime]::Now.ToFileTime()))
    $names = New-Object System.Collections.Generic.List[string]

    $runKeys = @(
        @{ Run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';             Approved = "HKCU:\$approvedRoot\Run" },
        @{ Run = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';             Approved = "HKLM:\$approvedRoot\Run" },
        @{ Run = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$approvedRoot\Run32" }
    )
    foreach ($src in $runKeys) {
        if (-not (Test-Path -LiteralPath $src.Run)) { continue }
        $key = Get-Item -LiteralPath $src.Run -ErrorAction SilentlyContinue
        if (-not $key) { continue }
        foreach ($n in $key.GetValueNames()) {
            if ($n -and $n -match $rx) {
                Set-Reg $src.Approved $n $disabledBytes 'Binary'
                $names.Add($n)
            }
        }
    }

    $folders = @(
        @{ Dir = [Environment]::GetFolderPath('Startup');       Approved = "HKCU:\$approvedRoot\StartupFolder" },
        @{ Dir = [Environment]::GetFolderPath('CommonStartup'); Approved = "HKLM:\$approvedRoot\StartupFolder" }
    )
    foreach ($f in $folders) {
        if (-not $f.Dir -or -not (Test-Path -LiteralPath $f.Dir)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $f.Dir -File -ErrorAction SilentlyContinue)) {
            if ($file.BaseName -match $rx) {
                Set-Reg $f.Approved $file.Name $disabledBytes 'Binary'
                $names.Add($file.BaseName)
            }
        }
    }

    # Microsoft Store apps (new Teams, Spotify from the Store, ...)
    $appData = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData'
    $uwp = 'MSTeams|MicrosoftTeams|SpotifyAB|Microsoft\.SkypeApp|Microsoft\.549981C3F5F10|Microsoft\.Copilot'
    if (Test-Path -LiteralPath $appData) {
        foreach ($pkg in @(Get-ChildItem -LiteralPath $appData -ErrorAction SilentlyContinue)) {
            if ($pkg.PSChildName -notmatch $uwp) { continue }
            foreach ($task in @(Get-ChildItem -LiteralPath $pkg.PSPath -ErrorAction SilentlyContinue)) {
                $state = (Get-ItemProperty -LiteralPath $task.PSPath -Name 'State' -ErrorAction SilentlyContinue).State
                if ($state -eq 2) {
                    Set-Reg ('{0}\{1}\{2}' -f $appData, $pkg.PSChildName, $task.PSChildName) 'State' 1
                    $names.Add($pkg.PSChildName.Split('_')[0])
                }
            }
        }
    }

    if ($names.Count -gt 0) {
        Write-Ok ('No auto-start any more: ' + ((@($names) | Select-Object -Unique) -join ', '))
    } else {
        Write-Skip 'No heavy startup apps found'
    }
}

function Disable-BackgroundBloat {
    Write-Step 'RAM savers: Widgets/News, Edge running in background, auto-installed apps, telemetry'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'StartupBoostEnabled' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Edge' 'BackgroundModeEnabled' 0
    $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    foreach ($n in 'SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled', 'SoftLandingEnabled',
                   'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled',
                   'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled') {
        Set-Reg $cdm $n 0
    }
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
    Write-Ok 'Widgets OFF, Edge no longer runs after you close it, no silent app installs'
}

function Set-NetworkLatency {
    Write-Step 'Network: lower ping and less lag'
    $root = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
    $n = 0
    foreach ($nic in @(Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) {
        $p = Get-ItemProperty -LiteralPath $nic.PSPath -ErrorAction SilentlyContinue
        $ips = @(@($p.DhcpIPAddress) + @($p.IPAddress) | Where-Object { $_ -and $_ -ne '0.0.0.0' })
        if ($ips.Count -eq 0) { continue }
        $path = '{0}\{1}' -f $root, $nic.PSChildName
        Set-Reg $path 'TcpAckFrequency' 1
        Set-Reg $path 'TCPNoDelay' 1
        $n++
    }
    # Do not upload Windows updates to other PCs on the internet (saves upload bandwidth / ping).
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0
    Write-Ok "Nagle delay OFF on $n network adapter(s), update-sharing upload OFF"
}

function Set-VisualAndMouse {
    Write-Step 'Windows look: performance mode (fonts stay smooth) + raw mouse input'
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 3
    Set-Reg 'HKCU:\Control Panel\Desktop' 'UserPreferencesMask' ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) 'Binary'
    Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' 0
    # "Enhance pointer precision" OFF = 1:1 mouse aim in games
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'
    Write-Ok 'Animations and transparency OFF, mouse acceleration OFF'
}

function Optimize-ProcessesAndClean {
    Write-Step 'Fewer background processes + clean temporary files'
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($cs) {
        # Group Windows services into fewer svchost.exe processes (threshold above the installed RAM).
        $kb = [int64]($cs.TotalPhysicalMemory / 1KB) + 1048576
        if ($kb -gt 0 -and $kb -lt [int]::MaxValue) {
            Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB' ([int]$kb)
            Write-Ok 'Windows services grouped into fewer processes (after restart)'
        }
    }
    $freed = [int64]0
    foreach ($dir in @($env:TEMP, (Join-Path $env:SystemRoot 'Temp'))) {
        if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { continue }
        foreach ($item in @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)) {
            try {
                $size = 0
                if ($item.PSIsContainer) {
                    $size = (Get-ChildItem -LiteralPath $item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue |
                             Measure-Object -Property Length -Sum).Sum
                } else {
                    $size = $item.Length
                }
                Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                if ($size) { $freed += [int64]$size }
            } catch { }   # file in use - skip it
        }
    }
    Write-Ok ('Temp files cleaned: {0:N0} MB' -f ($freed / 1MB))
}

function Set-GpuDriverUpdates {
    Write-Step 'GPU driver: keep it updated automatically'
    # 1) Windows Update is allowed to install new drivers by itself.
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' 'SearchOrderConfig' 1
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata' 'PreventDeviceMetadataFromNetwork' 0
    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $ex = Get-ItemProperty -LiteralPath $wu -Name 'ExcludeWUDriversInQualityUpdate' -ErrorAction SilentlyContinue
    if ($ex -and $ex.ExcludeWUDriversInQualityUpdate -eq 1) { Set-Reg $wu 'ExcludeWUDriversInQualityUpdate' 0 }
    Write-Ok 'Windows Update may install new drivers automatically'

    # 2) The GPU maker's own updater (newest game-ready drivers).
    $gpus   = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    $nvidia = @($gpus | Where-Object { $_.PNPDeviceID -match 'VEN_10DE' })
    $amd    = @($gpus | Where-Object { $_.PNPDeviceID -match 'VEN_1002' })
    $intel  = @($gpus | Where-Object { $_.PNPDeviceID -match 'VEN_8086' })
    foreach ($g in $gpus) { Write-Info ('Found GPU: {0}  (driver {1})' -f $g.Name, $g.DriverVersion) }

    if ($nvidia.Count -gt 0) {
        if (Test-AppInstalled '^NVIDIA app|GeForce Experience') {
            Write-Ok 'NVIDIA app is installed - it downloads new drivers for you'
        } elseif (Install-WithWinget -Ids @('Nvidia.NVIDIAApp') -ExactName 'NVIDIA app') {
            Write-Ok 'NVIDIA app installed - it downloads new drivers for you'
        } else {
            Write-Attention 'Could not install NVIDIA app automatically - opening the official page'
            Start-Process 'https://www.nvidia.com/en-us/software/nvidia-app/'
        }
        Write-Info 'Tip: in NVIDIA app settings turn ON automatic driver downloads.'
    }

    if ($amd.Count -gt 0) {
        if (Test-AppInstalled '^AMD Software') {
            Write-Ok 'AMD Software (Adrenalin) is installed - it checks for new drivers by itself'
        } else {
            Write-Attention 'AMD Software not found - opening AMD auto-detect page (download + run it once)'
            Start-Process 'https://www.amd.com/en/support/download/drivers.html'
        }
        Write-Info 'Tip: AMD Software > Settings > System > Check for updates = Automatic.'
    }

    $intelArc = @($intel | Where-Object { $_.Name -match 'Arc' })
    if ($intel.Count -gt 0 -and (($nvidia.Count + $amd.Count) -eq 0 -or $intelArc.Count -gt 0)) {
        if (Test-AppInstalled 'Intel.*Driver.*Support Assistant') {
            Write-Ok 'Intel Driver & Support Assistant is installed'
        } elseif (Install-WithWinget -Ids @('Intel.IntelDriverAndSupportAssistant') -ExactName '') {
            Write-Ok 'Intel Driver & Support Assistant installed - it keeps Intel drivers updated'
        } else {
            Write-Attention 'Could not install Intel DSA automatically - opening the official page'
            Start-Process 'https://www.intel.com/content/www/us/en/support/detect.html'
        }
    }

    if (($nvidia.Count + $amd.Count + $intel.Count) -eq 0) {
        Write-Skip 'No NVIDIA / AMD / Intel GPU detected - Windows Update will handle the driver'
    }

    try {
        Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\UsoClient.exe') -ArgumentList 'StartScan' -WindowStyle Hidden -ErrorAction Stop
        Write-Ok 'Windows Update asked to look for new drivers now'
    } catch { }
}

function New-CleanRamShortcut {
    Write-Step 'Desktop shortcut for the pre-game RAM cleanup'
    try {
        $installed = Join-Path $script:DataDir 'GameBoost.ps1'
        if ($PSCommandPath -ne $installed) { Copy-Item -LiteralPath $PSCommandPath -Destination $installed -Force -ErrorAction Stop }
        $desktop = [Environment]::GetFolderPath('Desktop')
        $wsh = New-Object -ComObject WScript.Shell
        $lnk = $wsh.CreateShortcut((Join-Path $desktop $script:ShortcutName))
        $lnk.TargetPath  = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $lnk.Arguments   = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Mode CleanRam' -f $installed
        $lnk.Description = 'Free RAM before playing (GameBoost)'
        $lnk.IconLocation = (Join-Path $env:SystemRoot 'System32\shell32.dll') + ',12'
        $lnk.Save()
        Write-Ok "Created on your desktop: 'GameBoost - Clean RAM' (double-click it before playing)"
    } catch {
        Write-Skip "Shortcut not created: $($_.Exception.Message)"
    }
}

function Invoke-Apply {
    Write-Banner
    Write-Host ' Applying GameBoost. It takes 1-3 minutes - do not close this window.' -ForegroundColor White
    Write-Log '===== APPLY start ====='
    Import-Backup
    $ramBefore = Get-RamInUseMB

    $steps = @(
        { New-SafetyRestorePoint },
        { Set-CpuPowerPlan },
        { Set-GameAndGpuSettings },
        { Set-CpuScheduling },
        { Disable-ExtraServices },
        { Disable-TelemetryTasks },
        { Disable-StartupApps },
        { Disable-BackgroundBloat },
        { Set-NetworkLatency },
        { Set-VisualAndMouse },
        { Optimize-ProcessesAndClean },
        { Set-GpuDriverUpdates },
        { New-CleanRamShortcut }
    )
    foreach ($s in $steps) {
        try { & $s } catch {
            Write-Attention "A step had a problem: $($_.Exception.Message)"
            Write-Log $_.ScriptStackTrace
        }
        Export-Backup   # saved after every step, so Undo always works
    }

    $changes = $script:Backup.Registry.Count + $script:Backup.Services.Count + $script:Backup.Tasks.Count
    Write-Log "===== APPLY done ($changes changes) ====="
    Write-Host ''
    Write-Host (' ' + ('-' * 62)) -ForegroundColor DarkCyan
    $ramAfter = Get-RamInUseMB
    $doneText = ' DONE!  GameBoost changed {0} settings.  RAM in use now: {1:N1} GB (was {2:N1} GB)' -f $changes, ($ramAfter / 1024), ($ramBefore / 1024)
    Write-Host $doneText -ForegroundColor Green
    Write-Host '  - RESTART the PC so everything takes effect (RAM drops more after restart).'
    Write-Host '  - Before playing: double-click "GameBoost - Clean RAM" on your desktop.'
    Write-Host '  - Laptop: keep the charger plugged in while gaming.'
    Write-Host '  - Undo everything any time: open GameBoost and choose [6].'
    Write-Host (' ' + ('-' * 62)) -ForegroundColor DarkCyan
    $ans = Read-Choice ' Restart now?  [1] Yes   [2] Later'
    if ($ans -eq '1' -or $ans -eq 'y') { Restart-Computer -Force }
}

# ================================================================= PRE-GAME RAM CLEANUP

function Invoke-CleanRam {
    Write-Banner
    Write-Step 'Pre-game cleanup: freeing RAM and closing background helpers'
    $before = Get-RamInUseMB

    # 1) Close background helpers that are not needed while gaming (they come back by themselves later).
    $helpers = @('Widgets', 'WidgetService', 'PhoneExperienceHost', 'YourPhone', 'Cortana',
                 'SkypeApp', 'SkypeBackgroundHost')
    $closed = @(Get-Process -Name $helpers -ErrorAction SilentlyContinue)
    $closed | Stop-Process -Force -ErrorAction SilentlyContinue
    if ($closed.Count -gt 0) { Write-Ok ('Closed: ' + ((@($closed.ProcessName) | Select-Object -Unique) -join ', ')) }

    if (Initialize-Native) {
        # 2) Trim the RAM held by idle background programs (Windows gives it to the game instead).
        $skip = @('System', 'Idle', 'Registry', 'Memory Compression', 'MemCompression', 'smss', 'csrss',
                  'wininit', 'winlogon', 'services', 'lsass', 'dwm', 'audiodg', 'explorer', 'fontdrvhost',
                  'MsMpEng', 'NisSrv', 'SecurityHealthService', 'sihost', 'ctfmon', 'TextInputHost')
        $trimmed = 0
        foreach ($p in @(Get-Process -ErrorAction SilentlyContinue)) {
            if ($p.Id -le 4 -or $p.Id -eq $PID -or $skip -contains $p.ProcessName) { continue }
            $h = [GameBoostNative]::OpenProcess(0x1100, $false, $p.Id)   # SET_QUOTA | QUERY_LIMITED_INFORMATION
            if ($h -ne [IntPtr]::Zero) {
                if ([GameBoostNative]::EmptyWorkingSet($h)) { $trimmed++ }
                [void][GameBoostNative]::CloseHandle($h)
            }
        }
        Write-Ok "Trimmed idle RAM of $trimmed background processes"

        # 3) Empty the standby list (old cached files) - reduces stutter in long sessions.
        $status = [GameBoostNative]::PurgeStandbyList()
        if ($status -eq 0) { Write-Ok 'Standby (cached) memory emptied' } else { Write-Skip ('Standby list not emptied (status 0x{0:X8})' -f $status) }
    } else {
        Write-Attention 'RAM trimming is not available on this PC'
    }

    # 4) Make sure the GameBoost power plan is the active one.
    if ((Test-SchemeExists $script:SchemeGuid) -and (Get-ActiveSchemeGuid) -ne $script:SchemeGuid) {
        $null = powercfg /setactive $script:SchemeGuid 2>&1
        Write-Ok 'GameBoost power plan re-activated'
    }

    $after = Get-RamInUseMB
    Write-Host ''
    Write-Host (' RAM in use: {0:N0} MB  ->  {1:N0} MB   (freed {2:N0} MB)' -f $before, $after, [math]::Max(0, $before - $after)) -ForegroundColor Green
    Write-Host ' Now start your game. Good luck!' -ForegroundColor Cyan
}

# ================================================================= BOOST ONE GAME

function Invoke-BoostGame {
    Write-Banner
    Write-Step 'Boost a specific game: always use the strong GPU + high CPU priority'
    Write-Info 'Choose the game .exe (the game itself, not the launcher).'
    Write-Info 'Example: C:\Program Files (x86)\Steam\steamapps\common\<Game>\<game>.exe'
    $exe = $null
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $owner = New-Object System.Windows.Forms.Form
        $owner.TopMost = $true
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Filter = 'Game (*.exe)|*.exe'
        $dlg.Title  = 'GameBoost - choose the game .exe'
        if ($dlg.ShowDialog($owner) -eq [System.Windows.Forms.DialogResult]::OK) { $exe = $dlg.FileName }
        $owner.Dispose()
    } catch { }
    if (-not $exe) {
        $typed = [string](Read-Host '    Or paste the full path of the .exe (Enter = cancel)')
        $exe = ($typed -replace '"', '').Trim()
    }
    if (-not $exe -or -not (Test-Path -LiteralPath $exe -PathType Leaf) -or $exe -notmatch '\.exe$') {
        Write-Attention 'No game selected.'
        return
    }

    Import-Backup
    $name = [IO.Path]::GetFileName($exe)
    Set-Reg 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' $exe 'GpuPreference=2;' 'String'
    Set-Reg ('HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\{0}\PerfOptions' -f $name) 'CpuPriorityClass' 3
    Export-Backup
    Write-Ok "$name now always runs on the high-performance GPU"
    Write-Ok "$name now always starts with HIGH CPU priority"
    Write-Info 'Big win on laptops that have two GPUs. Do this for each game you play.'
}

# ================================================================= MEMORY INTEGRITY (optional)

function Invoke-MemoryIntegrityOff {
    Write-Banner
    Write-Step 'Advanced: turn OFF Memory Integrity (Core isolation)'
    $key = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
    $cur = (Get-ItemProperty -LiteralPath $key -Name 'Enabled' -ErrorAction SilentlyContinue).Enabled
    if ($cur -ne 1) {
        Write-Skip 'Memory Integrity is already OFF on this PC - nothing to do.'
        return
    }
    Write-Host ''
    Write-Host '    Microsoft says turning this off can give more FPS in games.' -ForegroundColor White
    Write-Host '    BUT it also lowers protection against some malware.' -ForegroundColor Yellow
    Write-Host '    If a game anti-cheat complains later, use [6] Undo to turn it back on.' -ForegroundColor Yellow
    Write-Host ''
    $ans = Read-Choice '    Type 1 to turn it OFF (anything else = cancel)'
    if ($ans -ne '1') { Write-Skip 'Cancelled - nothing changed.'; return }
    Import-Backup
    Set-Reg $key 'Enabled' 0
    Export-Backup
    Write-Ok 'Memory Integrity will be OFF after you restart the PC.'
}

# ================================================================= STATUS

function Show-Status {
    Write-Banner
    Write-Step 'Your PC'
    $os   = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cpu  = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    if ($os)  { Write-Info ('Windows   : {0} (build {1})' -f $os.Caption, $os.BuildNumber) }
    if ($cpu) { Write-Info ('CPU       : {0}  ({1} cores / {2} threads)' -f $cpu.Name.Trim(), $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors) }
    foreach ($g in $gpus) {
        $date = ''
        if ($g.DriverDate) { try { $date = ([datetime]$g.DriverDate).ToString('yyyy-MM-dd') } catch { } }
        Write-Info ('GPU       : {0}  (driver {1} {2})' -f $g.Name, $g.DriverVersion, $date)
    }
    Write-Info ('RAM       : {0:N1} GB in use of {1:N1} GB' -f ((Get-RamInUseMB) / 1024), ((Get-RamTotalMB) / 1024))
    Write-Info ('Processes : {0}' -f @(Get-Process).Count)
    Write-Info ('Power     : {0}' -f ((powercfg /getactivescheme) -join ' ').Trim())

    $hags = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -ErrorAction SilentlyContinue).HwSchMode
    $gm   = (Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\GameBar' -Name 'AutoGameModeEnabled' -ErrorAction SilentlyContinue).AutoGameModeEnabled
    $hvci = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name 'Enabled' -ErrorAction SilentlyContinue).Enabled
    Write-Info ('GPU scheduling   : {0}' -f $(if ($hags -eq 2) { 'ON' } else { 'OFF / default' }))
    Write-Info ('Game Mode        : {0}' -f $(if ($gm -eq 0) { 'OFF' } else { 'ON' }))
    Write-Info ('Memory Integrity : {0}' -f $(if ($hvci -eq 1) { 'ON' } else { 'OFF' }))
    Write-Info ('GameBoost        : {0}' -f $(if (Test-Path -LiteralPath $script:BackupFile) { 'APPLIED' } else { 'not applied' }))

    Write-Step 'Top 10 programs using RAM right now'
    Get-Process -ErrorAction SilentlyContinue |
        Group-Object -Property ProcessName |
        ForEach-Object {
            [pscustomobject]@{
                Program = $_.Name
                'RAM MB' = [math]::Round(($_.Group | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB)
                Copies  = $_.Count
            }
        } |
        Sort-Object -Property 'RAM MB' -Descending |
        Select-Object -First 10 |
        Format-Table -AutoSize | Out-Host
    Write-Info 'Close the big ones you do not need before playing (browser tabs use a lot!).'
}

# ================================================================= UNDO

function Invoke-Restore {
    Write-Banner
    Write-Step 'Undo: putting back your original settings'
    if (-not (Test-Path -LiteralPath $script:BackupFile)) {
        Write-Attention 'No GameBoost backup found - nothing to undo.'
        Write-Info 'You can also use Windows System Restore (point "GameBoost - before tweaks").'
        return
    }
    Import-Backup
    Write-Log '===== RESTORE start ====='

    $reg = @($script:Backup.Registry)
    [array]::Reverse($reg)
    $ok = 0
    foreach ($e in $reg) {
        try {
            if ($e.Existed) {
                if ($script:RegTypes -notcontains [string]$e.Type) { continue }
                $val = $e.Value
                switch ([string]$e.Type) {
                    'DWord'        { $val = [int]$val }
                    'QWord'        { $val = [long]$val }
                    'Binary'       { $val = ConvertFrom-Hex ([string]$val) }
                    'MultiString'  { $val = [string[]]@($val) }
                    'String'       { $val = [string]$val }
                    'ExpandString' { $val = [string]$val }
                }
                if (-not (Test-Path -LiteralPath $e.Path)) { New-Item -Path $e.Path -Force | Out-Null }
                New-ItemProperty -LiteralPath $e.Path -Name $e.Name -Value $val -PropertyType $e.Type -Force -ErrorAction Stop | Out-Null
            } else {
                if (Test-Path -LiteralPath $e.Path) {
                    Remove-ItemProperty -LiteralPath $e.Path -Name $e.Name -Force -ErrorAction SilentlyContinue
                }
            }
            $ok++
        } catch {
            Write-Log "Restore failed: $($e.Path) | $($e.Name) : $($_.Exception.Message)"
        }
    }
    Write-Ok "$ok registry settings restored"

    $keys = @($script:Backup.CreatedKeys)
    [array]::Reverse($keys)
    foreach ($k in $keys) {
        $item = Get-Item -LiteralPath $k -ErrorAction SilentlyContinue
        if ($item -and $item.ValueCount -eq 0 -and $item.SubKeyCount -eq 0) {
            Remove-Item -LiteralPath $k -Force -ErrorAction SilentlyContinue
        }
    }

    $sv = 0
    foreach ($s in $script:Backup.Services) {
        $mode = 'demand'
        switch ([int]$s.Start) {
            0 { $mode = 'boot' }
            1 { $mode = 'system' }
            2 { if ([int]$s.Delayed -eq 1) { $mode = 'delayed-auto' } else { $mode = 'auto' } }
            3 { $mode = 'demand' }
            4 { $mode = 'disabled' }
        }
        $null = & sc.exe config $s.Name start= $mode 2>&1
        if ($LASTEXITCODE -eq 0) { $sv++ }
        if ([int]$s.Start -eq 2) { Start-Service -Name $s.Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue }
    }
    Write-Ok "$sv services restored"

    $tk = 0
    foreach ($t in $script:Backup.Tasks) {
        try { Enable-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction Stop | Out-Null; $tk++ } catch { }
    }
    Write-Ok "$tk scheduled tasks re-enabled"

    $target = $script:Backup.PowerScheme
    if (-not $target -or -not (Test-SchemeExists $target)) { $target = $script:BalancedGuid }
    $null = powercfg /setactive $target 2>&1
    if (Test-SchemeExists $script:SchemeGuid) { $null = powercfg /delete $script:SchemeGuid 2>&1 }
    if ($script:Backup.PowerOverlay -and (Initialize-Native)) {
        try { [void][GameBoostNative]::PowerSetActiveOverlayScheme([guid]$script:Backup.PowerOverlay) } catch { }
    }
    Write-Ok 'Original power plan restored'

    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) $script:ShortcutName
    if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Move-Item -LiteralPath $script:BackupFile -Destination (Join-Path $script:DataDir "backup-restored-$stamp.json") -Force -ErrorAction SilentlyContinue
    Write-Log '===== RESTORE done ====='
    Write-Host ''
    Write-Host ' Everything is back to how it was. Restart the PC to finish.' -ForegroundColor Green
    $ans = Read-Choice ' Restart now?  [1] Yes   [2] Later'
    if ($ans -eq '1' -or $ans -eq 'y') { Restart-Computer -Force }
}

# ================================================================= MENU

function Show-Menu {
    while ($true) {
        Write-Banner
        Write-Host (' RAM in use now: {0:N1} GB of {1:N1} GB' -f ((Get-RamInUseMB) / 1024), ((Get-RamTotalMB) / 1024)) -ForegroundColor Gray
        if (Test-Path -LiteralPath $script:BackupFile) {
            Write-Host ' Status: GameBoost is APPLIED' -ForegroundColor Green
        } else {
            Write-Host ' Status: not applied yet - choose [1]' -ForegroundColor Yellow
        }
        Write-Host ''
        Write-Host '   [1]  Apply full boost              (do this once - recommended)'
        Write-Host '   [2]  Pre-game RAM cleanup          (before every game)'
        Write-Host '   [3]  Boost a specific game         (pick the game .exe)'
        Write-Host '   [4]  Show PC status                (RAM / CPU / GPU / top apps)'
        Write-Host '   [5]  Advanced: Memory Integrity OFF (+FPS, less security)'
        Write-Host '   [6]  Undo everything               (back to your original settings)'
        Write-Host '   [0]  Exit'
        Write-Host ''
        $c = Read-Choice ' Choose a number'
        switch ($c) {
            '1' { Invoke-Apply;              Wait-Enter }
            '2' { Invoke-CleanRam;           Wait-Enter }
            '3' { Invoke-BoostGame;          Wait-Enter }
            '4' { Show-Status;               Wait-Enter }
            '5' { Invoke-MemoryIntegrityOff; Wait-Enter }
            '6' { Invoke-Restore;            Wait-Enter }
            '0' { return }
        }
    }
}

# ================================================================= MAIN
try { $Host.UI.RawUI.WindowTitle = 'GameBoost' } catch { }
New-EmptyBackup

switch ($Mode) {
    'Apply'    { Invoke-Apply;    Wait-Enter }
    'CleanRam' { Invoke-CleanRam; Start-Sleep -Seconds 5 }
    'Status'   { Show-Status;     Wait-Enter }
    'Restore'  { Invoke-Restore;  Wait-Enter }
    default    { Show-Menu }
}
