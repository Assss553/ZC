<#
================================================================================
  RoxEngine.ps1  -  the optimization engine behind ROX (dot-source this file)
--------------------------------------------------------------------------------
  * Every value it changes is backed up to C:\ProgramData\ROX\backup.json so
    Invoke-RoxRestore puts everything back exactly as it was.
  * Messages go to $script:RoxSink (a queue the ROX window reads) when it is
    set, otherwise to the console.
  * ASCII only on purpose (Windows PowerShell 5.1 friendly).
================================================================================
#>
Set-StrictMode -Off

# ----------------------------------------------------------------- constants
$script:RoxVersion      = '2.0'
$script:DataDir         = Join-Path $env:ProgramData 'ROX'
$script:AppDir          = Join-Path $script:DataDir 'app'
$script:BackupFile      = Join-Path $script:DataDir 'backup.json'
$script:LogFile         = Join-Path $script:DataDir 'log.txt'
$script:SettingsFile    = Join-Path $script:DataDir 'settings.json'
$script:GamesFile       = Join-Path $script:DataDir 'games.json'
$script:SchemeGuid      = 'd3a1f00d-6a3e-4c5b-9b7e-0b005e0b0057'   # our copy of the power plan
$script:UltimateGuid    = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$script:HighGuid        = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
$script:BalancedGuid    = '381b4222-f694-41f0-9685-ff5bb260df2e'
$script:BestPerfOverlay = 'ded574b5-45a0-4f42-8737-46345c09c238'
$script:RegTypes        = @('DWord', 'QWord', 'String', 'ExpandString', 'MultiString', 'Binary')
$script:OsBuild         = [Environment]::OSVersion.Version.Build
$script:IsWin10         = ($script:OsBuild -lt 22000)
$script:RoxSink         = $null

if (-not (Test-Path -LiteralPath $script:DataDir)) {
    New-Item -ItemType Directory -Path $script:DataDir -Force | Out-Null
}
# GameBoost (the console version) used another folder - keep its backup so Undo still covers it.
$legacyBackup = Join-Path $env:ProgramData 'GameBoost\backup.json'
if ((Test-Path -LiteralPath $legacyBackup) -and -not (Test-Path -LiteralPath $script:BackupFile)) {
    Copy-Item -LiteralPath $legacyBackup -Destination $script:BackupFile -Force -ErrorAction SilentlyContinue
}

# Startup entries that ROX stops from auto-starting (they still open normally by hand).
$script:StartupPattern = '(^MicrosoftEdgeAutoLaunch)|(Teams)|(^Spotify)|(Skype)|(CCleaner)|(Browser ?Assistant)|' +
                         '(uTorrent|BitTorrent)|(^Steam$)|(EpicGamesLauncher)|(^EADM$|EA ?Desktop|^EA ?App$|^Origin$)|' +
                         '(Ubisoft|Uplay)|(Battle\.net)|(^Discord$)|(Overwolf)|' +
                         '(AdobeGCInvoker|Adobe Creative Cloud|CCXProcess|AdobeAAMUpdater)|(iTunesHelper)|(^Cortana)'

# ----------------------------------------------------------------- native helpers (C# 5)
$script:NativeCode = @'
using System;
using System.Runtime.InteropServices;

public static class RoxNative
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

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetSystemCpuSetInformation(IntPtr information, int bufferLength, out int returnedLength,
                                                          IntPtr process, int flags);

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
        if (!OpenProcessToken(GetCurrentProcess(), 0x0028, out token)) return false;
        try
        {
            TokenPrivileges tp = new TokenPrivileges();
            tp.Count = 1;
            tp.Attributes = 2;
            if (!LookupPrivilegeValue(null, name, out tp.Luid)) return false;
            return AdjustTokenPrivileges(token, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
        }
        finally
        {
            CloseHandle(token);
        }
    }

    // Empties the standby list (cached RAM), like RAMMap "Empty Standby List".
    public static int PurgeStandbyList()
    {
        EnablePrivilege("SeProfileSingleProcessPrivilege");
        int command = 4;
        return NtSetSystemInformation(80, ref command, sizeof(int));
    }

    // Logical processors per efficiency class. Hybrid Intel CPUs: highest class = P-cores.
    public static int[] GetEfficiencyClassCounts()
    {
        int length;
        GetSystemCpuSetInformation(IntPtr.Zero, 0, out length, IntPtr.Zero, 0);
        if (length <= 0) return new int[0];
        IntPtr buffer = Marshal.AllocHGlobal(length);
        try
        {
            if (!GetSystemCpuSetInformation(buffer, length, out length, IntPtr.Zero, 0)) return new int[0];
            int[] counts = new int[256];
            int max = -1;
            int offset = 0;
            while (offset + 20 <= length)
            {
                int size = Marshal.ReadInt32(buffer, offset);
                if (size <= 0) break;
                if (Marshal.ReadInt32(buffer, offset + 4) == 0)
                {
                    int cls = Marshal.ReadByte(buffer, offset + 18);
                    counts[cls]++;
                    if (cls > max) max = cls;
                }
                offset += size;
            }
            int[] result = new int[max + 1];
            Array.Copy(counts, result, max + 1);
            return result;
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
    }
}
'@

function Initialize-Native {
    if ('RoxNative' -as [type]) { return $true }
    try {
        Add-Type -TypeDefinition $script:NativeCode -Language CSharp -ErrorAction Stop
        return $true
    } catch {
        Write-Log "Add-Type failed: $($_.Exception.Message)"
        return $false
    }
}

# ----------------------------------------------------------------- output
function Write-Log([string]$Text) {
    try {
        Add-Content -LiteralPath $script:LogFile -Value ('{0}  {1}' -f (Get-Date -Format 's'), $Text) -ErrorAction Stop
    } catch { }
}

function Send-RoxEvent([string]$Kind, [string]$Text) {
    Write-Log ('{0,-5} {1}' -f $Kind.ToUpper(), $Text)
    if ($null -ne $script:RoxSink) {
        $script:RoxSink.Enqueue([pscustomobject]@{ Kind = $Kind; Text = $Text })
        return
    }
    $color = 'Gray'
    switch ($Kind) {
        'step' { $color = 'Cyan' }
        'ok'   { $color = 'Green' }
        'warn' { $color = 'Yellow' }
        'skip' { $color = 'DarkGray' }
    }
    Write-Host $Text -ForegroundColor $color
}
function Write-Step([string]$Text)      { Send-RoxEvent 'step' $Text }
function Write-Ok([string]$Text)        { Send-RoxEvent 'ok'   $Text }
function Write-Info([string]$Text)      { Send-RoxEvent 'info' $Text }
function Write-Skip([string]$Text)      { Send-RoxEvent 'skip' $Text }
function Write-Attention([string]$Text) { Send-RoxEvent 'warn' $Text }

# Runs one step and keeps going if it fails.
function Invoke-Safe([string]$Name, [scriptblock]$Block) {
    try { & $Block } catch {
        Write-Attention "$Name had a problem: $($_.Exception.Message)"
        Write-Log $_.ScriptStackTrace
    }
}

# ----------------------------------------------------------------- settings + games storage
function Get-RoxSettings {
    $d = [ordered]@{
        GpuVendor        = ''
        FirstRunDone     = $false
        AutoBoost        = $true
        CloseOnGameStart = $true
        StartWithWindows = $false
        TrayHintShown    = $false
        KeepApps         = @()
        Favorites        = @('win', 'cleanup', 'network', 'input')
    }
    if (Test-Path -LiteralPath $script:SettingsFile) {
        try {
            $j = Get-Content -LiteralPath $script:SettingsFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            foreach ($k in @($d.Keys)) {
                if ($j.PSObject.Properties.Name -contains $k -and $null -ne $j.$k) { $d[$k] = $j.$k }
            }
        } catch { Write-Log "settings.json unreadable: $($_.Exception.Message)" }
    }
    $d.KeepApps  = @($d.KeepApps  | Where-Object { $_ })
    $d.Favorites = @($d.Favorites | Where-Object { $_ })
    return [pscustomobject]$d
}

function Save-RoxSettings($Settings) {
    try { $Settings | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $script:SettingsFile -Encoding UTF8 -ErrorAction Stop }
    catch { Write-Log "settings.json not saved: $($_.Exception.Message)" }
}

function Get-RoxGames {
    if (-not (Test-Path -LiteralPath $script:GamesFile)) { return @() }
    try {
        # Windows PowerShell 5.1 emits a JSON array as ONE object - unroll it.
        $j = Get-Content -LiteralPath $script:GamesFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        return @($j | ForEach-Object { $_ } | Where-Object { $_ })
    } catch { return @() }
}

function Save-RoxGames($Games) {
    try { ConvertTo-Json -InputObject @($Games) -Depth 4 | Set-Content -LiteralPath $script:GamesFile -Encoding UTF8 -ErrorAction Stop }
    catch { Write-Log "games.json not saved: $($_.Exception.Message)" }
}

