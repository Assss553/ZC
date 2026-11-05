<#
================================================================================
  ROX  -  gaming optimizer for Windows 10 / 11   (Arabic + English)
  Start it with ROX.bat (double-click). Needs administrator rights.
  ROX.ps1 -Tray            start hidden next to the clock (used by "start with Windows")
  ROX.ps1 -RenderTest DIR  build the UI and save screenshots of every page (CI)
  ROX.ps1 -SelfTest        run the engine end-to-end and undo it (CI)
================================================================================
#>
param(
    [switch]$Tray,
    [string]$RenderTest = '',
    [switch]$SelfTest
)
Set-StrictMode -Off
$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'

$script:Here        = Split-Path -Parent $PSCommandPath
$script:EnginePath  = Join-Path $script:Here 'RoxEngine.ps1'
$script:StringsPath = Join-Path $script:Here 'RoxStrings.ps1'
$script:XamlPath    = Join-Path $script:Here 'ROX.xaml'
$script:TestMode    = [bool]($RenderTest -or $SelfTest)
$script:IconVersion = 3

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml, System.Windows.Forms, System.Drawing

# ----------------------------------------------------------------- administrator
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ($script:TestMode) { Write-Host 'ROX tests need administrator rights'; exit 2 }
    $a = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $PSCommandPath
    if ($Tray) { $a += ' -Tray' }
    try { Start-Process -FilePath 'powershell.exe' -ArgumentList $a -Verb RunAs -ErrorAction Stop }
    catch { [void][System.Windows.Forms.MessageBox]::Show("ROX يحتاج صلاحيات المسؤول.`nROX needs administrator rights.", 'ROX') }
    exit
}

. $script:EnginePath
. $script:StringsPath

# ----------------------------------------------------------------- self test (engine only, used by CI)
if ($SelfTest) {
    $watch = @(
        @('HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers', 'HwSchMode'),
        @('HKCU:\System\GameConfigStore', 'GameDVR_Enabled'),
        @('HKCU:\Control Panel\Mouse', 'MouseSpeed'),
        @('HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl', 'Win32PrioritySeparation'),
        @('HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack', 'Start')
    )
    $before = @{}
    foreach ($w in $watch) { $before[$w[0] + '|' + $w[1]] = [string](Get-RegValue $w[0] $w[1]) }
    $tests = @(
        'Get-RoxSettings | Out-Null',
        'Get-SystemState | Format-List Score, RamPercent, DriverDays, Crashes | Out-String',
        'Get-CpuDetails | Format-List | Out-String',
        '(Get-BackgroundApps | Select-Object -First 8 | Format-Table ProcessName, RamMB, Category, DefaultClose | Out-String)',
        '(Find-InstalledGames).Count',
        '(Get-CrashFindings -Days 30 | Format-Table Cause, App, Module, Count, FixId | Out-String)',
        "Invoke-RoxModule -Id 'power'",
        "Invoke-RoxModule -Id 'gaming'",
        "Invoke-RoxModule -Id 'gpu'",
        "Invoke-RoxModule -Id 'win'",
        "Invoke-RoxModule -Id 'ram'",
        "Invoke-RoxModule -Id 'startup'",
        "Invoke-RoxModule -Id 'network'",
        "Invoke-RoxModule -Id 'input'",
        "Invoke-RoxModule -Id 'cleanup'",
        'Get-SystemState | Select-Object -ExpandProperty Score',
        'Invoke-CleanRam | Format-List | Out-String',
        'Invoke-GameBoost -ProcessId 0 -CloseApps $false | Format-List | Out-String',
        "Set-GameOptimization -Exe (Join-Path `$env:windir 'notepad.exe') -On `$true",
        "Set-GameOptimization -Exe (Join-Path `$env:windir 'notepad.exe') -On `$false",
        'Import-Backup; Set-TdrDelay; Set-PagefileAuto; Export-Backup',
        'Get-MemoryIntegrityOn',
        "Set-RoxAutostart -On `$true -ScriptPath 'C:\ROX\ROX.ps1'",
        "Set-RoxAutostart -On `$false -ScriptPath 'C:\ROX\ROX.ps1'",
        'Invoke-RoxRestore'
    )
    $fails = 0
    foreach ($t in $tests) {
        $Error.Clear()
        try {
            $out = & ([scriptblock]::Create($t))
            Write-Host ("PASS  {0}" -f $t) -ForegroundColor Green
            if ($out) { Write-Host (($out | Out-String).Trim()) }
        } catch {
            $fails++
            Write-Host ("FAIL  {0}`n      {1}`n      {2}" -f $t, $_.Exception.Message, $_.ScriptStackTrace) -ForegroundColor Red
        }
        foreach ($e in @($Error | Select-Object -First 5)) { Write-Host ("      note: {0}" -f $e) -ForegroundColor DarkYellow }
    }
    foreach ($w in $watch) {
        $k = $w[0] + '|' + $w[1]
        $now = [string](Get-RegValue $w[0] $w[1])
        if ($now -ne $before[$k]) { $fails++; Write-Host "FAIL  restore mismatch $k : before='$($before[$k])' now='$now'" -ForegroundColor Red }
        else { Write-Host "PASS  restored $k = '$now'" -ForegroundColor Green }
    }
    # every key used by the UI must exist in both languages
    foreach ($k in $script:Strings['ar'].Keys) { if (-not $script:Strings['en'].ContainsKey($k)) { $fails++; Write-Host "FAIL  string '$k' missing in English" -ForegroundColor Red } }
    foreach ($k in $script:Strings['en'].Keys) { if (-not $script:Strings['ar'].ContainsKey($k)) { $fails++; Write-Host "FAIL  string '$k' missing in Arabic" -ForegroundColor Red } }
    $xamlText = [IO.File]::ReadAllText($script:XamlPath)
    foreach ($m in [regex]::Matches($xamlText, 'DynamicResource (S_[A-Za-z0-9_]+)')) {
        if (-not $script:Strings['ar'].ContainsKey($m.Groups[1].Value)) { $fails++; Write-Host "FAIL  XAML uses unknown string $($m.Groups[1].Value)" -ForegroundColor Red }
    }
    Write-Host "SELFTEST DONE - $fails failure(s)"
    exit $fails
}

# ----------------------------------------------------------------- single instance
$script:ShowEvent = $null
if (-not $script:TestMode) {
    $created = $false
    $script:Mutex = New-Object System.Threading.Mutex($true, 'Global\ROX_SingleInstance', [ref]$created)
    $script:ShowEvent = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, 'Global\ROX_ShowWindow')
    if (-not $created) { [void]$script:ShowEvent.Set(); exit }
}

# ----------------------------------------------------------------- bindable item
if (-not ('RoxItem' -as [type])) {
    Add-Type -Language CSharp -TypeDefinition @'
using System.ComponentModel;

public class RoxItem : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler PropertyChanged;
    private void Notify(string name) { PropertyChangedEventHandler h = PropertyChanged; if (h != null) h(this, new PropertyChangedEventArgs(name)); }
    private string _key, _title, _subtitle, _detail, _badge, _icon, _accent, _tint, _image, _initial, _actionText;
    private bool _isChecked, _isOn, _hasBadge, _hasAction;
    private object _tag;
    public string Key        { get { return _key; }        set { _key = value; Notify("Key"); } }
    public string Title      { get { return _title; }      set { _title = value; Notify("Title"); } }
    public string Subtitle   { get { return _subtitle; }   set { _subtitle = value; Notify("Subtitle"); } }
    public string Detail     { get { return _detail; }     set { _detail = value; Notify("Detail"); } }
    public string Badge      { get { return _badge; }      set { _badge = value; Notify("Badge"); } }
    public string Icon       { get { return _icon; }       set { _icon = value; Notify("Icon"); } }
    public string Accent     { get { return _accent; }     set { _accent = value; Notify("Accent"); } }
    public string Tint       { get { return _tint; }       set { _tint = value; Notify("Tint"); } }
    public string Image      { get { return _image; }      set { _image = value; Notify("Image"); } }
    public string Initial    { get { return _initial; }    set { _initial = value; Notify("Initial"); } }
    public string ActionText { get { return _actionText; } set { _actionText = value; Notify("ActionText"); } }
    public bool IsChecked    { get { return _isChecked; }  set { _isChecked = value; Notify("IsChecked"); } }
    public bool IsOn         { get { return _isOn; }       set { _isOn = value; Notify("IsOn"); } }
    public bool HasBadge     { get { return _hasBadge; }   set { _hasBadge = value; Notify("HasBadge"); } }
    public bool HasAction    { get { return _hasAction; }  set { _hasAction = value; Notify("HasAction"); } }
    public object Tag        { get { return _tag; }        set { _tag = value; Notify("Tag"); } }
}
'@
}

function New-RoxItem([hashtable]$P) {
    $i = New-Object RoxItem
    foreach ($k in $P.Keys) { $i.$k = $P[$k] }
    return $i
}

# The comma keeps PowerShell from unrolling the (empty) collection into $null.
function New-ItemList { return , (New-Object 'System.Collections.ObjectModel.ObservableCollection[RoxItem]') }

# ----------------------------------------------------------------- language
$script:Lang = 'ar'
function T([string]$Key) {
    $v = $script:Strings[$script:Lang][$Key]
    if ($null -eq $v) { $v = $script:Strings['en'][$Key] }
    if ($null -eq $v) { $v = $Key }
    return [string]$v
}

$script:ModuleDefs = @(
    @{ Key = 'win';     Icon = 0xE770; Accent = '#FF60A5FA'; Check = 'telemetry' },
    @{ Key = 'gaming';  Icon = 0xE7FC; Accent = '#FFA78BFA'; Check = 'gamemode' },
    @{ Key = 'gpu';     Icon = 0xE7F4; Accent = '#FFFF7A85'; Check = 'hags' },
    @{ Key = 'power';   Icon = 0xE945; Accent = '#FFFFD166'; Check = 'plan' },
    @{ Key = 'cleanup'; Icon = 0xE74D; Accent = '#FF34F5B4'; Check = 'temp' },
    @{ Key = 'network'; Icon = 0xE701; Accent = '#FF22D3EE'; Check = 'network' },
    @{ Key = 'input';   Icon = 0xE765; Accent = '#FFF472B6'; Check = 'input' },
    @{ Key = 'startup'; Icon = 0xE7E8; Accent = '#FFFB923C'; Check = 'startup' },
    @{ Key = 'ram';     Icon = 0xE9D9; Accent = '#FF4ADE80'; Check = 'svchost' }
)
$script:CatColor = @{ app = '#FF2D3A8C'; launcher = '#FF5B2A9E'; chat = '#FF0F6A8A'; browser = '#FF7A4A12'; tool = '#FF7A1F4A' }
$script:Palette  = @('#FF3B2A7A', '#FF1E4D7A', '#FF6B2A4D', '#FF22604A', '#FF6B4D2A', '#FF2A4D6B', '#FF4A2A6B', '#FF6B2A2A')
$script:VendorName = @{ amd = 'AMD'; nvidia = 'NVIDIA'; intel = 'Intel' }