# ----------------------------------------------------------------- backup / undo
function New-EmptyBackup {
    $script:Backup = [ordered]@{
        Version      = $script:RoxVersion
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

function Get-RegValue([string]$Path, [string]$Name) {
    try { return (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}

# Puts ONE backed-up value back (used when a single game is un-optimized).
function Restore-RegEntry($Entry) {
    if ($Entry.Existed) {
        if ($script:RegTypes -notcontains [string]$Entry.Type) { return }
        $val = $Entry.Value
        switch ([string]$Entry.Type) {
            'DWord'        { $val = [int]$val }
            'QWord'        { $val = [long]$val }
            'Binary'       { $val = ConvertFrom-Hex ([string]$val) }
            'MultiString'  { $val = [string[]]@($val) }
            'String'       { $val = [string]$val }
            'ExpandString' { $val = [string]$val }
        }
        if (-not (Test-Path -LiteralPath $Entry.Path)) { New-Item -Path $Entry.Path -Force | Out-Null }
        New-ItemProperty -LiteralPath $Entry.Path -Name $Entry.Name -Value $val -PropertyType $Entry.Type -Force -ErrorAction Stop | Out-Null
    } elseif (Test-Path -LiteralPath $Entry.Path) {
        Remove-ItemProperty -LiteralPath $Entry.Path -Name $Entry.Name -Force -ErrorAction SilentlyContinue
    }
}

function Reset-RegValue([string]$Path, [string]$Name) {
    $keep = New-Object System.Collections.ArrayList
    $found = $false
    foreach ($e in $script:Backup.Registry) {
        if ($e.Path -eq $Path -and $e.Name -eq $Name) {
            try { Restore-RegEntry $e } catch { Write-Log "Reset-RegValue: $($_.Exception.Message)" }
            $found = $true
        } else { [void]$keep.Add($e) }
    }
    if (-not $found) { Remove-ItemProperty -LiteralPath $Path -Name $Name -Force -ErrorAction SilentlyContinue }
    $script:Backup.Registry = $keep
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
function Get-RamInfo {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if (-not $os) { return [pscustomobject]@{ TotalMB = 0; UsedMB = 0; Percent = 0 } }
    $totalMB = $os.TotalVisibleMemorySize / 1KB
    $availMB = $null
    try { $availMB = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory -ErrorAction Stop).AvailableMBytes } catch { }
    if (-not $availMB) { $availMB = $os.FreePhysicalMemory / 1KB }
    $used = [math]::Max(0, $totalMB - $availMB)
    return [pscustomobject]@{
        TotalMB = [math]::Round($totalMB)
        UsedMB  = [math]::Round($used)
        Percent = [math]::Round(100 * $used / [math]::Max(1, $totalMB))
    }
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

function Get-FolderSizeMB([string]$Path) {
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return 0 }
    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if (-not $sum) { return 0 }
    return [math]::Round($sum / 1MB)
}

# ----------------------------------------------------------------- winget
function Test-Winget { return [bool](Get-Command 'winget.exe' -ErrorAction SilentlyContinue) }

function Invoke-WingetStream([string[]]$Arguments) {
    & winget.exe @Arguments 2>&1 | ForEach-Object {
        $line = (([string]$_) -split "`r")[-1].Trim()
        if ($line.Length -gt 3 -and $line -notmatch '^[\-\\|/ ]+$' -and $line -notmatch '[\u2580-\u259F]') { Write-Info $line }
    }
    return $LASTEXITCODE
}

function Install-WithWinget([string[]]$Ids, [string]$ExactName) {
    if (-not (Test-Winget)) { Write-Skip 'winget is not available on this PC'; return $false }
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
        Write-Info "Installing $id (official winget package)..."
        $code = Invoke-WingetStream @('install', '--id', $id, '--exact', '--silent', '--source', 'winget',
                                      '--accept-package-agreements', '--accept-source-agreements')
        if ($code -eq 0) { return $true }
        $null = & winget.exe list --id $id --exact --accept-source-agreements 2>&1
        if ($LASTEXITCODE -eq 0) { Write-Info "$id is already installed"; return $true }
    }
    return $false
}

# ================================================================= OPTIMIZATION MODULES

function New-SafetyRestorePoint {
    Write-Step 'Safety first: creating a System Restore point'
    try {
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' 0
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'ROX - before tweaks' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Ok 'Restore point created'
    } catch {
        Write-Attention "No restore point ($($_.Exception.Message)). ROX still keeps its own backup for Undo."
    }
}

function Set-CpuPowerPlan {
    Write-Step 'Power: maximum-performance plan (Windows drives the CPU automatically)'
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
        $null = powercfg /changename $script:SchemeGuid 'ROX' 'Maximum performance for gaming (ROX)' 2>&1
        # Plugged in: full speed + turbo, no core parking, no PCIe/USB power saving.
        # The "...1" settings are for the P-cores of hybrid Intel CPUs (ignored elsewhere).
        $ac = @(
            @('SUB_PROCESSOR', 'PROCTHROTTLEMIN', 100),
            @('SUB_PROCESSOR', 'PROCTHROTTLEMAX', 100),
            @('SUB_PROCESSOR', 'CPMINCORES', 100),
            @('SUB_PROCESSOR', 'PROCTHROTTLEMIN1', 100),
            @('SUB_PROCESSOR', 'PROCTHROTTLEMAX1', 100),
            @('SUB_PROCESSOR', 'CPMINCORES1', 100),
            @('SUB_PROCESSOR', 'PERFBOOSTMODE', 2),
            @('SUB_PROCESSOR', 'PERFEPP', 0),
            @('SUB_PROCESSOR', 'PERFEPP1', 0),
            @('SUB_PCIEXPRESS', 'ASPM', 0),
            @('2a737441-1930-4402-8d77-b2bebba308a3', '48e6b7a6-50f5-4782-a5d4-53bb8f07e226', 0),
            @('SUB_DISK', 'DISKIDLE', 0)
        )
        foreach ($s in $ac) { $null = powercfg /setacvalueindex $script:SchemeGuid $s[0] $s[1] $s[2] 2>&1 }
        $null = powercfg /setdcvalueindex $script:SchemeGuid SUB_PROCESSOR PROCTHROTTLEMIN 5 2>&1
        $null = powercfg /setactive $script:SchemeGuid 2>&1
    }
    if ((Get-ActiveSchemeGuid) -eq $script:SchemeGuid) {
        Write-Ok 'ROX power plan active: CPU at full speed + Turbo while plugged in'
        return
    }
    if (Initialize-Native) {
        try {
            $cur = [guid]::Empty
            [void][RoxNative]::PowerGetEffectiveOverlayScheme([ref]$cur)
            if (-not $script:Backup.PowerOverlay) { $script:Backup.PowerOverlay = $cur.ToString() }
            if ([RoxNative]::PowerSetActiveOverlayScheme([guid]$script:BestPerfOverlay) -eq 0) {
                Write-Ok 'Power mode set to "Best performance"'
                return
            }
        } catch { Write-Log "Overlay: $($_.Exception.Message)" }
    }
    Write-Attention 'Could not change the power plan on this PC (kept Windows default)'
}

function Set-GameSettings {
    Write-Step 'Games: Game Mode ON, background recording OFF, games get top priority'
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'HistoricalCaptureEnabled' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
    $mm = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    Set-Reg $mm 'SystemResponsiveness' 10
    $games = "$mm\Tasks\Games"
    Set-Reg $games 'GPU Priority' 8
    Set-Reg $games 'Priority' 6
    Set-Reg $games 'Scheduling Category' 'High' 'String'
    Set-Reg $games 'SFIO Priority' 'High' 'String'
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 38
    Write-Ok 'Game Mode ON, recording OFF, the game window gets more CPU time'
}

function Set-GpuSettings {
    Write-Step 'GPU: hardware-accelerated scheduling + optimizations for windowed games'
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2
    $dx  = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    $cur = [string](Get-RegValue $dx 'DirectXUserGlobalSettings')
    $pairs = [ordered]@{}
    foreach ($part in ($cur -split ';')) {
        if ($part -match '^\s*([^=]+?)\s*=\s*(.*?)\s*$') { $pairs[$Matches[1]] = $Matches[2] }
    }
    $pairs['SwapEffectUpgradeEnable'] = '1'
    $newValue = (($pairs.GetEnumerator() | ForEach-Object { '{0}={1}' -f $_.Key, $_.Value }) -join ';') + ';'
    Set-Reg $dx 'DirectXUserGlobalSettings' $newValue 'String'
    Write-Ok 'GPU scheduling ON (GTX 10xx / RX 5000 / Intel Arc and newer, after restart)'
}

function Disable-ExtraServices {
    Write-Step 'Services: turn off what a gaming PC does not need'
    $disable = [ordered]@{
        'DiagTrack'        = 'Telemetry'
        'dmwappushservice' = 'Telemetry push messages'
        'MapsBroker'       = 'Offline maps'
        'RetailDemo'       = 'Shop demo mode'
        'Fax'              = 'Fax'
        'wisvc'            = 'Windows Insider'
        'WpcMonSvc'        = 'Parental controls monitor'
        'WMPNetworkSvc'    = 'Media Player sharing'
        'WSearch'          = 'Search indexer (RAM + disk)'
    }
    if (Test-SystemDriveIsSsd) { $disable['SysMain'] = 'SysMain / Superfetch' }
    else { Write-Skip 'SysMain kept ON (Windows is on a hard disk)' }
    $manual = [ordered]@{
        'PcaSvc'      = 'Program Compatibility Assistant'
        'TrkWks'      = 'Distributed Link Tracking'
        'edgeupdate'  = 'Edge updater'
        'edgeupdatem' = 'Edge updater'
    }
    $printers = @(Get-CimInstance Win32_Printer -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name -notmatch 'PDF|XPS|OneNote|Fax|Send To' })
    if ($printers.Count -eq 0) { $manual['Spooler'] = 'Print spooler (no printer)' }
    foreach ($k in @($disable.Keys)) { if (Set-ServiceStartup $k 'Disabled') { Write-Ok ('Off    : ' + $disable[$k]) } }
    foreach ($k in @($manual.Keys))  { if (Set-ServiceStartup $k 'Manual')   { Write-Ok ('Manual : ' + $manual[$k]) } }
}

function Disable-TelemetryTasks {
    Write-Step 'Scheduled tasks: stop background telemetry jobs (fewer CPU spikes in game)'
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
        @('\Microsoft\Windows\Maps\', 'MapsUpdateTask'),
        @('\Microsoft\Windows\Maps\', 'MapsToastTask')
    )
    $n = 0
    foreach ($t in $tasks) { if (Disable-TaskSafe $t[0] $t[1]) { $n++ } }
    if ($n -gt 0) { Write-Ok "$n background tasks disabled" } else { Write-Skip 'Nothing to change' }
}

function Disable-BackgroundBloat {
    Write-Step 'RAM savers: Widgets / News, Edge in background, silent app installs, telemetry'
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
    Write-Ok 'Widgets OFF, Edge stops after you close it, no silent app installs'
}

function Set-VisualEffects {
    Write-Step 'Windows look: performance mode (fonts stay smooth)'
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 3
    Set-Reg 'HKCU:\Control Panel\Desktop' 'UserPreferencesMask' ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) 'Binary'
    Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAnimations' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' 0
    Write-Ok 'Animations and transparency OFF'
}

function Set-InputTweaks {
    Write-Step 'Keyboard + mouse: raw 1:1 aim, fastest key repeat, no Sticky Keys pop-ups'
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Keyboard' 'KeyboardDelay' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Keyboard' 'KeyboardSpeed' '31' 'String'
    Set-Reg 'HKCU:\Control Panel\Accessibility\StickyKeys' 'Flags' '506' 'String'
    Set-Reg 'HKCU:\Control Panel\Accessibility\ToggleKeys' 'Flags' '58' 'String'
    Set-Reg 'HKCU:\Control Panel\Accessibility\Keyboard Response' 'Flags' '122' 'String'
    Write-Ok 'Mouse acceleration OFF, fastest key repeat, Shift x5 pop-up OFF (after sign-out)'
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
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' (-1)
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0
    $null = & ipconfig.exe /flushdns 2>&1
    Write-Ok "Nagle delay OFF on $n adapter(s), no network throttling, update upload OFF, DNS cache cleared"
}

function Disable-StartupApps {
    Write-Step 'Startup: heavy apps stop auto-starting (they still open when YOU open them)'
    $approvedRoot  = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    $disabledBytes = [byte[]](@(3, 0, 0, 0) + [BitConverter]::GetBytes([DateTime]::Now.ToFileTime()))
    $names = New-Object System.Collections.Generic.List[string]
    foreach ($src in (Get-StartupSources)) {
        if ($src.Kind -eq 'run') {
            if (-not (Test-Path -LiteralPath $src.Run)) { continue }
            $key = Get-Item -LiteralPath $src.Run -ErrorAction SilentlyContinue
            if (-not $key) { continue }
            foreach ($n in $key.GetValueNames()) {
                if ($n -and $n -match $script:StartupPattern) { Set-Reg $src.Approved $n $disabledBytes 'Binary'; $names.Add($n) }
            }
        } else {
            if (-not $src.Dir -or -not (Test-Path -LiteralPath $src.Dir)) { continue }
            foreach ($file in @(Get-ChildItem -LiteralPath $src.Dir -File -ErrorAction SilentlyContinue)) {
                if ($file.BaseName -match $script:StartupPattern) { Set-Reg $src.Approved $file.Name $disabledBytes 'Binary'; $names.Add($file.BaseName) }
            }
        }
    }
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
    if ($names.Count -gt 0) { Write-Ok ('No auto-start any more: ' + ((@($names) | Select-Object -Unique) -join ', ')) }
    else { Write-Skip 'No heavy startup apps found' }
}

function Get-StartupSources {
    $approvedRoot = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
    return @(
        [pscustomobject]@{ Kind = 'run';    Run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';             Approved = "HKCU:\$approvedRoot\Run";   Dir = $null },
        [pscustomobject]@{ Kind = 'run';    Run = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';             Approved = "HKLM:\$approvedRoot\Run";   Dir = $null },
        [pscustomobject]@{ Kind = 'run';    Run = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = "HKLM:\$approvedRoot\Run32"; Dir = $null },
        [pscustomobject]@{ Kind = 'folder'; Run = $null; Approved = "HKCU:\$approvedRoot\StartupFolder"; Dir = [Environment]::GetFolderPath('Startup') },
        [pscustomobject]@{ Kind = 'folder'; Run = $null; Approved = "HKLM:\$approvedRoot\StartupFolder"; Dir = [Environment]::GetFolderPath('CommonStartup') }
    )
}

# Heavy startup apps that are still allowed to auto-start.
function Get-HeavyStartupCount {
    $n = 0
    foreach ($src in (Get-StartupSources)) {
        $names = @()
        if ($src.Kind -eq 'run') {
            $key = Get-Item -LiteralPath $src.Run -ErrorAction SilentlyContinue
            if ($key) { $names = @($key.GetValueNames()) }
        } elseif ($src.Dir -and (Test-Path -LiteralPath $src.Dir)) {
            $names = @(Get-ChildItem -LiteralPath $src.Dir -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
        }
        foreach ($name in $names) {
            $base = $name
            if ($src.Kind -eq 'folder') { $base = [IO.Path]::GetFileNameWithoutExtension($name) }
            if (-not $base -or $base -notmatch $script:StartupPattern) { continue }
            $b = Get-RegValue $src.Approved $name
            if (-not ($b -is [byte[]]) -or $b.Length -eq 0 -or ($b[0] % 2) -eq 0) { $n++ }
        }
    }
    return $n
}

function Optimize-Processes {
    Write-Step 'Fewer background processes'
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    if ($cs) {
        $kb = [int64]($cs.TotalPhysicalMemory / 1KB) + 1048576
        if ($kb -gt 0 -and $kb -lt [int]::MaxValue) {
            Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB' ([int]$kb)
            Write-Ok 'Windows services grouped into fewer svchost processes (after restart)'
        }
    }
}

function Remove-FolderContents([string]$Dir) {
    $freed = [int64]0
    if (-not $Dir -or -not (Test-Path -LiteralPath $Dir)) { return $freed }
    foreach ($item in @(Get-ChildItem -LiteralPath $Dir -Force -ErrorAction SilentlyContinue)) {
        try {
            $size = 0
            if ($item.PSIsContainer) {
                $size = (Get-ChildItem -LiteralPath $item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue |
                         Measure-Object -Property Length -Sum).Sum
            } else { $size = $item.Length }
            Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
            if ($size) { $freed += [int64]$size }
        } catch { }
    }
    return $freed
}

function Invoke-Cleanup {
    Write-Step 'Cleanup: temp files, Windows Update download cache, delivery cache'
    $freed = [int64]0
    $freed += Remove-FolderContents $env:TEMP
    $freed += Remove-FolderContents (Join-Path $env:SystemRoot 'Temp')
    try {
        Stop-Service -Name 'wuauserv', 'bits' -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        $freed += Remove-FolderContents (Join-Path $env:SystemRoot 'SoftwareDistribution\Download')
    } finally {
        Start-Service -Name 'bits', 'wuauserv' -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }
    try { Delete-DeliveryOptimizationCache -Force -ErrorAction Stop | Out-Null } catch { }
    $mb = [math]::Round($freed / 1MB)
    Write-Ok ('Cleaned {0:N0} MB of junk files' -f $mb)
    return $mb
}

function Set-GpuDriverUpdates {
    Write-Step 'GPU driver: keep it updated automatically'
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' 'SearchOrderConfig' 1
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata' 'PreventDeviceMetadataFromNetwork' 0
    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    if ((Get-RegValue $wu 'ExcludeWUDriversInQualityUpdate') -eq 1) { Set-Reg $wu 'ExcludeWUDriversInQualityUpdate' 0 }
    Write-Ok 'Windows Update may install new drivers automatically'

    $settings = Get-RoxSettings
    $gpus   = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    $nvidia = @($gpus | Where-Object { $_.PNPDeviceID -match 'VEN_10DE' })
    $amd    = @($gpus | Where-Object { $_.PNPDeviceID -match 'VEN_1002' })
    $intel  = @($gpus | Where-Object { $_.PNPDeviceID -match 'VEN_8086' })
    foreach ($g in $gpus) { Write-Info ('Found GPU: {0}  (driver {1})' -f $g.Name, $g.DriverVersion) }

    if ($nvidia.Count -gt 0 -or $settings.GpuVendor -eq 'nvidia') {
        if (Test-AppInstalled '^NVIDIA app|GeForce Experience') {
            Write-Ok 'NVIDIA app is installed - it downloads new drivers for you'
        } elseif (Install-WithWinget -Ids @('Nvidia.NVIDIAApp') -ExactName 'NVIDIA app') {
            Write-Ok 'NVIDIA app installed - it downloads new drivers for you'
        } else {
            Write-Attention 'Could not install NVIDIA app automatically - opening the official page'
            Start-Process 'https://www.nvidia.com/en-us/software/nvidia-app/'
        }
    }
    if ($amd.Count -gt 0 -or $settings.GpuVendor -eq 'amd') {
        if (Test-AppInstalled '^AMD Software') {
            Write-Ok 'AMD Software (Adrenalin) is installed - it checks for new drivers itself'
        } else {
            Write-Attention 'AMD Software not found - opening the AMD auto-detect page'
            Start-Process 'https://www.amd.com/en/support/download/drivers.html'
        }
    }
    $cpuIsIntel = [string](Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).Manufacturer -match 'Intel'
    if ($intel.Count -gt 0 -or $cpuIsIntel -or $settings.GpuVendor -eq 'intel') { Install-IntelDsa }

    try {
        Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\UsoClient.exe') -ArgumentList 'StartScan' -WindowStyle Hidden -ErrorAction Stop
        Write-Ok 'Windows Update asked to look for new drivers now'
    } catch { }
}

# ================================================================= INTEL (CPU + GPU)

function Get-CpuDetails {
    $cpu   = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $name  = ''
    $maker = ''
    if ($cpu) { $name = ([string]$cpu.Name).Trim(); $maker = [string]$cpu.Manufacturer }
    $gen = 0
    $m = [regex]::Match($name, 'i[3579]-(\d{4,5})')
    if ($m.Success) {
        $num = $m.Groups[1].Value
        if ($num.Length -eq 5 -or $num.StartsWith('1')) { $gen = [int]$num.Substring(0, 2) } else { $gen = [int]$num.Substring(0, 1) }
    } elseif ($name -match 'Ultra') { $gen = 15 }
    $classes = @()
    if (Initialize-Native) { try { $classes = @([RoxNative]::GetEfficiencyClassCounts()) } catch { } }
    $p = 0
    $e = 0
    if ($classes.Count -gt 1) {
        $p = [int]$classes[$classes.Count - 1]
        for ($i = 0; $i -lt $classes.Count - 1; $i++) { $e += [int]$classes[$i] }
    }
    return [pscustomobject]@{
        Name     = $name
        IsIntel  = ($maker -match 'Intel' -or $name -match 'Intel')
        Gen      = $gen
        Hybrid   = ($p -gt 0 -and $e -gt 0)
        PThreads = $p
        EThreads = $e
    }
}

function Get-MicrocodeRevision {
    try {
        $v = (Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -Name 'Update Revision' -ErrorAction Stop).'Update Revision'
        if ($v -is [byte[]] -and $v.Length -ge 8) { return [BitConverter]::ToUInt32($v, 4) }
    } catch { }
    return 0
}

function Get-LargestBarMB([string]$PnpId) {
    try {
        $ranges = @{}
        foreach ($r in @(Get-WmiObject Win32_DeviceMemoryAddress -ErrorAction Stop)) { $ranges[[string]$r.StartingAddress] = $r }
        $max = 0
        foreach ($a in @(Get-WmiObject Win32_PnPAllocatedResource -ErrorAction Stop)) {
            $m = [regex]::Match([string]$a.Antecedent, 'Win32_DeviceMemoryAddress\.StartingAddress="(\d+)"')
            if (-not $m.Success) { continue }
            $dep = ([string]$a.Dependent).Replace('\\', '\')
            if ($dep.IndexOf($PnpId, [StringComparison]::OrdinalIgnoreCase) -lt 0) { continue }
            $range = $ranges[$m.Groups[1].Value]
            if ($range) {
                $size = ([double]$range.EndingAddress - [double]$range.StartingAddress + 1) / 1MB
                if ($size -gt $max) { $max = $size }
            }
        }
        return [math]::Round($max)
    } catch { return -1 }
}

function Show-RamCheck([switch]$IntegratedOnly) {
    $dimms = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
    if ($dimms.Count -eq 0) { return }
    $type     = [int]$dimms[0].SMBIOSMemoryType
    $speed    = [int]$dimms[0].ConfiguredClockSpeed
    $typeName = 'RAM'
    switch ($type) {
        24 { $typeName = 'DDR3' }
        26 { $typeName = 'DDR4' }
        29 { $typeName = 'LPDDR3' }
        30 { $typeName = 'LPDDR4' }
        34 { $typeName = 'DDR5' }
        35 { $typeName = 'LPDDR5' }
    }
    $totalGB = (($dimms | Measure-Object -Property Capacity -Sum).Sum) / 1GB
    Write-Info ('RAM: {0} stick(s), {1}, {2} MT/s, {3:N0} GB' -f $dimms.Count, $typeName, $speed, $totalGB)
    $soldered = @(27, 28, 29, 30, 35) -contains $type
    if ($IntegratedOnly -and $dimms.Count -eq 1 -and -not $soldered) {
        Write-Attention 'Only ONE RAM stick = single channel. Integrated graphics get up to ~2x FPS with TWO matching sticks (dual channel).'
    }
    if (($type -eq 26 -and $speed -gt 0 -and $speed -le 2666) -or ($type -eq 34 -and $speed -gt 0 -and $speed -le 4800)) {
        Write-Info 'If your RAM is rated faster (see the sticker), turn on XMP in BIOS - free FPS.'
    }
}

function Install-IntelDsa {
    $what = 'keeps Intel graphics, Wi-Fi, Bluetooth and chipset drivers updated'
    if (Test-AppInstalled 'Intel.*Driver.*Support Assistant') {
        Write-Ok "Intel Driver & Support Assistant is installed - $what"
    } elseif (Install-WithWinget -Ids @('Intel.IntelDriverAndSupportAssistant') -ExactName '') {
        Write-Ok "Intel Driver & Support Assistant installed - $what"
    } else {
        Write-Attention 'Could not install Intel Driver & Support Assistant automatically - opening the official page'
        Start-Process 'https://www.intel.com/content/www/us/en/support/detect.html'
    }
}

function Invoke-IntelTune {
    $cpu       = Get-CpuDetails
    $gpus      = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    $intelGpus = @($gpus | Where-Object { $_.PNPDeviceID -match 'VEN_8086' })
    if (-not $cpu.IsIntel -and $intelGpus.Count -eq 0) { return }
    $isArcCard = { param($g) [string]$g.Name -match 'Arc.*\b[AB]\d{3}' }
    $dedicated = @($gpus | Where-Object { $_.PNPDeviceID -match 'VEN_10DE|VEN_1002' -or (& $isArcCard $_) })

    Write-Step 'Intel: CPU + GPU tuning and checks'
    if ($cpu.IsIntel) {
        $genText = ''
        if ($cpu.Gen -ge 15) { $genText = '  (Core Ultra)' } elseif ($cpu.Gen -gt 0) { $genText = "  (gen $($cpu.Gen))" }
        Write-Info ('CPU: {0}{1}' -f $cpu.Name, $genText)
        if ($cpu.Hybrid) {
            Write-Ok ('Hybrid CPU: {0} P-core threads (fast) + {1} E-core threads (efficient)' -f $cpu.PThreads, $cpu.EThreads)
            if ((Test-SchemeExists $script:SchemeGuid) -and $script:IsWin10) {
                $null = powercfg /setacvalueindex $script:SchemeGuid SUB_PROCESSOR SCHEDPOLICY 2 2>&1
                $null = powercfg /setacvalueindex $script:SchemeGuid SUB_PROCESSOR SHORTSCHEDPOLICY 2 2>&1
                $null = powercfg /setactive $script:SchemeGuid 2>&1
                Write-Ok 'Windows 10 fix: games now prefer the fast P-cores'
            }
            if ($script:IsWin10) {
                Write-Attention 'Windows 10 does not fully understand P-cores / E-cores. Windows 11 is the biggest win for this CPU.'
            } else {
                Write-Ok 'Windows 11 Thread Director puts the game on the P-cores automatically'
            }
        }
        $mm = [regex]::Match($cpu.Name, 'i[579]-1[34]\d{3}([A-Z]*)')
        if ($mm.Success -and $mm.Groups[1].Value -notmatch '[HUP]') {
            $rev = Get-MicrocodeRevision
            if ($rev -ge 0x12B) {
                Write-Ok ('Microcode 0x{0:X}: has Intel''s 13th/14th gen stability fix' -f $rev)
            } elseif ($rev -gt 0) {
                Write-Attention ('Microcode 0x{0:X} is OLD - 13th/14th gen desktop CPUs need 0x12B+ to stop crashes and damage. Update the motherboard BIOS.' -f $rev)
            } else {
                Write-Info 'Important for 13th/14th gen: keep the motherboard BIOS updated (Intel microcode 0x12B fix).'
            }
        }
        $hvci = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled'
        if ($cpu.Gen -gt 0 -and $cpu.Gen -le 6 -and $hvci -eq 1) {
            Write-Attention ('Gen {0} Intel CPUs lack MBEC: Memory Integrity costs MORE FPS here (Settings > Memory Integrity).' -f $cpu.Gen)
        }
    }
    foreach ($g in $intelGpus) {
        if (& $isArcCard $g) {
            Write-Info ('GPU: {0}  (Intel Arc card, driver {1})' -f $g.Name, $g.DriverVersion)
            $bar = Get-LargestBarMB ([string]$g.PNPDeviceID)
            if ($bar -ge 1024) {
                Write-Ok ('Resizable BAR is ON ({0:N0} MB) - Arc runs at full speed' -f $bar)
            } else {
                Write-Attention 'Resizable BAR could not be confirmed ON - Intel Arc loses a LOT of FPS without it (BIOS: Above 4G Decoding + Re-Size BAR).'
            }
        } else {
            Write-Info ('GPU: {0}  (Intel integrated graphics, driver {1})' -f $g.Name, $g.DriverVersion)
        }
    }
    Show-RamCheck -IntegratedOnly:($dedicated.Count -eq 0 -and $intelGpus.Count -gt 0)
}

# ================================================================= MODULES (what the ROX cards run)

function Invoke-RoxModule([string]$Id) {
    Import-Backup
    switch ($Id) {
        'win'     { Invoke-Safe 'Services' { Disable-ExtraServices }; Invoke-Safe 'Tasks' { Disable-TelemetryTasks }; Invoke-Safe 'Visuals' { Set-VisualEffects } }
        'gaming'  { Invoke-Safe 'Games' { Set-GameSettings } }
        'gpu'     { Invoke-Safe 'GPU' { Set-GpuSettings }; Invoke-Safe 'Drivers' { Set-GpuDriverUpdates } }
        'power'   { Invoke-Safe 'Power' { Set-CpuPowerPlan }; Invoke-Safe 'Intel' { Invoke-IntelTune } }
        'cleanup' { Invoke-Safe 'Cleanup' { $null = Invoke-Cleanup } }
        'network' { Invoke-Safe 'Network' { Set-NetworkLatency } }
        'input'   { Invoke-Safe 'Input' { Set-InputTweaks } }
        'startup' { Invoke-Safe 'Startup' { Disable-StartupApps } }
        'ram'     { Invoke-Safe 'Processes' { Optimize-Processes }; Invoke-Safe 'Bloat' { Disable-BackgroundBloat } }
        default   { Write-Attention "Unknown module: $Id" }
    }
    Export-Backup
}

function Invoke-OptimizeAll {
    Import-Backup
    Invoke-Safe 'Restore point' { New-SafetyRestorePoint }
    Export-Backup
    foreach ($id in 'power', 'gaming', 'gpu', 'win', 'ram', 'startup', 'network', 'input', 'cleanup') {
        Invoke-RoxModule -Id $id
    }
    Write-Ok 'All optimizations applied - restart the PC to finish'
}

# ================================================================= BACKGROUND APPS

$script:EssentialNames = @(
    'idle', 'system', 'registry', 'smss', 'csrss', 'wininit', 'winlogon', 'services', 'lsass', 'lsaiso', 'svchost',
    'dwm', 'explorer', 'fontdrvhost', 'sihost', 'taskhostw', 'ctfmon', 'conhost', 'dllhost', 'runtimebroker',
    'searchhost', 'searchapp', 'searchui', 'searchindexer', 'searchprotocolhost', 'searchfilterhost',
    'startmenuexperiencehost', 'shellexperiencehost', 'textinputhost', 'applicationframehost', 'systemsettingsbroker',
    'securityhealthsystray', 'securityhealthservice', 'securityhealthhost', 'msmpeng', 'nissrv', 'smartscreen',
    'audiodg', 'spoolsv', 'wudfhost', 'lockapp', 'useroobebroker', 'memory compression', 'memcompression',
    'wmiprvse', 'unsecapp', 'dashost', 'sgrmbroker', 'presentationfontcache', 'wlanext', 'sihclient',
    'powershell', 'pwsh', 'powershell_ise', 'windowsterminal', 'openconsole', 'cmd', 'taskmgr', 'procexp', 'procexp64',
    'mmc', 'regedit', 'rox',
    'vgtray', 'vgc', 'easyanticheat', 'easyanticheat_eos', 'beservice', 'bedaisy', 'faceit', 'faceitclient',
    'faceitservice', 'eaanticheat.gameservice', 'eaanticheat', 'mbamtray', 'mbam', 'avastui', 'avgui', 'avp', 'avpui',
    'egui', 'ekrn', 'bdagent', 'mcuicnt', 'nortonsecurity', '360tray',
    'rtkauduservice64', 'rtkaudioservice64', 'rtkngui64', 'ravbg64', 'nahimicsvc64', 'nahimicsvc32', 'nahimic3',
    'dtsapo4service', 'dolbydax2api',
    'nvcontainer', 'nvdisplay.container', 'nvidia share', 'nvidia overlay', 'nvsphelper64', 'nvidia app',
    'nvidia web helper', 'radeonsoftware', 'amdrsserv', 'amdrssrcext', 'atieclxx', 'amdow', 'cncmd',
    'igfxem', 'igfxhk', 'igfxtray', 'intelgraphicssoftware', 'igcc', 'igcctray',
    'lghub', 'lghub_agent', 'lghub_system_tray', 'lghub_updater', 'razer synapse 3', 'razercentralservice',
    'razer synapse service', 'steelseriesgg', 'steelseriesengine', 'icue', 'corsair.service',
    'armourycrate.service', 'armourycrateservice', 'asusoptimization', 'msi.centralserver', 'msicenter'
)
# Windows helpers that live in C:\Windows but are fine to close before playing.
$script:ClosableWindowsNames = @('widgets', 'widgetservice', 'phoneexperiencehost', 'yourphone', 'cortana',
                                 'gamebar', 'gamebarftserver', 'xboxgamebarwidgets', 'onedrive', 'systemsettings')
$script:LauncherNames = @('steam', 'steamwebhelper', 'steamservice', 'epicgameslauncher', 'epicwebhelper',
                          'eadesktop', 'eabackgroundservice', 'battle.net', 'agent', 'riotclientservices',
                          'riotclientux', 'riotclientuxrender', 'upc', 'ubisoftconnect', 'uplaywebcore',
                          'galaxyclient', 'galaxyclient helper', 'rockstarlauncher', 'socialclubhelper',
                          'xboxpcapp', 'gamingservices', 'leagueclient', 'leagueclientux', 'leagueclientuxrender')
$script:ChatNames = @('discord', 'teamspeak', 'ts3client_win64', 'whatsapp', 'telegram', 'slack', 'zoom',
                      'ms-teams', 'msteams', 'teams', 'signal', 'viber', 'messenger', 'skype')
# Browsers (open tabs) and streaming / FPS-overlay tools are never closed automatically.
$script:BrowserNames = @('chrome', 'msedge', 'firefox', 'opera', 'brave', 'vivaldi', 'iexplore', 'arc', 'yandex')
$script:ToolNames = @('obs64', 'obs32', 'obs', 'streamlabs obs', 'streamlabs', 'twitchstudio', 'xsplit.core',
                      'msiafterburner', 'rtss', 'rtsshooksloader64', 'hwinfo64', 'capframex', 'presentmon')

function Get-BackgroundApps {
    $session  = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    $settings = Get-RoxSettings
    $keep     = @($settings.KeepApps | ForEach-Object { ([string]$_).ToLower() })
    $paths    = @{}
    foreach ($w in @(Get-CimInstance Win32_Process -Property ProcessId, ExecutablePath -ErrorAction SilentlyContinue)) {
        if ($w.ExecutablePath) { $paths[[int]$w.ProcessId] = $w.ExecutablePath }
    }
    $groups = @{}
    foreach ($p in [System.Diagnostics.Process]::GetProcesses()) {
        try {
            if ($p.SessionId -ne $session -or $p.Id -eq $PID -or $p.Id -le 4) { continue }
            $name = $p.ProcessName.ToLower()
            if ($script:EssentialNames -contains $name) { continue }
            $path = $paths[$p.Id]
            if (-not $path) { continue }
            if ($path.StartsWith($env:windir, [StringComparison]::OrdinalIgnoreCase) -and $script:ClosableWindowsNames -notcontains $name) { continue }
            if (-not $groups.ContainsKey($name)) {
                $info = $null
                try { $info = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($path) } catch { }
                $company = ''
                $desc = ''
                if ($info) { $company = [string]$info.CompanyName; $desc = [string]$info.FileDescription }
                if ($company -match 'NVIDIA|Advanced Micro Devices|^AMD|Intel|Realtek|Microsoft Windows') { continue }
                $cat = 'app'
                if ($script:LauncherNames -contains $name) { $cat = 'launcher' }
                elseif ($script:ChatNames -contains $name) { $cat = 'chat' }
                elseif ($script:BrowserNames -contains $name) { $cat = 'browser' }
                elseif ($script:ToolNames -contains $name) { $cat = 'tool' }
                $display = $desc.Trim()
                if (-not $display -or $display.Length -gt 40) { $display = $p.ProcessName }
                $groups[$name] = [pscustomobject]@{
                    ProcessName = $p.ProcessName
                    Name        = $display
                    Company     = $company.Trim()
                    Path        = $path
                    Category    = $cat
                    RamMB       = 0.0
                    Count       = 0
                    HasWindow   = $false
                    Keep        = ($keep -contains $name)
                    DefaultClose = $false
                }
            }
            $g = $groups[$name]
            $g.RamMB += $p.WorkingSet64 / 1MB
            $g.Count++
            if ($p.MainWindowHandle -ne [IntPtr]::Zero) { $g.HasWindow = $true }
        } catch { }
    }
    $list = @($groups.Values)
    foreach ($g in $list) {
        $g.RamMB = [math]::Round($g.RamMB)
        $g.DefaultClose = (-not $g.Keep) -and ($g.Category -eq 'app')
    }
    return @($list | Sort-Object -Property RamMB -Descending)
}

# Closes apps by process name. Windows with possible unsaved work are asked nicely and never forced.
function Stop-BackgroundApps([string[]]$Names) {
    $before = 0.0
    $closed = 0
    $stillOpen = New-Object System.Collections.Generic.List[string]
    foreach ($n in @($Names | Where-Object { $_ })) {
        $procs = @(Get-Process -Name $n -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID })
        if ($procs.Count -eq 0) { continue }
        foreach ($p in $procs) { $before += $p.WorkingSet64 / 1MB }
        $windowed = @($procs | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })
        foreach ($w in $windowed) { try { [void]$w.CloseMainWindow() } catch { } }
        if ($windowed.Count -gt 0) {
            $deadline = (Get-Date).AddSeconds(4)
            while ((Get-Date) -lt $deadline -and @($windowed | Where-Object { -not $_.HasExited }).Count -gt 0) { Start-Sleep -Milliseconds 250 }
        }
        if (@($windowed | Where-Object { -not $_.HasExited }).Count -gt 0) {
            $stillOpen.Add($n)
            continue
        }
        foreach ($p in @(Get-Process -Name $n -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $PID })) {
            try { $p.Kill() } catch { }
        }
        $closed++
    }
    Start-Sleep -Milliseconds 600
    $after = 0.0
    foreach ($n in @($Names | Where-Object { $_ })) {
        foreach ($p in @(Get-Process -Name $n -ErrorAction SilentlyContinue)) { $after += $p.WorkingSet64 / 1MB }
    }
    if ($closed -gt 0) { Write-Ok ('Closed {0} app(s)' -f $closed) }
    if ($stillOpen.Count -gt 0) { Write-Attention ('Still open (maybe unsaved work): ' + ($stillOpen -join ', ')) }
    return [pscustomobject]@{ Closed = $closed; FreedMB = [math]::Round([math]::Max(0, $before - $after)); StillOpen = @($stillOpen) }
}

function Invoke-CleanRam([int]$SkipPid = 0) {
    Write-Step 'Freeing RAM'
    $before = (Get-RamInfo).UsedMB
    $helpers = @('Widgets', 'WidgetService', 'PhoneExperienceHost', 'YourPhone', 'Cortana', 'SkypeApp', 'SkypeBackgroundHost')
    Get-Process -Name $helpers -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    if (Initialize-Native) {
        $skip = @('system', 'idle', 'registry', 'memory compression', 'memcompression', 'smss', 'csrss', 'wininit',
                  'winlogon', 'services', 'lsass', 'dwm', 'audiodg', 'explorer', 'fontdrvhost', 'msmpeng', 'nissrv',
                  'securityhealthservice', 'sihost', 'ctfmon', 'textinputhost')
        $trimmed = 0
        foreach ($p in [System.Diagnostics.Process]::GetProcesses()) {
            if ($p.Id -le 4 -or $p.Id -eq $PID -or $p.Id -eq $SkipPid -or $skip -contains $p.ProcessName.ToLower()) { continue }
            $h = [RoxNative]::OpenProcess(0x1100, $false, $p.Id)
            if ($h -ne [IntPtr]::Zero) {
                if ([RoxNative]::EmptyWorkingSet($h)) { $trimmed++ }
                [void][RoxNative]::CloseHandle($h)
            }
        }
        $status = [RoxNative]::PurgeStandbyList()
        Write-Ok ("Trimmed $trimmed background processes" + $(if ($status -eq 0) { ', standby memory emptied' } else { '' }))
    }
    if ((Test-SchemeExists $script:SchemeGuid) -and (Get-ActiveSchemeGuid) -ne $script:SchemeGuid) {
        $null = powercfg /setactive $script:SchemeGuid 2>&1
    }
    $after = (Get-RamInfo).UsedMB
    $freed = [math]::Max(0, $before - $after)
    Write-Ok ('RAM in use: {0:N0} MB -> {1:N0} MB (freed {2:N0} MB)' -f $before, $after, $freed)
    return [pscustomobject]@{ BeforeMB = $before; AfterMB = $after; FreedMB = $freed }
}

# Runs when a game starts (or right before ROX launches one).
function Invoke-GameBoost([int]$ProcessId = 0, [bool]$CloseApps = $true) {
    $closed = 0
    $freedApps = 0
    if ($CloseApps) {
        $targets = @(Get-BackgroundApps | Where-Object { $_.DefaultClose } | ForEach-Object { $_.ProcessName })
        if ($targets.Count -gt 0) {
            $r = Stop-BackgroundApps -Names $targets
            $closed = $r.Closed
            $freedApps = $r.FreedMB
        }
    }
    $ram = Invoke-CleanRam -SkipPid $ProcessId
    if ($ProcessId -gt 0) {
        try {
            $gp = Get-Process -Id $ProcessId -ErrorAction Stop
            $gp.PriorityClass = 'High'
            Write-Ok "$($gp.ProcessName): HIGH CPU priority"
        } catch { }
    }
    return [pscustomobject]@{ Closed = $closed; FreedMB = [math]::Round($freedApps + $ram.FreedMB) }
}

# ================================================================= GAMES LIBRARY

function Find-GameExe([string]$Dir) {
    if (-not $Dir -or -not (Test-Path -LiteralPath $Dir)) { return '' }
    $bad = 'unins|setup|install|crash|report|redist|vcredist|vc_redist|dxsetup|directx|dotnet|helper|launcher|' +
           'easyanticheat|battleye|beservice|update|patch|prereq|uninstall|config|benchmark|server|editor|' +
           'cefsharp|webview|7z|python|java|node|cleanup|touchup|unitycrash|ue4prereq|quicksfv'
    $best = Get-ChildItem -LiteralPath $Dir -Filter '*.exe' -File -Recurse -Depth 5 -ErrorAction SilentlyContinue |
            Where-Object { $_.BaseName -notmatch $bad } |
            Sort-Object -Property Length -Descending |
            Select-Object -First 1
    if ($best) { return $best.FullName }
    return ''
}

function Find-SteamGames {
    $steam = Get-RegValue 'HKCU:\Software\Valve\Steam' 'SteamPath'
    if (-not $steam) { $steam = Get-RegValue 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' 'InstallPath' }
    if (-not $steam) { return @() }
    $steam = ([string]$steam) -replace '/', '\'
    if (-not (Test-Path -LiteralPath $steam)) { return @() }
    $libs = New-Object System.Collections.Generic.List[string]
    $libs.Add($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
        foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) {
            $lp = $m.Groups[1].Value -replace '\\\\', '\'
            if (-not $libs.Contains($lp)) { $libs.Add($lp) }
        }
    }
    $out = New-Object System.Collections.ArrayList
    foreach ($lib in $libs) {
        $apps = Join-Path $lib 'steamapps'
        foreach ($acf in @(Get-ChildItem -LiteralPath $apps -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue)) {
            $t    = Get-Content -LiteralPath $acf.FullName -Raw -ErrorAction SilentlyContinue
            $id   = [regex]::Match($t, '"appid"\s+"(\d+)"').Groups[1].Value
            $name = [regex]::Match($t, '"name"\s+"([^"]+)"').Groups[1].Value
            $dir  = [regex]::Match($t, '"installdir"\s+"([^"]+)"').Groups[1].Value
            if (-not $id -or -not $name) { continue }
            if ($id -in @('228980', '1070560', '1391110', '1628350', '1493710', '250820', '1826330')) { continue }
            if ($name -match 'Redistributable|Proton|Steam Linux Runtime|SteamVR|Steamworks|Dedicated Server|Soundtrack') { continue }
            $full = Join-Path $apps ('common\' + $dir)
            if (-not (Test-Path -LiteralPath $full)) { continue }
            $img = $null
            foreach ($c in @("appcache\librarycache\$id\header.jpg", "appcache\librarycache\${id}_header.jpg",
                             "appcache\librarycache\$id\library_hero.jpg")) {
                $cp = Join-Path $steam $c
                if (Test-Path -LiteralPath $cp) { $img = $cp; break }
            }
            if (-not $img) {
                $hdir = Join-Path $steam "appcache\librarycache\$id"
                if (Test-Path -LiteralPath $hdir) {
                    $h = Get-ChildItem -LiteralPath $hdir -Filter '*.jpg' -File -Recurse -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1
                    if ($h) { $img = $h.FullName }
                }
            }
            [void]$out.Add([pscustomobject]@{
                Id = "steam:$id"; Name = $name; Source = 'Steam'; InstallDir = $full; Exe = ''
                LaunchUri = "steam://rungameid/$id"; LaunchExe = ''; LaunchArgs = ''; Image = $img; AppId = $id
            })
        }
    }
    return @($out)
}

function Find-EpicGames {
    $dir = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    if (-not (Test-Path -LiteralPath $dir)) { return @() }
    $out = New-Object System.Collections.ArrayList
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter '*.item' -File -ErrorAction SilentlyContinue)) {
        try { $j = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json } catch { continue }
        if ($j.bIsIncompleteInstall) { continue }
        if ($j.AppCategories -and (@($j.AppCategories) -notcontains 'games')) { continue }
        if (-not $j.InstallLocation -or -not (Test-Path -LiteralPath $j.InstallLocation)) { continue }
        $uri = 'com.epicgames.launcher://apps/{0}%3A{1}%3A{2}?action=launch&silent=true' -f $j.CatalogNamespace, $j.CatalogItemId, $j.AppName
        [void]$out.Add([pscustomobject]@{
            Id = "epic:$($j.AppName)"; Name = $j.DisplayName; Source = 'Epic'; InstallDir = $j.InstallLocation; Exe = ''
            LaunchUri = $uri; LaunchExe = ''; LaunchArgs = ''; Image = $null; AppId = ''
            Hint = (Join-Path $j.InstallLocation ([string]$j.LaunchExecutable))
        })
    }
    return @($out)
}

function Find-RiotGames {
    $meta = Join-Path $env:ProgramData 'Riot Games\Metadata'
    if (-not (Test-Path -LiteralPath $meta)) { return @() }
    $client = ''
    $installs = Join-Path $env:ProgramData 'Riot Games\RiotClientInstalls.json'
    if (Test-Path -LiteralPath $installs) {
        try { $client = [string](Get-Content -LiteralPath $installs -Raw | ConvertFrom-Json).rc_default } catch { }
    }
    $names = @{ 'valorant' = 'VALORANT'; 'league_of_legends' = 'League of Legends'; 'bacon' = 'Legends of Runeterra'; 'lion' = '2XKO' }
    $out = New-Object System.Collections.ArrayList
    foreach ($f in @(Get-ChildItem -LiteralPath $meta -Filter '*.product_settings.yaml' -File -Recurse -ErrorAction SilentlyContinue)) {
        $t = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
        $path = [regex]::Match($t, 'product_install_full_path:\s*"?([^"\r\n]+?)"?\s*(\r|\n|$)').Groups[1].Value
        $tag = $f.Name -replace '\.product_settings\.yaml$', ''
        $parts = $tag.Split('.')
        $product = $parts[0]
        if ($product -eq 'riot_client' -or -not $path -or -not (Test-Path -LiteralPath $path)) { continue }
        $patch = 'live'
        if ($parts.Count -gt 1) { $patch = $parts[1] }
        $display = $names[$product]
        if (-not $display) { $display = (Get-Culture).TextInfo.ToTitleCase($product.Replace('_', ' ')) }
        [void]$out.Add([pscustomobject]@{
            Id = "riot:$product"; Name = $display; Source = 'Riot'; InstallDir = $path; Exe = ''
            LaunchUri = ''; LaunchExe = $client; LaunchArgs = "--launch-product=$product --launch-patchline=$patch"
            Image = $null; AppId = ''
        })
    }
    return @($out)
}

# Finds installed games and merges them with the saved list (keeps the Optimized flags and manual games).
function Find-InstalledGames {
    Write-Step 'Looking for your games (Steam, Epic, Riot)'
    $saved = @{}
    foreach ($g in @(Get-RoxGames)) { if ($g.Id) { $saved[[string]$g.Id] = $g } }
    $found = @()
    $found += @(Find-SteamGames)
    $found += @(Find-EpicGames)
    $found += @(Find-RiotGames)
    $result = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($g in $found) {
        if ($seen.ContainsKey($g.Id)) { continue }
        $seen[$g.Id] = $true
        $old = $saved[$g.Id]
        $exe = ''
        if ($old -and $old.Exe -and (Test-Path -LiteralPath $old.Exe)) { $exe = $old.Exe }
        if (-not $exe) { $exe = Find-GameExe $g.InstallDir }
        if (-not $exe -and $g.Hint -and (Test-Path -LiteralPath $g.Hint)) { $exe = $g.Hint }
        [void]$result.Add([pscustomobject]@{
            Id = $g.Id; Name = $g.Name; Source = $g.Source; Exe = $exe; InstallDir = $g.InstallDir
            LaunchUri = $g.LaunchUri; LaunchExe = $g.LaunchExe; LaunchArgs = $g.LaunchArgs; Image = $g.Image; AppId = $g.AppId
            Optimized = [bool]($old -and $old.Optimized)
        })
    }
    foreach ($old in $saved.Values) {
        if ($seen.ContainsKey([string]$old.Id)) { continue }
        if ($old.Source -eq 'Manual' -and $old.Exe -and (Test-Path -LiteralPath $old.Exe)) { [void]$result.Add($old) }
    }
    Write-Ok ('Found {0} game(s)' -f $result.Count)
    return @($result | Sort-Object -Property Name)
}

function Set-GameOptimization([string]$Exe, [bool]$On) {
    if (-not $Exe) { Write-Attention 'This game has no .exe yet - choose it first'; return }
    Import-Backup
    $name  = [IO.Path]::GetFileName($Exe)
    $gpuKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    $ifeo  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\{0}\PerfOptions' -f $name
    if ($On) {
        Set-Reg $gpuKey $Exe 'GpuPreference=2;' 'String'
        Set-Reg $ifeo 'CpuPriorityClass' 3
        Write-Ok "$name : strong GPU + HIGH CPU priority, boosted automatically when it starts"
    } else {
        Reset-RegValue $gpuKey $Exe
        Reset-RegValue $ifeo 'CpuPriorityClass'
        Write-Ok "$name : back to normal"
    }
    Export-Backup
}

function Start-RoxGame($Game) {
    if ($Game.LaunchUri) {
        Start-Process $Game.LaunchUri
    } elseif ($Game.LaunchExe -and (Test-Path -LiteralPath $Game.LaunchExe)) {
        Start-Process -FilePath $Game.LaunchExe -ArgumentList $Game.LaunchArgs
    } elseif ($Game.Exe -and (Test-Path -LiteralPath $Game.Exe)) {
        # Through Explorer so the game starts as the normal user (not as administrator).
        Start-Process -FilePath (Join-Path $env:windir 'explorer.exe') -ArgumentList ('"{0}"' -f $Game.Exe)
    } else {
        Write-Attention "Can not start $($Game.Name) - its file was not found"
        return
    }
    Write-Ok "Starting $($Game.Name)"
}

function Get-SteamAppIdForPath([string]$Path) {
    $m = [regex]::Match([string]$Path, '\\steamapps\\common\\([^\\]+)\\', 'IgnoreCase')
    if (-not $m.Success) { return '' }
    $dir = $m.Groups[1].Value
    foreach ($g in @(Get-RoxGames)) {
        if ($g.Source -eq 'Steam' -and $g.InstallDir -and ([IO.Path]::GetFileName([string]$g.InstallDir) -eq $dir)) { return [string]$g.AppId }
    }
    return ''
}

# ================================================================= CRASH DOCTOR

function Get-CrashCause([string]$Module, [string]$Code, [string]$App) {
    $m = ([string]$Module).ToLower()
    $c = ([string]$Code).ToLower() -replace '^0x', ''
    if ($m -match '^(nvwgf2um|nvd3dum|nvoglv|nvlddmkm|nvcuda|nvapi|nvgpucomp|nvwgf2umx)') { return 'gpu-nvidia' }
    if ($m -match '^(atidxx|amdxx|atiumd|aticfx|amdvlk|atio6axx|amdihk|amfrt|amdenc)') { return 'gpu-amd' }
    if ($m -match '^(igd10iumd|igd12umd|igdumd|igc64|igxelpicd|igd9|igdusc|ig9icd|ig75icd|igdml)') { return 'gpu-intel' }
    if ($m -match '^(d3d11|d3d12|d3d12core|dxgi|d3d9|dxcore|vulkan-1)\.dll') { return 'gpu-generic' }
    if ($m -match '^(vcruntime|msvcp|ucrtbase|msvcr|concrt|vccorlib|mfc1)') { return 'runtime-vc' }
    if ($m -match '^(d3dx9|d3dx10|d3dx11|xinput1_|xaudio2_[0-7]|d3dcompiler_4[0-3]|x3daudio)') { return 'runtime-dx' }
    if ($m -match '^(clr|coreclr|clrjit|mscorlib|system\.|kernelbase\.dll)' -and $c -eq 'e0434352') { return 'runtime-net' }
    if ($m -match '^(gameoverlayrenderer|rtsshooks|discordhook|nvspcap|obs-|graphics-hook|igo|ubisoftoverlay|overlay|reshade|mshook)') { return 'overlay' }
    if ($m -match 'easyanticheat|beclient|battleye|vgk|vanguard|faceit|eac_|eaanticheat') { return 'anticheat' }
    if ($c -in @('c0000135', 'c0000139', 'c000007b')) { return 'missing-dll' }
    if ($c -in @('c0000017', 'c000012d')) { return 'memory' }
    if ($App -and $m -eq ([string]$App).ToLower()) { return 'game-files' }
    if ($c -in @('c0000005', 'c0000409', 'c0000374', '80000003')) { return 'game-files' }
    return 'unknown'
}

function Get-BugcheckCause([string]$Text) {
    $m = [regex]::Match([string]$Text, '0x([0-9a-fA-F]{1,8})')
    if (-not $m.Success) { return @('bsod-system', '') }
    $code = [Convert]::ToInt64($m.Groups[1].Value, 16)
    $hex = '0x{0:X}' -f $code
    if (@(0x116, 0x117, 0x119, 0x10E, 0x141) -contains $code) { return @('bsod-gpu', $hex) }
    if (@(0x124, 0x101, 0x9C, 0x12B) -contains $code) { return @('bsod-hw', $hex) }
    if (@(0x1A, 0x50, 0x4E, 0x12) -contains $code) { return @('bsod-ram', $hex) }
    if (@(0x133, 0x9F, 0xD1, 0xA, 0x3B, 0x7E, 0x1E, 0xC2, 0x139) -contains $code) { return @('bsod-driver', $hex) }
    return @('bsod-system', $hex)
}

function Get-CrashFixId([string]$Cause) {
    switch -Regex ($Cause) {
        '^gpu-|^tdr$|^bsod-gpu$'                 { return 'gpu' }
        '^runtime-|^missing-dll$'                { return 'runtimes' }
        '^memory$|^low-memory$'                  { return 'pagefile' }
        '^bsod-ram$'                             { return 'memtest' }
        '^bsod-driver$|^bsod-system$'            { return 'sfc' }
        '^hang$'                                 { return 'boost' }
        '^disk$'                                 { return 'disk' }
        '^game-files$|^anticheat$|^unknown$'     { return 'verify' }
    }
    return ''
}

function Get-CrashFindings([int]$Days = 14) {
    Write-Step "Reading crash reports from the last $Days days"
    $since = (Get-Date).AddDays(-$Days)
    $groups = @{}
    $add = {
        param($Key, $Kind, $Cause, $App, $Module, $Code, $Path, $Time)
        if (-not $groups.ContainsKey($Key)) {
            $groups[$Key] = [pscustomobject]@{
                Kind = $Kind; Cause = $Cause; App = $App; Module = $Module; Code = $Code; Path = $Path
                Count = 0; Last = $Time; FixId = (Get-CrashFixId $Cause); Extra = ''; IsGame = $false
            }
        }
        $g = $groups[$Key]
        $g.Count++
        if ($Time -gt $g.Last) { $g.Last = $Time }
    }

    $quiet = 'searchhost|searchapp|explorer|shellexperiencehost|startmenuexperiencehost|textinputhost|msedgewebview2|' +
             'backgroundtaskhost|runtimebroker|svchost|dllhost|werfault|consent|powershell|rox|setup|installer|update'
    foreach ($e in @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Id = 1000, 1002; StartTime = $since } -MaxEvents 400 -ErrorAction SilentlyContinue)) {
        try {
            $p = $e.Properties
            $app = [string]$p[0].Value
            if (-not $app -or $app -match $quiet) { continue }
            if ($e.Id -eq 1000) {
                $module = [string]$p[3].Value
                $code   = [string]$p[6].Value
                $path   = ''
                if ($p.Count -gt 10) { $path = [string]$p[10].Value }
                $cause  = Get-CrashCause $module $code $app
            } else {
                $module = 'hang'
                $code   = 'hang'
                $path   = ''
                foreach ($v in $p) { if ([string]$v.Value -match '\\[^\\]+\.exe$') { $path = [string]$v.Value; break } }
                $cause  = 'hang'
            }
            & $add ("app|$app|$cause") 'app' $cause $app $module $code $path $e.TimeCreated
        } catch { }
    }

    $sys = @(
        @{ P = 'Display';                                       I = @(4101);              C = 'tdr' },
        @{ P = 'Microsoft-Windows-WER-SystemErrorReporting';    I = @(1001);              C = 'bsod' },
        @{ P = 'Microsoft-Windows-Kernel-Power';                I = @(41);                C = 'power' },
        @{ P = 'Microsoft-Windows-WHEA-Logger';                 I = @(1, 17, 18, 19, 47); C = 'whea' },
        @{ P = 'Microsoft-Windows-Resource-Exhaustion-Detector'; I = @(2004);             C = 'low-memory' },
        @{ P = 'disk';                                          I = @(7, 51, 153);        C = 'disk' }
    )
    foreach ($s in $sys) {
        foreach ($e in @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = $s.P; Id = $s.I; StartTime = $since } -MaxEvents 100 -ErrorAction SilentlyContinue)) {
            try {
                $cause = $s.C
                $code  = ''
                if ($cause -eq 'bsod') {
                    $bc = Get-BugcheckCause ([string]$e.Properties[0].Value + ' ' + [string]$e.Message)
                    $cause = $bc[0]
                    $code  = $bc[1]
                }
                if ($cause -eq 'power' -and [int64]$e.Properties[0].Value -ne 0) { continue }   # had a bugcheck -> counted as BSOD
                & $add ("sys|$cause") 'system' $cause '' '' $code '' $e.TimeCreated
            } catch { }
        }
    }

    $gameDirs = 'steamapps|epic games|riot games|\\games\\|xboxgames|ubisoft|ea games|battle\.net|gog galaxy|rockstar'
    $known = @{}
    foreach ($g in @(Get-RoxGames)) { if ($g.Exe) { $known[[IO.Path]::GetFileName([string]$g.Exe).ToLower()] = $true } }
    $list = @($groups.Values)
    foreach ($g in $list) {
        if ($g.Kind -eq 'app') {
            $g.IsGame = ($known.ContainsKey(([string]$g.App).ToLower()) -or [string]$g.Path -match $gameDirs)
            if ($g.FixId -eq 'verify') {
                $id = Get-SteamAppIdForPath $g.Path
                if ($id) { $g.Extra = $id } else { $g.FixId = 'runtimes' }
            }
        }
    }
    $list = @($list | Sort-Object -Property @{ Expression = { if ($_.Kind -eq 'system' -or $_.IsGame) { 0 } else { 1 } } }, @{ Expression = 'Last'; Descending = $true })
    Write-Ok ('Found {0} crash type(s)' -f $list.Count)
    return $list
}

function Set-TdrDelay {
    Write-Step 'GPU: give the graphics driver more time before Windows resets it (fewer black-screen crashes)'
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'TdrDelay' 8
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'TdrDdiDelay' 10
    Write-Ok 'GPU timeout raised to 8 seconds (after restart)'
}

function Set-PagefileAuto {
    Write-Step 'Memory: let Windows manage the page file (stops "out of memory" crashes)'
    $mm = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    $cur = @(Get-RegValue $mm 'PagingFiles')
    if ($cur.Count -eq 1 -and [string]$cur[0] -match '^\?:\\pagefile\.sys') {
        Write-Ok 'Page file is already managed by Windows'
        return
    }
    Set-Reg $mm 'PagingFiles' ([string[]]@('?:\pagefile.sys')) 'MultiString'
    try {
        Get-CimInstance Win32_ComputerSystem -ErrorAction Stop | Set-CimInstance -Property @{ AutomaticManagedPagefile = $true } -ErrorAction Stop
    } catch { Write-Log "AutomaticManagedPagefile: $($_.Exception.Message)" }
    Write-Ok 'Page file set to automatic (after restart)'
}

function Install-GameRuntimes {
    Write-Step 'Installing / repairing game runtimes (Visual C++, DirectX, .NET)'
    $pkgs = [ordered]@{
        'Microsoft.VCRedist.2015+.x64'      = 'Visual C++ 2015-2022 (64-bit)'
        'Microsoft.VCRedist.2015+.x86'      = 'Visual C++ 2015-2022 (32-bit)'
        'Microsoft.DirectX'                 = 'DirectX End-User Runtime'
        'Microsoft.DotNet.DesktopRuntime.8' = '.NET Desktop Runtime 8'
    }
    foreach ($id in @($pkgs.Keys)) {
        if (Install-WithWinget -Ids @($id) -ExactName '') { Write-Ok $pkgs[$id] }
        else { Write-Attention ("Could not install " + $pkgs[$id]) }
    }
}