function Get-PaletteColor([string]$Text) {
    $h = 0
    foreach ($ch in ([string]$Text).ToCharArray()) { $h = ($h * 31 + [int]$ch) % 100003 }
    return $script:Palette[$h % $script:Palette.Count]
}

function Get-Initial([string]$Text) {
    $t = ([string]$Text).Trim()
    if (-not $t) { return '?' }
    return $t.Substring(0, 1).ToUpper()
}

# ----------------------------------------------------------------- the ROX logo (vector, drawn - no image files)
$script:LogoXaml = @'
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Width="256" Height="256" FlowDirection="LeftToRight">
  <Border Margin="16" CornerRadius="66">
    <Border.Background>
      <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
        <GradientStop Color="#FF8B5CF6" Offset="0"/>
        <GradientStop Color="#FF6366F1" Offset="0.48"/>
        <GradientStop Color="#FF06B6D4" Offset="1"/>
      </LinearGradientBrush>
    </Border.Background>
    <Border.Effect><DropShadowEffect Color="#FF6D28D9" BlurRadius="22" ShadowDepth="0" Opacity="0.6"/></Border.Effect>
  </Border>
  <Border Margin="16" CornerRadius="66">
    <Border.Background>
      <RadialGradientBrush Center="0.26,0.1" GradientOrigin="0.26,0.1" RadiusX="0.85" RadiusY="0.7">
        <GradientStop Color="#66FFFFFF" Offset="0"/><GradientStop Color="#00FFFFFF" Offset="1"/>
      </RadialGradientBrush>
    </Border.Background>
  </Border>
  <Border Margin="16" CornerRadius="66" BorderBrush="#45FFFFFF" BorderThickness="3"/>
  <Canvas>
    <Border Canvas.Left="56" Canvas.Top="84"  Width="36" Height="12" CornerRadius="6" Background="#F2FFFFFF"/>
    <Border Canvas.Left="42" Canvas.Top="112" Width="50" Height="12" CornerRadius="6" Background="#C0FFFFFF"/>
    <Border Canvas.Left="64" Canvas.Top="140" Width="28" Height="12" CornerRadius="6" Background="#8CFFFFFF"/>
    <Path Data="M 100,62 L 158,62 A 38,38 0 0 1 158,138 L 204,194 L 166,194 L 132,142 L 132,194 L 100,194 Z M 132,92 L 158,92 A 8,8 0 0 1 158,108 L 132,108 Z">
      <Path.Fill>
        <LinearGradientBrush StartPoint="0,0" EndPoint="0,1">
          <GradientStop Color="#FFFFFFFF" Offset="0"/><GradientStop Color="#FFE0F2FE" Offset="1"/>
        </LinearGradientBrush>
      </Path.Fill>
      <Path.Effect><DropShadowEffect Color="#FF1E1B4B" BlurRadius="14" ShadowDepth="5" Direction="270" Opacity="0.45"/></Path.Effect>
    </Path>
  </Canvas>
</Grid>
'@

function New-LogoElement { return [Windows.Markup.XamlReader]::Parse($script:LogoXaml) }

function Get-LogoPngBytes([int]$Size, [string]$Background = '') {
    $host2 = New-Object System.Windows.Controls.Grid
    $host2.Width = $Size
    $host2.Height = $Size
    if ($Background) { $host2.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($Background) }
    $vb = New-Object System.Windows.Controls.Viewbox
    $vb.Child = New-LogoElement
    [void]$host2.Children.Add($vb)
    $host2.Measure((New-Object System.Windows.Size($Size, $Size)))
    $host2.Arrange((New-Object System.Windows.Rect(0, 0, $Size, $Size)))
    $host2.UpdateLayout()
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($Size, $Size, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($host2)
    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $ms = New-Object System.IO.MemoryStream
    $enc.Save($ms)
    return , $ms.ToArray()
}

# Writes rox-v3.ico (256/64/48/32/24/16, PNG frames) + PNGs for the window and tray.
function New-RoxIcon {
    $png = Join-Path $script:DataDir 'rox-v3-256.png'
    $png32 = Join-Path $script:DataDir 'rox-v3-32.png'
    $ico = Join-Path $script:DataDir 'rox-v3.ico'
    if ((Test-Path -LiteralPath $png) -and (Test-Path -LiteralPath $ico) -and (Test-Path -LiteralPath $png32)) { return }
    try {
        $sizes = @(256, 64, 48, 32, 24, 16)
        $frames = @{}
        foreach ($s in $sizes) { $frames[$s] = Get-LogoPngBytes $s }
        [IO.File]::WriteAllBytes($png, $frames[256])
        [IO.File]::WriteAllBytes($png32, $frames[32])
        $fs = [IO.File]::Create($ico)
        $bw = New-Object System.IO.BinaryWriter($fs)
        $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
        $offset = 6 + 16 * $sizes.Count
        foreach ($s in $sizes) {
            $dim = [byte]0
            if ($s -lt 256) { $dim = [byte]$s }
            $bw.Write($dim); $bw.Write($dim); $bw.Write([byte]0); $bw.Write([byte]0)
            $bw.Write([uint16]1); $bw.Write([uint16]32)
            $bw.Write([uint32]$frames[$s].Length); $bw.Write([uint32]$offset)
            $offset += $frames[$s].Length
        }
        foreach ($s in $sizes) { $bw.Write($frames[$s]) }
        $bw.Close()
    } catch { Write-Log "icon: $($_.Exception.Message)" }
}

# ----------------------------------------------------------------- window
$script:App = [System.Windows.Application]::Current
if (-not $script:App) { $script:App = New-Object System.Windows.Application; $script:App.ShutdownMode = 'OnExplicitShutdown' }

$reader = [System.Xml.XmlReader]::Create($script:XamlPath)
$window = [Windows.Markup.XamlReader]::Load($reader)
$reader.Close()
$ui = @{}
foreach ($m in [regex]::Matches([IO.File]::ReadAllText($script:XamlPath), 'x:Name="([^"]+)"')) {
    $n = $m.Groups[1].Value
    $el = $window.FindName($n)
    if ($el) { $ui[$n] = $el }
}

$script:Settings  = Get-RoxSettings
$script:Modules   = New-ItemList
$script:HomeMods  = New-ItemList
$script:Games     = New-ItemList
$script:Apps      = New-ItemList
$script:Crashes   = New-ItemList
$script:Logs      = New-ItemList
$script:GameData  = New-Object System.Collections.ArrayList
$script:GameByExe = @{}
$script:LastApps  = $null
$script:LastCrashes = $null
$script:LastBoost = ''
$script:NoAnim    = [bool]$RenderTest
$script:ScoreTarget = 0.0
$script:ScoreShown  = -1.0
$script:ToastUntil  = $null
$script:TickCount   = 0
$script:Exiting     = $false
$script:CrashScanned = $false
$script:LangBusy    = $false
$script:CurrentPage = 'PageHome'
$script:Hist = @{
    cpu  = (New-Object System.Collections.Generic.List[double])
    gpu  = (New-Object System.Collections.Generic.List[double])
    ram  = (New-Object System.Collections.Generic.List[double])
    proc = (New-Object System.Collections.Generic.List[double])
}

$ui.HomeModules.ItemsSource = $script:HomeMods
$ui.ModulesList.ItemsSource = $script:Modules
$ui.GamesList.ItemsSource   = $script:Games
$ui.AppsList.ItemsSource    = $script:Apps
$ui.CrashList.ItemsSource   = $script:Crashes
$ui.DrawerLog.ItemsSource   = $script:Logs

New-RoxIcon
$script:IconPng = Join-Path $script:DataDir 'rox-v3-256.png'
try { $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create((New-Object System.Uri($script:IconPng))) } catch { }
foreach ($h in 'LogoHost', 'AboutLogoHost', 'ModalLogoHost') { try { $ui[$h].Child = New-LogoElement } catch { } }

# ----------------------------------------------------------------- animation helpers
function New-Ease { $e = New-Object System.Windows.Media.Animation.CubicEase; $e.EasingMode = 'EaseOut'; return $e }
function New-Dur([int]$Ms) { return (New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds($Ms))) }

function Start-FadeIn($El, [double]$FromY = 16) {
    if ($script:NoAnim) { $El.Opacity = 1; return }
    $a = New-Object System.Windows.Media.Animation.DoubleAnimation(0.0, 1.0, (New-Dur 260))
    $a.EasingFunction = New-Ease
    $El.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $a)
    if ($El.RenderTransform -is [System.Windows.Media.TranslateTransform]) {
        $t = New-Object System.Windows.Media.Animation.DoubleAnimation($FromY, 0.0, (New-Dur 320))
        $t.EasingFunction = New-Ease
        $El.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $t)
    }
}

# Draws the score ring as an arc (0-100 %).
function Set-ScoreRing([double]$Pct) {
    $size = 180.0; $th = 14.0
    $r = ($size - $th) / 2
    $c = $size / 2
    $p = [math]::Max(0.002, [math]::Min(0.9995, $Pct / 100.0))
    $ang = 2 * [math]::PI * $p
    $ex = $c + $r * [math]::Sin($ang)
    $ey = $c - $r * [math]::Cos($ang)
    $large = 0
    if ($p -gt 0.5) { $large = 1 }
    $d = [string]::Format([Globalization.CultureInfo]::InvariantCulture, 'M {0},{1} A {2},{2} 0 {3} 1 {4},{5}', $c, ($c - $r), $r, $large, $ex, $ey)
    $ui.ScoreArc.Data = [System.Windows.Media.Geometry]::Parse($d)
}

function Update-Spark($Canvas, $Line, $Area, $Values, [double]$Max) {
    $w = $Canvas.ActualWidth
    $h = $Canvas.ActualHeight
    if ($w -lt 4 -or $h -lt 4 -or $Values.Count -lt 2) { return }
    if ($Max -le 0) { $Max = 1 }
    $slots = 40
    $start = $slots - $Values.Count
    $pts = New-Object System.Windows.Media.PointCollection
    for ($i = 0; $i -lt $Values.Count; $i++) {
        $x = $w * ($start + $i) / ($slots - 1)
        $v = [math]::Max(0.0, [math]::Min($Max, [double]$Values[$i]))
        $y = $h - 3 - ($v / $Max) * ($h - 6)
        $pts.Add((New-Object System.Windows.Point($x, $y)))
    }
    $Line.Points = $pts
    $ap = $pts.Clone()
    $ap.Add((New-Object System.Windows.Point($pts[$pts.Count - 1].X, $h)))
    $ap.Add((New-Object System.Windows.Point($pts[0].X, $h)))
    $Area.Points = $ap
}