function Update-AllApps {
    Write-Step 'Updating your apps (winget)'
    if (-not (Test-Winget)) { Write-Skip 'winget is not available on this PC'; return }
    $code = Invoke-WingetStream @('upgrade', '--all', '--silent', '--accept-package-agreements', '--accept-source-agreements')
    if ($code -eq 0) { Write-Ok 'Apps are up to date' } else { Write-Info "winget finished (code $code)" }
}

function Invoke-SystemRepair {
    Write-Step 'Repairing Windows system files (DISM + SFC) - this can take 10-30 minutes'
    $old = [Console]::OutputEncoding
    try {
        & dism.exe /Online /Cleanup-Image /RestoreHealth 2>&1 | ForEach-Object {
            $l = (([string]$_) -split "`r")[-1].Trim()
            if ($l -and $l -notmatch '^\[[=\s\d.%]*\]$') { Write-Info $l }
        }
        Write-Ok "DISM finished (code $LASTEXITCODE)"
        [Console]::OutputEncoding = [Text.Encoding]::Unicode
        & sfc.exe /scannow 2>&1 | ForEach-Object {
            $l = (([string]$_) -replace "`0", '' -split "`r")[-1].Trim()
            if ($l -and $l -notmatch '\d+%') { Write-Info $l }
        }
        Write-Ok "SFC finished (code $LASTEXITCODE)"
    } finally { [Console]::OutputEncoding = $old }
}