function Add-Hist([string]$Key, [double]$Value) {
    $l = $script:Hist[$Key]
    $l.Add($Value)
    while ($l.Count -gt 40) { $l.RemoveAt(0) }
}

# ----------------------------------------------------------------- toast + drawer + modals
function Show-Toast([string]$Text, [string]$Kind = 'ok') {
    $ui.ToastText.Text = $Text
    $glyph = [string][char]0xE73E
    if ($Kind -eq 'warn') { $glyph = [string][char]0xE7BA }
    $ui.ToastIcon.Text = $glyph
    $ui.Toast.Visibility = 'Visible'
    Start-FadeIn $ui.Toast -FromY -10
    $script:ToastUntil = (Get-Date).AddSeconds(3.5)
}

function Hide-Toast { $script:ToastUntil = $null; $ui.Toast.Visibility = 'Collapsed' }

function Open-Drawer([string]$Title) {
    $script:Logs.Clear()
    $ui.DrawerTitle.Text = $Title
    $ui.DrawerStatus.Text = T 'D_Starting'
    $ui.DrawerSpinner.Visibility = 'Visible'
    $ui.DrawerDone.Visibility = 'Collapsed'
    $ui.Drawer.Visibility = 'Visible'
    if (-not $script:NoAnim) {
        $a = New-Object System.Windows.Media.Animation.DoubleAnimation(290.0, 0.0, (New-Dur 380))
        $a.EasingFunction = New-Ease
        $ui.Drawer.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $a)
    }
}

function Close-Drawer { $ui.Drawer.Visibility = 'Collapsed' }

function Complete-Drawer([bool]$Ok) {
    $ui.DrawerSpinner.Visibility = 'Collapsed'
    $ui.DrawerDone.Visibility = 'Visible'
    if ($Ok) { $ui.DrawerStatus.Text = T 'D_Done' } else { $ui.DrawerStatus.Text = T 'D_Notes' }
}

function Add-LogLine($Evt) {
    $color = '#FF9A9AB0'
    switch ([string]$Evt.Kind) {
        'step' { $color = '#FFB9A2FF' }
        'ok'   { $color = '#FF34F5B4' }
        'warn' { $color = '#FFFFDD6E' }
        'skip' { $color = '#FF5A5A76' }
    }
    $script:Logs.Add((New-RoxItem @{ Title = [string]$Evt.Text; Accent = $color; Key = [string]$Evt.Kind }))
    while ($script:Logs.Count -gt 400) { $script:Logs.RemoveAt(0) }
    if ($Evt.Kind -eq 'step') { $ui.DrawerStatus.Text = [string]$Evt.Text }
    $ui.DrawerScroll.ScrollToEnd()
}

function Show-Confirm([string]$Title, [string]$Text, [string]$YesText, [scriptblock]$OnYes, [string]$AltText = '', [scriptblock]$OnAlt = $null) {
    $ui.ConfirmTitle.Text = $Title
    $ui.ConfirmText.Text = $Text
    $ui.ConfirmYes.Content = $YesText
    $ui.ConfirmNo.Content = T 'S_Cancel'
    $script:ConfirmOnYes = $OnYes
    $script:ConfirmOnAlt = $OnAlt
    if ($AltText) { $ui.ConfirmAlt.Content = $AltText; $ui.ConfirmAlt.Visibility = 'Visible' } else { $ui.ConfirmAlt.Visibility = 'Collapsed' }
    $ui.ModalConfirm.Visibility = 'Visible'
    Start-FadeIn $ui.ModalConfirm -FromY 0
}

function Request-Restart {
    Show-Confirm (T 'C_RestartTitle') (T 'C_RestartText') (T 'C_RestartYes') { Restart-Computer -Force } '' $null
    $ui.ConfirmNo.Content = T 'C_Later'
}

# ----------------------------------------------------------------- background jobs (UI never freezes)
$script:LogQueue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
$script:JobQueue = New-Object System.Collections.Queue
$script:Job      = $null
$script:Pool     = [runspacefactory]::CreateRunspacePool(1, 1)
$script:Pool.ApartmentState = 'STA'
$script:Pool.Open()

$script:WorkerBootstrap = @'
param($EnginePath, $Queue, $Code, $Params)
if (-not (Get-Command Invoke-RoxModule -ErrorAction SilentlyContinue)) { . $EnginePath }
$script:RoxSink = $Queue
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$P = $Params
& ([scriptblock]::Create($Code))
'@

function Start-RoxJob {
    param([string]$Title, [string]$Code, [hashtable]$P = @{}, [scriptblock]$OnDone = $null, [switch]$Quiet, [hashtable]$Ctx = @{})
    $script:JobQueue.Enqueue([pscustomobject]@{ Title = $Title; Code = $Code; P = $P; OnDone = $OnDone; Quiet = [bool]$Quiet; Ctx = $Ctx; Ps = $null; Handle = $null })
    Start-NextJob
}

function Start-NextJob {
    if ($null -ne $script:Job -or $script:JobQueue.Count -eq 0) { return }
    $j = $script:JobQueue.Dequeue()
    $ps = [PowerShell]::Create()
    $ps.RunspacePool = $script:Pool
    [void]$ps.AddScript($script:WorkerBootstrap).AddArgument($script:EnginePath).AddArgument($script:LogQueue).AddArgument($j.Code).AddArgument($j.P)
    $j.Ps = $ps
    $j.Handle = $ps.BeginInvoke()
    $script:Job = $j
    $ui.BusyChipText.Text = $j.Title
    $ui.BusyChip.Visibility = 'Visible'
    if (-not $j.Quiet) { Open-Drawer $j.Title }
}

function Complete-RoxJob {
    $j = $script:Job
    $script:Job = $null
    $result = @()
    $err = $null
    try { $result = @($j.Ps.EndInvoke($j.Handle)) } catch {
        $err = $_.Exception.Message
        if ($_.Exception.InnerException) { $err = $_.Exception.InnerException.Message }
    }
    $evt = $null
    while ($script:LogQueue.TryDequeue([ref]$evt)) { Add-LogLine $evt }
    foreach ($e in @($j.Ps.Streams.Error | Select-Object -First 4)) {
        Write-Log "job '$($j.Title)' error: $e"
        if (-not $j.Quiet) { Add-LogLine ([pscustomobject]@{ Kind = 'warn'; Text = [string]$e }) }
    }
    $j.Ps.Dispose()
    if ($err) { Write-Log "job '$($j.Title)' failed: $err"; Add-LogLine ([pscustomobject]@{ Kind = 'warn'; Text = $err }) }
    if (-not $j.Quiet) { Complete-Drawer (-not $err) }
    if ($script:JobQueue.Count -eq 0) { $ui.BusyChip.Visibility = 'Collapsed' }
    if ($j.OnDone) {
        try { & $j.OnDone $result $err $j.Ctx } catch { Write-Log "OnDone '$($j.Title)': $($_.Exception.Message)" }
    }
    Start-NextJob
}

# ----------------------------------------------------------------- live stats + game watcher (own thread)
$script:Sync = [hashtable]::Synchronized(@{
    Stop = $false; Visible = $true; Cpu = -1; Gpu = -1; RamUsed = 0; RamTotal = 0; Procs = 0
    GameNames  = [string[]]@()
    Boosted    = [hashtable]::Synchronized(@{})
    GameEvents = (New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]')
})
$statsCode = @'
param($Sync)
$tick = 0
while (-not $Sync.Stop) {
    try {
        $tick++
        $procs = [System.Diagnostics.Process]::GetProcesses()
        $Sync.Procs = $procs.Length
        $names = $Sync.GameNames
        if ($names -and $names.Count -gt 0) {
            $alive = @{}
            foreach ($p in $procs) {
                $n = $p.ProcessName.ToLower()
                if ($names -contains $n) {
                    $alive[$p.Id] = $true
                    if (-not $Sync.Boosted.ContainsKey($p.Id)) {
                        $Sync.Boosted[$p.Id] = $n
                        $Sync.GameEvents.Enqueue([pscustomobject]@{ Pid = $p.Id; Name = $n })
                    }
                }
            }
            foreach ($k in @($Sync.Boosted.Keys)) { if (-not $alive.ContainsKey($k)) { $Sync.Boosted.Remove($k) } }
        }
        foreach ($p in $procs) { $p.Dispose() }
        if ($Sync.Visible) {
            $cpu = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue
            if ($cpu) { $Sync.Cpu = [int]$cpu.PercentProcessorTime }
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
            if ($os) {
                $Sync.RamTotal = [math]::Round($os.TotalVisibleMemorySize / 1KB)
                $Sync.RamUsed  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1KB)
            }
            if ($tick % 2 -eq 0) {
                $eng = @(Get-CimInstance -ClassName Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -Filter "Name LIKE '%engtype_3D%'" -ErrorAction SilentlyContinue)
                $sum = 0
                foreach ($e in $eng) { $sum += [int]$e.UtilizationPercentage }
                $Sync.Gpu = [int][math]::Min(100, $sum)
            }
        }
    } catch { }
    Start-Sleep -Milliseconds 1500
}
'@
$script:StatsPs = [PowerShell]::Create()
[void]$script:StatsPs.AddScript($statsCode).AddArgument($script:Sync)
$script:StatsHandle = $script:StatsPs.BeginInvoke()

function Update-Stats {
    $s = $script:Sync
    if ($s.Cpu -ge 0) { $ui.CpuText.Text = '{0}%' -f $s.Cpu; Add-Hist 'cpu' $s.Cpu }
    if ($s.Gpu -ge 0) { $ui.GpuText.Text = '{0}%' -f $s.Gpu; Add-Hist 'gpu' $s.Gpu }
    if ($s.RamTotal -gt 0) {
        $ui.RamText.Text = '{0:N1} / {1:N0} GB' -f ($s.RamUsed / 1024), ($s.RamTotal / 1024)
        Add-Hist 'ram' (100.0 * $s.RamUsed / $s.RamTotal)
    }
    if ($s.Procs -gt 0) { $ui.ProcText.Text = [string]$s.Procs; Add-Hist 'proc' $s.Procs }
    Update-Sparks
}

function Update-Sparks {
    Update-Spark $ui.CpuChart $ui.CpuLine $ui.CpuArea $script:Hist.cpu 100
    Update-Spark $ui.GpuChart $ui.GpuLine $ui.GpuArea $script:Hist.gpu 100
    Update-Spark $ui.RamChart $ui.RamLine $ui.RamArea $script:Hist.ram 100
    $pmax = 100.0
    foreach ($v in $script:Hist.proc) { if ($v * 1.2 -gt $pmax) { $pmax = $v * 1.2 } }
    Update-Spark $ui.ProcChart $ui.ProcLine $ui.ProcArea $script:Hist.proc $pmax
}

function Update-ScoreAnim {
    $d = $script:ScoreTarget - $script:ScoreShown
    if ([math]::Abs($d) -lt 0.4) {
        if ($script:ScoreShown -ne $script:ScoreTarget) { $script:ScoreShown = $script:ScoreTarget } else { return }
    } else {
        $script:ScoreShown += $d * 0.14
    }
    $ui.ScoreText.Text = '{0:N0}%' -f [math]::Max(0, $script:ScoreShown)
    Set-ScoreRing $script:ScoreShown
}

function Update-HeroText {
    $k = 'H_Low'
    if ($script:ScoreTarget -ge 80) { $k = 'H_Good' } elseif ($script:ScoreTarget -ge 50) { $k = 'H_Mid' }
    $ui.HeroText.Text = T $k
}

# ----------------------------------------------------------------- modules / state
function Initialize-Modules {
    $script:Modules.Clear()
    foreach ($d in $script:ModuleDefs) {
        $fav = @($script:Settings.Favorites) -contains $d.Key
        $script:Modules.Add((New-RoxItem @{
            Key = $d.Key; Icon = [string][char]$d.Icon; Accent = $d.Accent; Tint = ('#22' + $d.Accent.Substring(3))
            IsOn = $fav; HasBadge = $false; Tag = $d.Check
        }))
    }
    Update-ModuleTexts
    Update-HomeModules
}

function Update-ModuleTexts {
    foreach ($m in $script:Modules) {
        $m.Title = T ('M_{0}_t' -f $m.Key)
        $m.Subtitle = T ('M_{0}_s' -f $m.Key)
        $m.Badge = T 'Badge_On'
    }
}

function Update-HomeModules {
    $script:HomeMods.Clear()
    foreach ($m in $script:Modules) { if ($m.IsOn) { $script:HomeMods.Add($m) } }
}

function Update-Favorites {
    $script:Settings.Favorites = @($script:Modules | Where-Object { $_.IsOn } | ForEach-Object { $_.Key })
    Save-RoxSettings $script:Settings
    Update-HomeModules
}

function Update-State {
    Start-RoxJob (T 'J_State') 'Get-SystemState' -Quiet -OnDone {
        param($r, $e)
        $st = $r | Select-Object -Last 1
        if (-not $st) { return }
        $script:ScoreTarget = [double]$st.Score
        foreach ($m in $script:Modules) { $m.HasBadge = [bool]$st.Checks.($m.Tag) }
        $gpu = @($st.Gpus) | Where-Object { $_ } | Select-Object -First 1
        if ($gpu) { $ui.GpuCardSub.Text = $gpu }
        Update-HeroText
    }
}

function Invoke-ModuleJob([string]$Key) {
    Start-RoxJob ((T 'J_Apply') -f (T ('M_{0}_t' -f $Key))) 'Invoke-RoxModule -Id $P.Id' @{ Id = $Key } -OnDone {
        param($r, $e)
        Show-Toast (T 'T_Applied')
        Update-State
    }
}

# ----------------------------------------------------------------- games
function ConvertTo-GameItem($G) {
    $img = $null
    if ($G.Image -and (Test-Path -LiteralPath ([string]$G.Image))) { $img = [string]$G.Image }
    $badge = [string]$G.Source
    if ($badge -eq 'Manual') { $badge = T 'Src_Manual' }
    $sub = ''
    if ($G.Exe) { $sub = [IO.Path]::GetFileName([string]$G.Exe) }
    return (New-RoxItem @{ Key = [string]$G.Id; Title = [string]$G.Name; Subtitle = $sub; Badge = $badge; Image = $img
                           Initial = (Get-Initial $G.Name); Accent = (Get-PaletteColor $G.Name); IsOn = [bool]$G.Optimized; Tag = $G })
}

function Show-Games {
    $script:Games.Clear()
    foreach ($g in $script:GameData) { $script:Games.Add((ConvertTo-GameItem $g)) }
    $ui.GamesCount.Text = [string]$script:GameData.Count
    if ($script:GameData.Count -eq 0) { $ui.GamesEmpty.Visibility = 'Visible' } else { $ui.GamesEmpty.Visibility = 'Collapsed' }
    Update-GameWatch
}

function Update-GameWatch {
    $names = New-Object System.Collections.Generic.List[string]
    $script:GameByExe = @{}
    foreach ($g in $script:GameData) {
        if ($g.Optimized -and $g.Exe) {
            $n = [IO.Path]::GetFileNameWithoutExtension([string]$g.Exe).ToLower()
            if (-not $names.Contains($n)) { $names.Add($n) }
            $script:GameByExe[$n] = [string]$g.Name
        }
    }
    $script:Sync.GameNames = $names.ToArray()
    Update-WatchText
}

function Update-WatchText {
    $n = @($script:Sync.GameNames).Count
    if ($n -gt 0) { $w = (T 'W_Count') -f $n } else { $w = T 'W_None' }
    $ui.WatchText.Text = $w
    $ui.SideWatch.Text = $w
    if ($script:LastBoost) { $ui.LastBoostText.Text = (T 'L_Last') -f $script:LastBoost } else { $ui.LastBoostText.Text = T 'L_None' }
}

function Save-Games { Save-RoxGames @($script:GameData) }

function Find-Games([switch]$Quiet) {
    Start-RoxJob (T 'J_FindGames') 'Find-InstalledGames' -Quiet:$Quiet -OnDone {
        param($r, $e)
        $script:GameData.Clear()
        foreach ($g in @($r)) { if ($g -and $g.Id) { [void]$script:GameData.Add($g) } }
        Save-Games
        Show-Games
    }
}

function Set-GameObjectValue($G, [string]$Name, $Value) {
    if ($G.PSObject.Properties.Name -contains $Name) { $G.$Name = $Value }
    else { $G | Add-Member -NotePropertyName $Name -NotePropertyValue $Value -Force }
}

function Select-GameExe($Item) {
    $g = $Item.Tag
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = T 'F_Filter'
    $dlg.Title = T 'F_Pick'
    if ($g.InstallDir -and (Test-Path -LiteralPath ([string]$g.InstallDir))) { $dlg.InitialDirectory = [string]$g.InstallDir }
    if ($dlg.ShowDialog($window) -ne $true) { return $false }
    $old = [string]$g.Exe
    if ($old -and $g.Optimized -and $old -ne $dlg.FileName) {
        Start-RoxJob (T 'J_UndoOld') 'Set-GameOptimization -Exe $P.Exe -On $false' @{ Exe = $old } -Quiet
    }
    Set-GameObjectValue $g 'Exe' $dlg.FileName
    $Item.Subtitle = [IO.Path]::GetFileName($dlg.FileName)
    Save-Games
    if ($g.Optimized) { Set-GameOpt $Item $true }
    return $true
}

function Set-GameOpt($Item, [bool]$On) {
    $g = $Item.Tag
    if ($On -and -not $g.Exe) {
        if (-not (Select-GameExe $Item)) { $Item.IsOn = $false; return }
    }
    Start-RoxJob ((T 'J_Boost') -f $g.Name) 'Set-GameOptimization -Exe $P.Exe -On ([bool]$P.On)' @{ Exe = [string]$g.Exe; On = $On } -Quiet -Ctx @{ G = $g; Item = $Item; On = $On } -OnDone {
        param($r, $e, $c)
        Set-GameObjectValue $c.G 'Optimized' ([bool]$c.On)
        $c.Item.IsOn = [bool]$c.On
        Save-Games
        Update-GameWatch
        if ($c.On) { Show-Toast ((T 'T_GameOn') -f $c.G.Name) } else { Show-Toast ((T 'T_GameOff') -f $c.G.Name) }
    }
}

function Invoke-PlayGame($Item) {
    $g = $Item.Tag
    $close = [bool]$script:Settings.CloseOnGameStart
    Start-RoxJob ((T 'J_Prepare') -f $g.Name) '$r = Invoke-GameBoost -ProcessId 0 -CloseApps ([bool]$P.Close); Start-RoxGame $P.Game; $r' @{ Close = $close; Game = $g } -Quiet -Ctx @{ Name = [string]$g.Name } -OnDone {
        param($r, $e, $c)
        $res = $r | Where-Object { $_ -and $_.PSObject.Properties.Name -contains 'FreedMB' } | Select-Object -Last 1
        if ($res) { Show-Toast ((T 'T_PlayFreed') -f $c.Name, $res.Closed, $res.FreedMB) } else { Show-Toast ((T 'T_Play') -f $c.Name) }
    }
}

function Add-ManualGame {
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = T 'F_Filter'
    $dlg.Title = T 'F_Add'
    if ($dlg.ShowDialog($window) -ne $true) { return }
    $exe = $dlg.FileName
    $name = [IO.Path]::GetFileNameWithoutExtension($exe)
    try {
        $vi = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exe)
        if ($vi.ProductName -and $vi.ProductName.Trim().Length -gt 1) { $name = $vi.ProductName.Trim() }
    } catch { }
    $g = [pscustomobject]@{
        Id = 'manual:' + $exe.ToLower(); Name = $name; Source = 'Manual'; Exe = $exe; InstallDir = (Split-Path -Parent $exe)
        LaunchUri = ''; LaunchExe = ''; LaunchArgs = ''; Image = $null; AppId = ''; Optimized = $false
    }
    foreach ($x in $script:GameData) { if ($x.Id -eq $g.Id) { Show-Toast (T 'T_GameExists') 'warn'; return } }
    [void]$script:GameData.Add($g)
    Save-Games
    Show-Games
    foreach ($it in $script:Games) { if ($it.Key -eq $g.Id) { $it.IsOn = $true; Set-GameOpt $it $true } }
}

function Invoke-GameDetected($Evt) {
    if (-not $script:Settings.AutoBoost) { return }
    $name = $script:GameByExe[[string]$Evt.Name]
    if (-not $name) { $name = [string]$Evt.Name }
    $script:LastBoost = $name
    Update-WatchText
    Start-RoxJob ((T 'J_Boost') -f $name) 'Invoke-GameBoost -ProcessId ([int]$P.Pid) -CloseApps ([bool]$P.Close)' @{ Pid = [int]$Evt.Pid; Close = [bool]$script:Settings.CloseOnGameStart } -Quiet -Ctx @{ Name = $name } -OnDone {
        param($r, $e, $c)
        $res = $r | Where-Object { $_ -and $_.PSObject.Properties.Name -contains 'FreedMB' } | Select-Object -Last 1
        $line = T 'G_Priority'
        if ($res) { $line = (T 'G_Line') -f $res.Closed, $res.FreedMB }
        Show-GameToast ((T 'G_Title') -f $c.Name) $line
    }
}