function Invoke-RoxFix([string]$FixId, [string]$Extra = '') {
    Import-Backup
    switch ($FixId) {
        'gpu'      { Invoke-Safe 'TDR' { Set-TdrDelay }; Invoke-Safe 'Drivers' { Set-GpuDriverUpdates } }
        'runtimes' { Invoke-Safe 'Runtimes' { Install-GameRuntimes } }
        'pagefile' { Invoke-Safe 'Pagefile' { Set-PagefileAuto } }
        'verify'   {
            if ($Extra -match '^\d+$') { Start-Process "steam://validate/$Extra"; Write-Ok 'Steam is checking the game files now' }
            else { Invoke-Safe 'Runtimes' { Install-GameRuntimes } }
        }
        'sfc'      { Invoke-Safe 'Repair' { Invoke-SystemRepair } }
        'memtest'  { Start-Process (Join-Path $env:windir 'System32\mdsched.exe'); Write-Ok 'Windows Memory Diagnostic opened' }
        'boost'    { $null = Invoke-CleanRam }
        'disk'     {
            Write-Step 'Checking the system disk (online scan)'
            & chkdsk.exe $env:SystemDrive /scan 2>&1 | ForEach-Object { $l = ([string]$_).Trim(); if ($l -and $l -notmatch '\d+ percent|\d+%') { Write-Info $l } }
            Write-Ok "Disk check finished (code $LASTEXITCODE)"
        }
        default    { Write-Attention "Unknown fix: $FixId" }
    }
    Export-Backup
}