# Small notification in the corner that does not steal focus from the game.
function Show-GameToast([string]$Title, [string]$Line) {
    try {
        $x = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent" Topmost="True" ShowInTaskbar="False"
        SizeToContent="WidthAndHeight" ShowActivated="False" ResizeMode="NoResize"
        FontFamily="Segoe UI Variable Text, Segoe UI">
  <Border CornerRadius="22" Background="#F20E0E17" BorderBrush="#7734F5B4" BorderThickness="1" Padding="16,14" Margin="16">
    <Border.Effect><DropShadowEffect BlurRadius="26" ShadowDepth="0" Opacity="0.6"/></Border.Effect>
    <StackPanel Orientation="Horizontal">
      <Viewbox Name="LogoBox" Width="46" Height="46" FlowDirection="LeftToRight"/>
      <StackPanel Margin="14,0,6,0" VerticalAlignment="Center">
        <TextBlock Name="T1" FontSize="15" FontWeight="Bold" Foreground="White"/>
        <TextBlock Name="T2" FontSize="12" Foreground="#FFB9F5DC" Margin="0,3,0,0"/>
      </StackPanel>
    </StackPanel>
  </Border>
</Window>
'@
        $w = [Windows.Markup.XamlReader]::Parse($x)
        $w.FlowDirection = $window.FlowDirection
        $w.FindName('LogoBox').Child = New-LogoElement
        $w.FindName('T1').Text = $Title
        $w.FindName('T2').Text = $Line
        $w.Left = -4000
        $w.Top = -4000
        $w.Show()
        $w.UpdateLayout()
        $wa = [System.Windows.SystemParameters]::WorkArea
        $w.Left = $wa.Right - $w.ActualWidth - 8
        $w.Top  = $wa.Bottom - $w.ActualHeight - 8
        $t = New-Object System.Windows.Threading.DispatcherTimer
        $t.Interval = [TimeSpan]::FromSeconds(5)
        $t.Add_Tick({ $t.Stop(); $w.Close() }.GetNewClosure())
        $t.Start()
    } catch { Write-Log "game toast: $($_.Exception.Message)" }
}

# ----------------------------------------------------------------- background apps
function Update-Apps {
    Start-RoxJob (T 'J_Apps') 'Get-BackgroundApps' -Quiet -OnDone { param($r, $e) Show-Apps $r }
}

function Show-Apps($List) {
    $script:LastApps = @($List)
    $script:Apps.Clear()
    $total = 0.0
    foreach ($a in @($List)) {
        if (-not $a -or -not $a.ProcessName) { continue }
        $sub = '{0}.exe' -f $a.ProcessName
        if ($a.Company) { $sub += '  •  ' + $a.Company }
        $cat = [string]$a.Category
        if (-not $script:CatColor.ContainsKey($cat)) { $cat = 'app' }
        $script:Apps.Add((New-RoxItem @{
            Key = [string]$a.ProcessName; Title = [string]$a.Name; Subtitle = $sub; Detail = ('{0:N0} MB' -f $a.RamMB)
            Badge = (T ('Cat_' + $cat)); Accent = $script:CatColor[$cat]; Initial = (Get-Initial $a.Name)
            IsChecked = [bool]$a.DefaultClose; IsOn = [bool]$a.Keep; Tag = $a
        }))
        $total += [double]$a.RamMB
    }
    $ui.AppsRamText.Text = '{0:N1} GB' -f ($total / 1024)
    $ui.AppsCountText.Text = [string]$script:Apps.Count
    $ui.AppsProcText.Text = [string]$script:Sync.Procs
    if ($script:Apps.Count -eq 0) { $ui.AppsEmpty.Visibility = 'Visible' } else { $ui.AppsEmpty.Visibility = 'Collapsed' }
}

function Stop-Apps([string[]]$Names) {
    if (-not $Names -or $Names.Count -eq 0) { Show-Toast (T 'T_PickFirst') 'warn'; return }
    Start-RoxJob (T 'J_CloseApps') 'Stop-BackgroundApps -Names $P.Names' @{ Names = $Names } -Quiet -OnDone {
        param($r, $e)
        $res = $r | Where-Object { $_ -and $_.PSObject.Properties.Name -contains 'FreedMB' } | Select-Object -Last 1
        if ($res) {
            $msg = (T 'T_ClosedFreed') -f $res.Closed, $res.FreedMB
            if (@($res.StillOpen).Count -gt 0) { $msg += T 'T_StillOpen' }
            Show-Toast $msg
        }
        Update-Apps
    }
}

function Invoke-FreeRam {
    Start-RoxJob (T 'J_FreeRam') 'Invoke-CleanRam' -Quiet -OnDone {
        param($r, $e)
        $x = $r | Where-Object { $_ -and $_.PSObject.Properties.Name -contains 'FreedMB' } | Select-Object -Last 1
        if ($x) {
            Show-Toast ((T 'T_FreedRam') -f $x.FreedMB)
            if (-not $window.IsVisible) { Show-GameToast 'ROX' ((T 'G_Ram') -f $x.FreedMB) }
        }
    }
}

# ----------------------------------------------------------------- crash doctor
function Invoke-CrashScan {
    $ui.CrashSummary.Text = T 'X_Scanning'
    Start-RoxJob (T 'J_Crash') 'Get-CrashFindings -Days 14' -Quiet -OnDone { param($r, $e) Show-Crashes $r }
}

function Get-CauseColor([string]$Cause) {
    switch -Regex ($Cause) {
        '^gpu|^tdr|^bsod'     { return '#FFFF7070' }
        '^runtime|^missing'   { return '#FFFFDD6E' }
        '^overlay|^anticheat' { return '#FF60A5FA' }
        '^hang|memory'        { return '#FFB9A2FF' }
        '^power|^whea|^disk'  { return '#FFFB923C' }
    }
    return '#FF8C8CA8'
}

function Show-Crashes($List) {
    $script:CrashScanned = $true
    $script:LastCrashes = @($List)
    $script:Crashes.Clear()
    $culture = [Globalization.CultureInfo]::GetCultureInfo((T 'Date_Culture'))
    foreach ($f in @($List)) {
        if (-not $f -or -not $f.Cause) { continue }
        $cause = [string]$f.Cause
        if (-not $script:Strings['en'].ContainsKey("Cause_${cause}_t")) { $cause = 'unknown' }
        $parts = New-Object System.Collections.Generic.List[string]
        if ($f.App) { $parts.Add([string]$f.App) }
        if ($f.Module -and $f.Module -ne 'hang') { $parts.Add((T 'X_File') + $f.Module) }
        if ($f.Code -and $f.Code -ne 'hang') { $parts.Add((T 'X_Code') + $f.Code) }
        try { $parts.Add((T 'X_Last') + ([datetime]$f.Last).ToString('dd MMM HH:mm', $culture)) } catch { }
        $fix = [string]$f.FixId
        $fixText = ''
        if ($fix) { $fixText = T ('Fix_' + $fix) }
        $script:Crashes.Add((New-RoxItem @{
            Key = $fix; Title = (T "Cause_${cause}_t"); Detail = (T "Cause_${cause}_d"); Subtitle = ($parts -join '   •   ')
            Badge = ((T 'X_Times') -f $f.Count); Accent = (Get-CauseColor ([string]$f.Cause))
            ActionText = $fixText; HasAction = [bool]($fix -and $script:Strings['en'].ContainsKey('Fix_' + $fix)); Tag = $f
        }))
    }
    if ($script:Crashes.Count -eq 0) {
        $ui.CrashEmpty.Visibility = 'Visible'
        $ui.CrashSummary.Text = ''
    } else {
        $ui.CrashEmpty.Visibility = 'Collapsed'
        $ui.CrashSummary.Text = (T 'X_Summary') -f $script:Crashes.Count
    }
}

# ----------------------------------------------------------------- settings: GPU + language
function Update-VendorTiles {
    $sel = [string]$script:Settings.GpuVendor
    $map = @{ amd = 'SetAmd'; nvidia = 'SetNvidia'; intel = 'SetIntel' }
    $glow = @{ amd = '#FFFF7070'; nvidia = '#FF34F5B4'; intel = '#FF60A5FA' }
    $bc = New-Object System.Windows.Media.BrushConverter
    foreach ($k in $map.Keys) {
        $b = $ui[$map[$k]]
        if ($k -eq $sel) {
            $b.BorderBrush = $bc.ConvertFromString($glow[$k])
            $b.BorderThickness = New-Object System.Windows.Thickness(2.5)
        } else {
            $b.BorderBrush = $bc.ConvertFromString('#22FFFFFF')
            $b.BorderThickness = New-Object System.Windows.Thickness(1.5)
        }
    }
    $guess = Get-GpuVendorGuess
    $parts = @()
    if ($guess) { $parts += (T 'V_Detected') -f $script:VendorName[$guess] }
    if ($sel)   { $parts += (T 'V_Chosen') -f $script:VendorName[$sel] }
    $ui.SetGpuDetected.Text = ($parts -join '   •   ')
}

function Set-GpuVendor([string]$V) {
    $script:Settings.GpuVendor = $V
    $script:Settings.FirstRunDone = $true
    Save-RoxSettings $script:Settings
    $ui.ModalGpu.Visibility = 'Collapsed'
    Update-VendorTiles
    Show-Toast ((T 'T_GpuSet') -f $script:VendorName[$V])
}

function Show-GpuModal {
    $guess = Get-GpuVendorGuess
    if ($guess) { $ui.ModalDetected.Text = (T 'V_Detected') -f $script:VendorName[$guess] } else { $ui.ModalDetected.Text = '' }
    $tiles = @{ amd = 'ModalAmd'; nvidia = 'ModalNvidia'; intel = 'ModalIntel' }
    $bc = New-Object System.Windows.Media.BrushConverter
    foreach ($k in $tiles.Keys) {
        if ($k -eq $guess) {
            $ui[$tiles[$k]].BorderBrush = $bc.ConvertFromString('#FFFFFFFF')
            $ui[$tiles[$k]].BorderThickness = New-Object System.Windows.Thickness(2.5)
        }
    }
    $ui.ModalGpu.Visibility = 'Visible'
    Start-FadeIn $ui.ModalGpu -FromY 0
}