# The big green button: optimize + update + repair.
function Invoke-UpdateAndFixAll([bool]$DeepRepair = $true) {
    Invoke-OptimizeAll
    Import-Backup
    Invoke-Safe 'Runtimes' { Install-GameRuntimes }
    Invoke-Safe 'Apps' { Update-AllApps }
    Invoke-Safe 'Crash fixes' {
        $f = @(Get-CrashFindings -Days 14)
        if (@($f | Where-Object { $_.FixId -eq 'pagefile' }).Count -gt 0) { Set-PagefileAuto }
        if (@($f | Where-Object { $_.FixId -eq 'gpu' }).Count -gt 0) { Set-TdrDelay }
    }
    Export-Backup
    if ($DeepRepair) { Invoke-Safe 'System repair' { Invoke-SystemRepair } }
    Write-Ok 'Everything is updated and fixed - restart the PC to finish'
}

# ================================================================= SYSTEM STATE / SCORE

function Get-SystemState {
    $c = [ordered]@{}
    $active = Get-ActiveSchemeGuid
    $c.plan      = ($active -eq $script:SchemeGuid -or $active -eq $script:UltimateGuid -or $active -eq $script:HighGuid)
    $c.gamemode  = ((Get-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled') -ne 0) -and
                   ((Get-RegValue 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled') -eq 0)
    $c.hags      = (Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode') -eq 2
    $c.telemetry = (Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack' 'Start') -eq 4
    $c.network   = (Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex') -eq -1
    $c.input     = [string](Get-RegValue 'HKCU:\Control Panel\Mouse' 'MouseSpeed') -eq '0'
    $c.svchost   = [int64](Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB') -gt 3670016
    $c.startup   = (Get-HeavyStartupCount) -eq 0
    $tempMB      = Get-FolderSizeMB $env:TEMP
    $c.temp      = $tempMB -lt 500
    $ram         = Get-RamInfo
    $gpus        = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    $days        = 9999
    foreach ($g in $gpus) {
        if ($g.DriverDate) { try { $d = ((Get-Date) - [datetime]$g.DriverDate).Days; if ($d -lt $days) { $days = $d } } catch { } }
    }
    $c.driver    = $days -le 150
    $crashes     = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Id = 1000; StartTime = (Get-Date).AddDays(-7) } -MaxEvents 50 -ErrorAction SilentlyContinue |
                     Where-Object { [string]$_.Properties[0].Value -notmatch 'searchhost|explorer|msedgewebview2|backgroundtaskhost|runtimebroker|svchost' }).Count
    $c.crashes   = $crashes -eq 0

    $weights = @{ plan = 14; gamemode = 10; hags = 8; telemetry = 8; network = 5; input = 4; svchost = 6; startup = 8; temp = 5; driver = 10; crashes = 10 }
    $score = 0.0
    foreach ($k in $weights.Keys) { if ($c[$k]) { $score += $weights[$k] } }
    $ramScore = 12 * [math]::Max(0, [math]::Min(1, (85 - $ram.Percent) / 40))
    $score += $ramScore
    return [pscustomobject]@{
        Score      = [math]::Round([math]::Min(100, $score))
        Checks     = [pscustomobject]$c
        RamPercent = $ram.Percent
        RamUsedMB  = $ram.UsedMB
        RamTotalMB = $ram.TotalMB
        TempMB     = $tempMB
        DriverDays = $days
        Crashes    = $crashes
        Gpus       = @($gpus | ForEach-Object { [string]$_.Name })
    }
}

function Get-GpuVendorGuess {
    $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    if (@($gpus | Where-Object { $_.PNPDeviceID -match 'VEN_10DE' }).Count) { return 'nvidia' }
    if (@($gpus | Where-Object { $_.PNPDeviceID -match 'VEN_1002' }).Count) { return 'amd' }
    if (@($gpus | Where-Object { $_.PNPDeviceID -match 'VEN_8086' }).Count) { return 'intel' }
    return ''
}

# ================================================================= MEMORY INTEGRITY / AUTOSTART / UNDO

function Set-MemoryIntegrity([bool]$Enable) {
    Import-Backup
    $key = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
    if ($Enable) {
        Reset-RegValue $key 'Enabled'
        if ((Get-RegValue $key 'Enabled') -ne 1) { New-ItemProperty -LiteralPath $key -Name 'Enabled' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null }
        Write-Ok 'Memory Integrity will be ON after restart'
    } else {
        Set-Reg $key 'Enabled' 0
        Write-Ok 'Memory Integrity will be OFF after restart (more FPS, less protection)'
    }
    Export-Backup
}

function Get-MemoryIntegrityOn {
    return (Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled') -eq 1
}

function Set-RoxAutostart([bool]$On, [string]$ScriptPath) {
    $name = 'ROX'
    if ($On) {
        $user = '{0}\{1}' -f $env:USERDOMAIN, $env:USERNAME
        $arg  = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Tray' -f $ScriptPath
        $action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
        $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
        $principal = New-ScheduledTaskPrincipal -UserId $user -RunLevel Highest -LogonType Interactive
        $set       = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)
        Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Principal $principal -Settings $set -Force -ErrorAction Stop | Out-Null
        Write-Ok 'ROX starts with Windows (in the tray) to boost your games automatically'
    } else {
        Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
        Write-Ok 'ROX no longer starts with Windows'
    }
}

function Invoke-RoxRestore {
    Write-Step 'Undo: putting back your original settings'
    if (-not (Test-Path -LiteralPath $script:BackupFile)) {
        Write-Attention 'No ROX backup found - nothing to undo (Windows System Restore point "ROX - before tweaks" may also exist).'
        return
    }
    Import-Backup
    $reg = @($script:Backup.Registry)
    [array]::Reverse($reg)
    $ok = 0
    foreach ($e in $reg) {
        try { Restore-RegEntry $e; $ok++ } catch { Write-Log "Restore failed: $($e.Path) | $($e.Name) : $($_.Exception.Message)" }
    }
    Write-Ok "$ok registry settings restored"
    $keys = @($script:Backup.CreatedKeys)
    [array]::Reverse($keys)
    foreach ($k in $keys) {
        $item = Get-Item -LiteralPath $k -ErrorAction SilentlyContinue
        if ($item -and $item.ValueCount -eq 0 -and $item.SubKeyCount -eq 0) { Remove-Item -LiteralPath $k -Force -ErrorAction SilentlyContinue }
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
        try { [void][RoxNative]::PowerSetActiveOverlayScheme([guid]$script:Backup.PowerOverlay) } catch { }
    }
    Write-Ok 'Original power plan restored'
    Unregister-ScheduledTask -TaskName 'ROX' -Confirm:$false -ErrorAction SilentlyContinue
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Move-Item -LiteralPath $script:BackupFile -Destination (Join-Path $script:DataDir "backup-restored-$stamp.json") -Force -ErrorAction SilentlyContinue
    $legacy = Join-Path $env:ProgramData 'GameBoost\backup.json'
    if (Test-Path -LiteralPath $legacy) { Move-Item -LiteralPath $legacy -Destination (Join-Path $env:ProgramData "GameBoost\backup-restored-$stamp.json") -Force -ErrorAction SilentlyContinue }
    Write-Ok 'Everything is back to how it was - restart the PC to finish'
}