function Set-Language([string]$Code, [switch]$Save) {
    if ($Code -ne 'en') { $Code = 'ar' }
    if ($script:LangBusy) { return }
    $script:LangBusy = $true
    try {
        $script:Lang = $Code
        $tbl = $script:Strings[$Code]
        foreach ($k in @($tbl.Keys)) { if ($k.StartsWith('S_')) { $window.Resources[$k] = $tbl[$k] } }
        if ($Code -eq 'ar') {
            $window.FlowDirection = [System.Windows.FlowDirection]::RightToLeft
            $window.Resources['LogAlign'] = [System.Windows.TextAlignment]::Right
            $ui.SeeAllArrow.Text = [string][char]0xE72B
        } else {
            $window.FlowDirection = [System.Windows.FlowDirection]::LeftToRight
            $window.Resources['LogAlign'] = [System.Windows.TextAlignment]::Left
            $ui.SeeAllArrow.Text = [string][char]0xE72A
        }
        $ui.LangAr.IsChecked = ($Code -eq 'ar')
        $ui.LangEn.IsChecked = ($Code -eq 'en')
        $ui.ModalLangAr.IsChecked = ($Code -eq 'ar')
        $ui.ModalLangEn.IsChecked = ($Code -eq 'en')
        $culture = [Globalization.CultureInfo]::GetCultureInfo((T 'Date_Culture'))
        $ui.DateText.Text = (Get-Date).ToString('dddd  d MMMM yyyy', $culture)
        $ui.VersionText.Text = (T 'Version') -f $script:RoxVersion
        $ui.TitleText.Text = T ('S_Nav' + $script:CurrentPage.Substring(4))
        Update-ModuleTexts
        Update-HeroText
        Update-WatchText
        Update-VendorTiles
        Show-Games
        if ($null -ne $script:LastApps) { Show-Apps $script:LastApps }
        if ($null -ne $script:LastCrashes) { Show-Crashes $script:LastCrashes }
        Update-TrayTexts
        if ($Save) {
            $script:Settings.Language = $Code
            Save-RoxSettings $script:Settings
            Show-Toast (T 'T_Lang')
        }
    } finally { $script:LangBusy = $false }
}

# Copies ROX to C:\ProgramData\ROX\app and keeps a desktop shortcut that opens it as administrator.
function Install-RoxCopy {
    try {
        if (-not (Test-Path -LiteralPath $script:AppDir)) { New-Item -ItemType Directory -Path $script:AppDir -Force | Out-Null }
        if ($script:Here.TrimEnd('\') -ne $script:AppDir.TrimEnd('\')) {
            foreach ($f in 'ROX.ps1', 'ROX.xaml', 'RoxEngine.ps1', 'RoxStrings.ps1', 'ROX.bat') {
                $src = Join-Path $script:Here $f
                if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $script:AppDir $f) -Force }
            }
        }
        $lnkPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'ROX.lnk'
        if ((Test-Path -LiteralPath $lnkPath) -and [int]$script:Settings.IconVersion -ge $script:IconVersion) { return }
        $wsh = New-Object -ComObject WScript.Shell
        $lnk = $wsh.CreateShortcut($lnkPath)
        $lnk.TargetPath  = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $lnk.Arguments   = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f (Join-Path $script:AppDir 'ROX.ps1')
        $lnk.Description = 'ROX - game booster'
        $lnk.WindowStyle = 7
        $ico = Join-Path $script:DataDir 'rox-v3.ico'
        if (Test-Path -LiteralPath $ico) { $lnk.IconLocation = $ico }
        $lnk.Save()
        $bytes = [IO.File]::ReadAllBytes($lnkPath)
        $bytes[0x15] = $bytes[0x15] -bor 0x20          # "Run as administrator"
        [IO.File]::WriteAllBytes($lnkPath, $bytes)
        $script:Settings.IconVersion = $script:IconVersion
        Save-RoxSettings $script:Settings
    } catch { Write-Log "install copy: $($_.Exception.Message)" }
}

# ----------------------------------------------------------------- tray icon
function Show-Main {
    $window.Show()
    if ($window.WindowState -eq 'Minimized') { $window.WindowState = 'Normal' }
    [void]$window.Activate()
    $script:Sync.Visible = $true
}

function Exit-Rox {
    $script:Exiting = $true
    $script:Sync.Stop = $true
    try { $script:TrayIcon.Visible = $false; $script:TrayIcon.Dispose() } catch { }
    try { $window.Close() } catch { }
    $script:App.Shutdown()
}

function Hide-ToTray {
    $window.Hide()
    $script:Sync.Visible = $false
    if (-not $script:Settings.TrayHintShown -and $script:TrayIcon) {
        $script:TrayIcon.ShowBalloonTip(4000, (T 'Tr_HintTitle'), (T 'Tr_HintText'), [System.Windows.Forms.ToolTipIcon]::Info)
        $script:Settings.TrayHintShown = $true
        Save-RoxSettings $script:Settings
    }
}

$script:TrayItems = @{}
function New-TrayIcon {
    try {
        $ni = New-Object System.Windows.Forms.NotifyIcon
        try {
            $bmp = New-Object System.Drawing.Bitmap((Join-Path $script:DataDir 'rox-v3-32.png'))
            $ni.Icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
        } catch { $ni.Icon = [System.Drawing.SystemIcons]::Application }
        $ni.Text = 'ROX'
        $menu = New-Object System.Windows.Forms.ContextMenuStrip
        $script:TrayItems.open = $menu.Items.Add('ROX', $null, { Show-Main })
        $script:TrayItems.ram  = $menu.Items.Add('RAM', $null, { Invoke-FreeRam })
        $script:TrayItems.exit = $menu.Items.Add('Exit', $null, { Exit-Rox })
        $ni.ContextMenuStrip = $menu
        $ni.Add_MouseClick({ param($s, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Show-Main } })
        $ni.Visible = $true
        return $ni
    } catch { Write-Log "tray: $($_.Exception.Message)"; return $null }
}

function Update-TrayTexts {
    if (-not $script:TrayIcon) { return }
    try {
        $script:TrayItems.open.Text = T 'Tr_Open'
        $script:TrayItems.ram.Text  = T 'Tr_FreeRam'
        $script:TrayItems.exit.Text = T 'Tr_Exit'
        if ($script:Lang -eq 'ar') { $script:TrayIcon.ContextMenuStrip.RightToLeft = 'Yes' } else { $script:TrayIcon.ContextMenuStrip.RightToLeft = 'No' }
    } catch { }
}

# ----------------------------------------------------------------- navigation
$script:Pages = [ordered]@{
    NavHome = 'PageHome'; NavOptimize = 'PageOptimize'; NavGames = 'PageGames'
    NavApps = 'PageApps'; NavCrash = 'PageCrash'; NavSettings = 'PageSettings'
}

function Show-Page([string]$Page) {
    foreach ($p in $script:Pages.Values) { if ($p -ne $Page) { $ui[$p].Visibility = 'Collapsed' } }
    $script:CurrentPage = $Page
    $pg = $ui[$Page]
    $pg.Visibility = 'Visible'
    $pg.ScrollToTop()
    $ui.TitleText.Text = T ('S_Nav' + $Page.Substring(4))
    Start-FadeIn $pg
    switch ($Page) {
        'PageApps'     { Update-Apps }
        'PageCrash'    { if (-not $script:CrashScanned) { Invoke-CrashScan } }
        'PageSettings' { Update-VendorTiles; $ui.ChkSetHvci.IsChecked = (Get-MemoryIntegrityOn) }
        'PageHome'     { Update-Sparks }
    }
}

foreach ($nav in @($script:Pages.Keys)) {
    $ui[$nav].Add_Checked({ Show-Page $script:Pages[$this.Name] })
}

# ----------------------------------------------------------------- events
$ui.BtnMin.Add_Click({ $window.WindowState = 'Minimized' })
$ui.BtnMax.Add_Click({ if ($window.WindowState -eq 'Maximized') { $window.WindowState = 'Normal' } else { $window.WindowState = 'Maximized' } })
$ui.BtnClose.Add_Click({ if ($script:Settings.AutoBoost -and $script:TrayIcon) { Hide-ToTray } else { Exit-Rox } })
$window.Add_StateChanged({
    if ($window.WindowState -eq 'Maximized') { $ui.Root.Margin = New-Object System.Windows.Thickness(7) } else { $ui.Root.Margin = New-Object System.Windows.Thickness(0) }
    $script:Sync.Visible = ($window.WindowState -ne 'Minimized')
})
$window.Add_Closing({
    param($s, $e)
    if (-not $script:Exiting -and -not $script:TestMode) {
        $e.Cancel = $true
        if ($script:Settings.AutoBoost -and $script:TrayIcon) { Hide-ToTray } else { Exit-Rox }
    }
})
$window.Add_SizeChanged({ Update-Sparks })

$ui.ConfirmYes.Add_Click({ $ui.ModalConfirm.Visibility = 'Collapsed'; if ($script:ConfirmOnYes) { & $script:ConfirmOnYes } })
$ui.ConfirmAlt.Add_Click({ $ui.ModalConfirm.Visibility = 'Collapsed'; if ($script:ConfirmOnAlt) { & $script:ConfirmOnAlt } })
$ui.ConfirmNo.Add_Click({ $ui.ModalConfirm.Visibility = 'Collapsed' })
$ui.BtnDrawerClose.Add_Click({ Close-Drawer })

# language
$ui.LangAr.Add_Checked({ if (-not $script:LangBusy) { Set-Language 'ar' -Save } })
$ui.LangEn.Add_Checked({ if (-not $script:LangBusy) { Set-Language 'en' -Save } })
$ui.ModalLangAr.Add_Checked({ if (-not $script:LangBusy) { Set-Language 'ar' -Save } })
$ui.ModalLangEn.Add_Checked({ if (-not $script:LangBusy) { Set-Language 'en' -Save } })

# GPU
$ui.ModalAmd.Add_Click({ Set-GpuVendor 'amd' })
$ui.ModalNvidia.Add_Click({ Set-GpuVendor 'nvidia' })
$ui.ModalIntel.Add_Click({ Set-GpuVendor 'intel' })
$ui.SetAmd.Add_Click({ Set-GpuVendor 'amd' })
$ui.SetNvidia.Add_Click({ Set-GpuVendor 'nvidia' })
$ui.SetIntel.Add_Click({ Set-GpuVendor 'intel' })

# home
$ui.BtnFixAll.Add_Click({
    Show-Confirm (T 'C_FixTitle') (T 'C_FixText') (T 'C_FixAll') {
        Start-RoxJob (T 'J_FixAll') 'Invoke-UpdateAndFixAll -DeepRepair $true' -OnDone { param($r, $e) Update-State; Request-Restart }
    } (T 'C_FixQuick') {
        Start-RoxJob (T 'J_FixAll') 'Invoke-UpdateAndFixAll -DeepRepair $false' -OnDone { param($r, $e) Update-State; Request-Restart }
    }
})
$applyAll = {
    Show-Confirm (T 'C_OptTitle') (T 'C_OptText') (T 'C_OptYes') {
        Start-RoxJob (T 'J_OptAll') 'Invoke-OptimizeAll' -OnDone { param($r, $e) Update-State; Request-Restart }
    }
}
$ui.BtnApplyAllHome.Add_Click($applyAll)
$ui.BtnOptimizeAll.Add_Click($applyAll)
$ui.BtnGaming.Add_Click({ Invoke-ModuleJob 'gaming' })
$ui.BtnGpu.Add_Click({ Invoke-ModuleJob 'gpu' })
$ui.BtnPower.Add_Click({ Invoke-ModuleJob 'power' })
$ui.BtnQuickClean.Add_Click({ Invoke-FreeRam })
$ui.BtnSeeAll.Add_Click({ $ui.NavOptimize.IsChecked = $true })
$ui.BtnOpenGames.Add_Click({ $ui.NavGames.IsChecked = $true })

$moduleClick = {
    param($s, $e)
    $src = $e.OriginalSource
    if (-not ($src -is [System.Windows.FrameworkElement])) { return }
    $item = $src.DataContext
    if (-not ($item -is [RoxItem])) { return }
    switch ([string]$src.Tag) {
        'run' { Invoke-ModuleJob $item.Key }
        'fav' { Update-Favorites }
    }
}
$ui.ModulesList.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]$moduleClick)
$ui.HomeModules.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]$moduleClick)

# games
$ui.BtnRescan.Add_Click({ Find-Games })
$ui.BtnAddGame.Add_Click({ Add-ManualGame })
$ui.GamesList.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($s, $e)
    $src = $e.OriginalSource
    if (-not ($src -is [System.Windows.FrameworkElement])) { return }
    $item = $src.DataContext
    if (-not ($item -is [RoxItem])) { return }
    switch ([string]$src.Tag) {
        'opt'  { Set-GameOpt $item ([bool]$item.IsOn) }
        'play' { Invoke-PlayGame $item }
        'exe'  { [void](Select-GameExe $item) }
    }
})

function Set-AutoBoost([bool]$On) {
    $script:Settings.AutoBoost = $On
    $ui.ChkAutoBoost.IsChecked = $On
    $ui.ChkSetAuto.IsChecked = $On
    $ui.ChkHomeAuto.IsChecked = $On
    Save-RoxSettings $script:Settings
}
function Set-CloseOnStart([bool]$On) {
    $script:Settings.CloseOnGameStart = $On
    $ui.ChkCloseOnStart.IsChecked = $On
    $ui.ChkSetClose.IsChecked = $On
    Save-RoxSettings $script:Settings
}
$ui.ChkAutoBoost.Add_Click({ Set-AutoBoost ([bool]$ui.ChkAutoBoost.IsChecked) })
$ui.ChkSetAuto.Add_Click({ Set-AutoBoost ([bool]$ui.ChkSetAuto.IsChecked) })
$ui.ChkHomeAuto.Add_Click({ Set-AutoBoost ([bool]$ui.ChkHomeAuto.IsChecked) })
$ui.ChkCloseOnStart.Add_Click({ Set-CloseOnStart ([bool]$ui.ChkCloseOnStart.IsChecked) })
$ui.ChkSetClose.Add_Click({ Set-CloseOnStart ([bool]$ui.ChkSetClose.IsChecked) })

# background apps
$ui.BtnRefreshApps.Add_Click({ Update-Apps })
$ui.BtnCleanRam.Add_Click({ Invoke-FreeRam })
$ui.BtnCloseSelected.Add_Click({ Stop-Apps @($script:Apps | Where-Object { $_.IsChecked } | ForEach-Object { $_.Key }) })
$ui.BtnCloseAll.Add_Click({
    $script:PendingClose = @($script:Apps | Where-Object { -not $_.IsOn } | ForEach-Object { $_.Key })
    Show-Confirm (T 'C_CloseTitle') ((T 'C_CloseText') -f $script:PendingClose.Count) (T 'C_CloseYes') { Stop-Apps $script:PendingClose }
})
$ui.AppsList.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($s, $e)
    $src = $e.OriginalSource
    if (-not ($src -is [System.Windows.FrameworkElement])) { return }
    $item = $src.DataContext
    if (-not ($item -is [RoxItem])) { return }
    if ([string]$src.Tag -eq 'keep') {
        $n = $item.Key.ToLower()
        $keep = New-Object System.Collections.Generic.List[string]
        foreach ($k in @($script:Settings.KeepApps)) { if ($k -and ([string]$k).ToLower() -ne $n) { $keep.Add(([string]$k).ToLower()) } }
        if ($item.IsOn) { $keep.Add($n); $item.IsChecked = $false; Show-Toast ((T 'T_KeepForever') -f $item.Title) }
        $script:Settings.KeepApps = $keep.ToArray()
        Save-RoxSettings $script:Settings
    }
})

# crash doctor
$ui.BtnScanCrash.Add_Click({ Invoke-CrashScan })
$ui.BtnDeepRepair.Add_Click({
    Show-Confirm (T 'C_RepairTitle') (T 'C_RepairText') (T 'C_RepairYes') {
        Start-RoxJob (T 'J_Repair') 'Invoke-SystemRepair' -OnDone { param($r, $e) Request-Restart }
    }
})
$ui.CrashList.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($s, $e)
    $src = $e.OriginalSource
    if (-not ($src -is [System.Windows.FrameworkElement])) { return }
    $item = $src.DataContext
    if (-not ($item -is [RoxItem]) -or [string]$src.Tag -ne 'fix') { return }
    $f = $item.Tag
    Start-RoxJob ($item.ActionText) 'Invoke-RoxFix -FixId $P.Fix -Extra $P.Extra' @{ Fix = [string]$f.FixId; Extra = [string]$f.Extra } -OnDone {
        param($r, $e)
        Show-Toast (T 'T_FixDone')
    }
})

# settings
$ui.ChkSetStartup.Add_Click({
    $on = [bool]$ui.ChkSetStartup.IsChecked
    $script:Settings.StartWithWindows = $on
    Save-RoxSettings $script:Settings
    Start-RoxJob (T 'J_Startup') 'Set-RoxAutostart -On ([bool]$P.On) -ScriptPath $P.Path' @{ On = $on; Path = (Join-Path $script:AppDir 'ROX.ps1') } -Quiet -OnDone {
        param($r, $e)
        if ($e) { Show-Toast (T 'T_Failed') 'warn' } else { Show-Toast (T 'T_Done') }
    }
})
$ui.ChkSetHvci.Add_Click({
    if ($ui.ChkSetHvci.IsChecked) {
        Start-RoxJob (T 'J_HvciOn') 'Set-MemoryIntegrity -Enable $true' -Quiet -OnDone { param($r, $e) Show-Toast (T 'T_HvciOn') }
    } else {
        $ui.ChkSetHvci.IsChecked = $true
        Show-Confirm (T 'C_HvciTitle') (T 'C_HvciText') (T 'C_HvciYes') {
            $ui.ChkSetHvci.IsChecked = $false
            Start-RoxJob (T 'J_HvciOff') 'Set-MemoryIntegrity -Enable $false' -Quiet -OnDone { param($r, $e) Show-Toast (T 'T_HvciOff') }
        }
    }
})
$ui.BtnUndoAll.Add_Click({
    Show-Confirm (T 'C_UndoTitle') (T 'C_UndoText') (T 'C_UndoYes') {
        Start-RoxJob (T 'J_Undo') 'Invoke-RoxRestore' -OnDone {
            param($r, $e)
            foreach ($g in $script:GameData) { Set-GameObjectValue $g 'Optimized' $false }
            Save-Games
            Show-Games
            $script:Settings.StartWithWindows = $false
            Save-RoxSettings $script:Settings
            $ui.ChkSetStartup.IsChecked = $false
            Update-State
            Request-Restart
        }
    }
})
$ui.BtnOpenLogs.Add_Click({ Start-Process -FilePath (Join-Path $env:windir 'explorer.exe') -ArgumentList ('"{0}"' -f $script:DataDir) })

# ----------------------------------------------------------------- timer
$script:Timer = New-Object System.Windows.Threading.DispatcherTimer
$script:Timer.Interval = [TimeSpan]::FromMilliseconds(120)
$script:Timer.Add_Tick({
    try {
        $evt = $null
        $n = 0
        while ($n -lt 80 -and $script:LogQueue.TryDequeue([ref]$evt)) { Add-LogLine $evt; $n++ }
        if ($null -ne $script:Job -and $script:Job.Handle.IsCompleted) { Complete-RoxJob }
        $script:TickCount++
        if ($script:TickCount % 12 -eq 1 -and $script:Sync.Visible) { Update-Stats }
        Update-ScoreAnim
        $g = $null
        while ($script:Sync.GameEvents.TryDequeue([ref]$g)) { Invoke-GameDetected $g }
        if ($script:ShowEvent -and $script:ShowEvent.WaitOne(0)) { Show-Main }
        if ($script:ToastUntil -and (Get-Date) -gt $script:ToastUntil) { Hide-Toast }
    } catch { Write-Log "tick: $($_.Exception.Message)" }
})

# ----------------------------------------------------------------- start
$lang = [string]$script:Settings.Language
if (-not $lang) {
    if ($script:Settings.FirstRunDone -or [Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'ar' -or
        [Globalization.CultureInfo]::CurrentCulture.TwoLetterISOLanguageName -eq 'ar') { $lang = 'ar' } else { $lang = 'en' }
}
Initialize-Modules
Set-Language $lang
$ui.ChkAutoBoost.IsChecked    = [bool]$script:Settings.AutoBoost
$ui.ChkSetAuto.IsChecked      = [bool]$script:Settings.AutoBoost
$ui.ChkHomeAuto.IsChecked     = [bool]$script:Settings.AutoBoost
$ui.ChkCloseOnStart.IsChecked = [bool]$script:Settings.CloseOnGameStart
$ui.ChkSetClose.IsChecked     = [bool]$script:Settings.CloseOnGameStart
$ui.ChkSetStartup.IsChecked   = [bool]$script:Settings.StartWithWindows
foreach ($g in @(Get-RoxGames)) { if ($g -and $g.Id) { [void]$script:GameData.Add($g) } }
Show-Games
Set-ScoreRing 0
$script:Timer.Start()
Update-State
Find-Games -Quiet

# ----------------------------------------------------------------- render test (CI screenshots)
function Invoke-Pump([int]$Times = 1) {
    for ($i = 0; $i -lt $Times; $i++) {
        $frame = New-Object System.Windows.Threading.DispatcherFrame
        [void][System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
            [System.Windows.Threading.DispatcherPriority]::Background,
            [System.Windows.Threading.DispatcherOperationCallback]{ param($f) $f.Continue = $false; return $null }, $frame)
        [System.Windows.Threading.Dispatcher]::PushFrame($frame)
        Start-Sleep -Milliseconds 30
    }
}

function Save-Png($Visual, [int]$W, [int]$H, [string]$Name) {
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($W, $H, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($Visual)
    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $path = Join-Path $RenderTest "$Name.png"
    $fs = [IO.File]::Create($path)
    $enc.Save($fs)
    $fs.Close()
    Write-Host "shot: $path ($W x $H)"
}

function Save-Shot([string]$Name) {
    Invoke-Pump 8
    $root = $ui.Root
    $w = [int][math]::Max(1, $root.ActualWidth)
    $h = [int][math]::Max(1, $root.ActualHeight)
    # Paint the window background and re-apply the right-to-left mirror Windows applies to the window.
    $dv = New-Object System.Windows.Media.DrawingVisual
    $dc = $dv.RenderOpen()
    $full = New-Object System.Windows.Rect(0, 0, $w, $h)
    $dc.DrawRectangle($window.Background, $null, $full)
    $vb = New-Object System.Windows.Media.VisualBrush($root)
    $vb.ViewboxUnits = [System.Windows.Media.BrushMappingMode]::Absolute
    $vb.Viewbox = $full
    $vb.Stretch = [System.Windows.Media.Stretch]::Fill
    $rtl = ($window.FlowDirection -eq [System.Windows.FlowDirection]::RightToLeft)
    if ($rtl) { $dc.PushTransform((New-Object System.Windows.Media.MatrixTransform(-1.0, 0.0, 0.0, 1.0, [double]$w, 0.0))) }
    $dc.DrawRectangle($vb, $null, $full)
    if ($rtl) { $dc.Pop() }
    $dc.Close()
    Save-Png $dv $w $h $Name
}

if ($RenderTest) {
    New-Item -ItemType Directory -Path $RenderTest -Force | Out-Null
    $window.WindowStartupLocation = 'Manual'
    $window.Left = 0; $window.Top = 0; $window.Width = 1366; $window.Height = 860
    $window.ShowActivated = $false
    try { $window.Show() } catch { Write-Host "Show failed: $($_.Exception.Message)" }
    Update-Apps
    Invoke-CrashScan
    $deadline = (Get-Date).AddSeconds(240)
    while (((Get-Date) -lt $deadline) -and ($null -ne $script:Job -or $script:JobQueue.Count -gt 0)) { Invoke-Pump 5 }
    Write-Host ("jobs finished: score={0} games={1} apps={2} crashes={3}" -f $script:ScoreTarget, $script:GameData.Count, $script:Apps.Count, $script:Crashes.Count)

    # icon preview: dark + light background, several sizes
    $strip = New-Object System.Windows.Controls.StackPanel
    $strip.Orientation = 'Horizontal'
    foreach ($bg in @('#FF06060B', '#FFF3F3F3')) {
        foreach ($s in @(256, 64, 32, 16)) {
            $cell = New-Object System.Windows.Controls.Border
            $cell.Width = 272; $cell.Height = 272
            $cell.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($bg)
            $vb2 = New-Object System.Windows.Controls.Viewbox
            $vb2.Width = $s; $vb2.Height = $s
            $vb2.Child = New-LogoElement
            $cell.Child = $vb2
            [void]$strip.Children.Add($cell)
        }
    }
    $strip.Measure((New-Object System.Windows.Size(2176, 272)))
    $strip.Arrange((New-Object System.Windows.Rect(0, 0, 2176, 272)))
    $strip.UpdateLayout()
    Save-Png $strip 2176 272 '00-icon'

    $script:ScoreTarget = [math]::Max($script:ScoreTarget, 72)
    $script:ScoreShown = $script:ScoreTarget
    Update-ScoreAnim
    Update-HeroText
    $rnd = New-Object System.Random(7)
    for ($i = 0; $i -lt 40; $i++) {
        Add-Hist 'cpu' (18 + 22 * [math]::Abs([math]::Sin($i / 4.0)) + $rnd.Next(0, 8))
        Add-Hist 'gpu' (40 + 35 * [math]::Abs([math]::Sin($i / 6.0 + 1)) + $rnd.Next(0, 6))
        Add-Hist 'ram' (38 + $i / 4.0 + $rnd.Next(0, 3))
        Add-Hist 'proc' (150 - $i + $rnd.Next(0, 6))
    }
    $script:Sync.Stop = $true
    $ui.CpuText.Text = '27%'; $ui.GpuText.Text = '68%'; $ui.RamText.Text = '6.4 / 16 GB'; $ui.ProcText.Text = '112'
    $script:LastBoost = 'VALORANT'
    if ($script:Games.Count -eq 0) {
        foreach ($d in @(@('VALORANT', 'Riot', $true), @('Counter-Strike 2', 'Steam', $true), @('Fortnite', 'Epic', $false), @('Call of Duty', 'Steam', $false), @('Minecraft', 'Manual', $false))) {
            [void]$script:GameData.Add([pscustomobject]@{ Id = 'demo:' + $d[0]; Name = $d[0]; Source = $d[1]; Exe = ('C:\Games\{0}.exe' -f $d[0].Replace(' ', '')); Optimized = $d[2]; Image = $null })
        }
        Show-Games
    }
    if ($script:Apps.Count -lt 3) {
        Show-Apps @(
            [pscustomobject]@{ ProcessName = 'chrome'; Name = 'Google Chrome'; Company = 'Google LLC'; Category = 'browser'; RamMB = 1840; Keep = $false; DefaultClose = $false },
            [pscustomobject]@{ ProcessName = 'Spotify'; Name = 'Spotify'; Company = 'Spotify AB'; Category = 'app'; RamMB = 410; Keep = $false; DefaultClose = $true },
            [pscustomobject]@{ ProcessName = 'Discord'; Name = 'Discord'; Company = 'Discord Inc.'; Category = 'chat'; RamMB = 512; Keep = $true; DefaultClose = $false },
            [pscustomobject]@{ ProcessName = 'steamwebhelper'; Name = 'Steam Client WebHelper'; Company = 'Valve'; Category = 'launcher'; RamMB = 430; Keep = $false; DefaultClose = $false }
        )
    }
    if ($script:Crashes.Count -eq 0) {
        Show-Crashes @(
            [pscustomobject]@{ Cause = 'gpu-nvidia'; App = 'FortniteClient-Win64-Shipping.exe'; Module = 'nvwgf2umx.dll'; Code = 'c0000005'; Count = 3; Last = (Get-Date).AddHours(-5); FixId = 'gpu'; Extra = '' },
            [pscustomobject]@{ Cause = 'runtime-vc'; App = 'cod.exe'; Module = 'MSVCP140.dll'; Code = 'c0000409'; Count = 1; Last = (Get-Date).AddDays(-2); FixId = 'runtimes'; Extra = '' },
            [pscustomobject]@{ Cause = 'tdr'; App = ''; Module = ''; Code = ''; Count = 2; Last = (Get-Date).AddDays(-3); FixId = 'gpu'; Extra = '' }
        )
    }
    Update-WatchText
    $shots = {
        param($Suffix)
        $ui.NavHome.IsChecked = $true; Show-Page 'PageHome'; Invoke-Pump 3; Update-Sparks; Save-Shot ('01-home' + $Suffix)
        $ui.NavOptimize.IsChecked = $true; Save-Shot ('02-optimize' + $Suffix)
        $ui.NavGames.IsChecked = $true;    Save-Shot ('03-games' + $Suffix)
        $ui.NavApps.IsChecked = $true
        $deadline = (Get-Date).AddSeconds(60)
        while (((Get-Date) -lt $deadline) -and ($null -ne $script:Job -or $script:JobQueue.Count -gt 0)) { Invoke-Pump 5 }
        if ($script:Apps.Count -lt 3) {
            Show-Apps @(
                [pscustomobject]@{ ProcessName = 'chrome'; Name = 'Google Chrome'; Company = 'Google LLC'; Category = 'browser'; RamMB = 1840; Keep = $false; DefaultClose = $false },
                [pscustomobject]@{ ProcessName = 'Spotify'; Name = 'Spotify'; Company = 'Spotify AB'; Category = 'app'; RamMB = 410; Keep = $false; DefaultClose = $true }
            )
        }
        Save-Shot ('04-apps' + $Suffix)
        $ui.NavCrash.IsChecked = $true;    Save-Shot ('05-crash' + $Suffix)
        $ui.NavSettings.IsChecked = $true; Save-Shot ('06-settings' + $Suffix)
        $ui.NavHome.IsChecked = $true
    }
    & $shots ''
    Show-GpuModal;            Save-Shot '07-welcome'
    $ui.ModalGpu.Visibility = 'Collapsed'
    Open-Drawer (T 'J_FixAll')
    foreach ($t in @(@('step', 'Power: maximum-performance plan'), @('ok', 'ROX power plan active: CPU at full speed + Turbo'), @('step', 'Games: Game Mode ON'), @('warn', 'Could not install NVIDIA app automatically'), @('info', 'Found GPU: NVIDIA GeForce RTX 4070'))) {
        Add-LogLine ([pscustomobject]@{ Kind = $t[0]; Text = $t[1] })
    }
    Save-Shot '08-drawer'
    Close-Drawer
    $ui.BtnFixAll.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    Save-Shot '09-confirm'
    $ui.ModalConfirm.Visibility = 'Collapsed'
    Set-Language 'en'
    & $shots '-en'
    Show-GpuModal; Save-Shot '07-welcome-en'
    $ui.ModalGpu.Visibility = 'Collapsed'
    Set-Language 'ar'
    Show-GameToast ((T 'G_Title') -f 'VALORANT') ((T 'G_Line') -f 6, 1240)
    Invoke-Pump 5
    $seen = @{}
    foreach ($er in @($Error)) {
        $msg = '{0} @ {1}' -f $er.Exception.Message, $er.InvocationInfo.PositionMessage
        if ($seen.ContainsKey($msg) -or $msg -match 'No events were found|Cannot find path|does not exist|Cannot find a process') { continue }
        $seen[$msg] = $true
        Write-Host ('UI-ERROR: ' + ($msg -replace '\s+', ' '))
    }
    Write-Host 'RENDER OK'
    $window.Close()
    exit 0
}

# ----------------------------------------------------------------- run
Install-RoxCopy
$script:TrayIcon = New-TrayIcon
Update-TrayTexts
if (-not $Tray) {
    $window.Show()
    if (-not $script:Settings.FirstRunDone) { Show-GpuModal }
} else {
    $script:Sync.Visible = $false
}
[void]$script:App.Run()
$script:Sync.Stop = $true
try { $script:Pool.Close() } catch { }
