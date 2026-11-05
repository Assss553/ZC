<#
================================================================================
  ROX  -  gaming optimizer for Windows 10 / 11
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

$script:Here       = Split-Path -Parent $PSCommandPath
$script:EnginePath = Join-Path $script:Here 'RoxEngine.ps1'
$script:XamlPath   = Join-Path $script:Here 'ROX.xaml'
$script:TestMode   = [bool]($RenderTest -or $SelfTest)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml, System.Windows.Forms, System.Drawing

# ----------------------------------------------------------------- administrator
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ($script:TestMode) { Write-Host 'ROX tests need administrator rights'; exit 2 }
    $a = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f $PSCommandPath
    if ($Tray) { $a += ' -Tray' }
    try { Start-Process -FilePath 'powershell.exe' -ArgumentList $a -Verb RunAs -ErrorAction Stop }
    catch { [void][System.Windows.Forms.MessageBox]::Show('ROX يحتاج صلاحيات المسؤول. اضغط "نعم" لما يطلبها ويندوز.', 'ROX') }
    exit
}

. $script:EnginePath

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

# ----------------------------------------------------------------- bindable item + console helper
if (-not ('RoxItem' -as [type])) {
    Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

public class RoxItem : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler PropertyChanged;
    private void Notify(string name) { PropertyChangedEventHandler h = PropertyChanged; if (h != null) h(this, new PropertyChangedEventArgs(name)); }
    private string _key, _title, _subtitle, _detail, _badge, _icon, _accent, _image, _initial, _actionText;
    private bool _isChecked, _isOn, _hasBadge, _hasAction;
    private object _tag;
    public string Key        { get { return _key; }        set { _key = value; Notify("Key"); } }
    public string Title      { get { return _title; }      set { _title = value; Notify("Title"); } }
    public string Subtitle   { get { return _subtitle; }   set { _subtitle = value; Notify("Subtitle"); } }
    public string Detail     { get { return _detail; }     set { _detail = value; Notify("Detail"); } }
    public string Badge      { get { return _badge; }      set { _badge = value; Notify("Badge"); } }
    public string Icon       { get { return _icon; }       set { _icon = value; Notify("Icon"); } }
    public string Accent     { get { return _accent; }     set { _accent = value; Notify("Accent"); } }
    public string Image      { get { return _image; }      set { _image = value; Notify("Image"); } }
    public string Initial    { get { return _initial; }    set { _initial = value; Notify("Initial"); } }
    public string ActionText { get { return _actionText; } set { _actionText = value; Notify("ActionText"); } }
    public bool IsChecked    { get { return _isChecked; }  set { _isChecked = value; Notify("IsChecked"); } }
    public bool IsOn         { get { return _isOn; }       set { _isOn = value; Notify("IsOn"); } }
    public bool HasBadge     { get { return _hasBadge; }   set { _hasBadge = value; Notify("HasBadge"); } }
    public bool HasAction    { get { return _hasAction; }  set { _hasAction = value; Notify("HasAction"); } }
    public object Tag        { get { return _tag; }        set { _tag = value; Notify("Tag"); } }
}

public static class RoxWin
{
    [DllImport("kernel32.dll")] private static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr hWnd, int cmd);
    public static void HideConsole() { IntPtr h = GetConsoleWindow(); if (h != IntPtr.Zero) ShowWindow(h, 0); }
}
'@
}

function New-RoxItem([hashtable]$P) {
    $i = New-Object RoxItem
    foreach ($k in $P.Keys) { $i.$k = $P[$k] }
    return $i
}

# The comma keeps PowerShell from unrolling the (empty) collection into `$null.
function New-ItemList { return , (New-Object 'System.Collections.ObjectModel.ObservableCollection[RoxItem]') }

# ----------------------------------------------------------------- Arabic text
$script:ModuleDefs = @(
    @{ Key = 'win';     Title = 'تحسين الويندوز';     Sub = 'يقفل الخدمات والتتبع والمهام اللي تشتغل بالخلفية';      Icon = [string][char]0xE770; Check = 'telemetry' },
    @{ Key = 'gaming';  Title = 'تحسين الألعاب';      Sub = 'Game Mode، إيقاف تسجيل الخلفية، أولوية أعلى للعبة';     Icon = [string][char]0xE7FC; Check = 'gamemode' },
    @{ Key = 'gpu';     Title = 'إعدادات الكرت';      Sub = 'جدولة الكرت، تحسين النوافذ، تحديث التعريف تلقائي';      Icon = [string][char]0xE7F4; Check = 'hags' },
    @{ Key = 'power';   Title = 'الطاقة والمعالج';    Sub = 'خطة أداء أقصى + Turbo + أنوية P و E لمعالجات Intel';     Icon = [string][char]0xE945; Check = 'plan' },
    @{ Key = 'cleanup'; Title = 'التنظيف';            Sub = 'يمسح الملفات المؤقتة وكاش التحديثات';                    Icon = [string][char]0xE74D; Check = 'temp' },
    @{ Key = 'network'; Title = 'تحسين الشبكة';       Sub = 'بنق أقل ولاق أقل في الأونلاين';                          Icon = [string][char]0xE701; Check = 'network' },
    @{ Key = 'input';   Title = 'الكيبورد والماوس';    Sub = 'تصويب 1:1، أزرار أسرع، بدون نافذة Sticky Keys';          Icon = [string][char]0xE765; Check = 'input' },
    @{ Key = 'startup'; Title = 'برامج بدء التشغيل';   Sub = 'البرامج الثقيلة ما تشتغل مع الويندوز';                  Icon = [string][char]0xE7E8; Check = 'startup' },
    @{ Key = 'ram';     Title = 'الرامات والعمليات';   Sub = 'عمليات أقل، و Widgets و Edge ما يشتغلون بالخلفية';      Icon = [string][char]0xE9D9; Check = 'svchost' }
)

$script:CauseText = @{
    'gpu-nvidia'  = @('كراش من تعريف كرت NVIDIA', 'اللعبة طاحت داخل تعريف الكرت. الأسباب: تعريف قديم أو خربان، أو كسر سرعة (Overclock) للكرت، أو حرارة عالية.')
    'gpu-amd'     = @('كراش من تعريف كرت AMD', 'اللعبة طاحت داخل تعريف الكرت. الأسباب: تعريف قديم أو خربان، أو كسر سرعة (Overclock) للكرت، أو حرارة عالية.')
    'gpu-intel'   = @('كراش من تعريف كرت Intel', 'اللعبة طاحت داخل تعريف كرت Intel. حدّث التعريف من Intel، ولكروت Arc تأكد إن Resizable BAR شغّال.')
    'gpu-generic' = @('كراش في DirectX / الكرت', 'المشكلة في طبقة الرسوميات. غالباً التعريف، أو إعدادات رسوم عالية، أو Overclock.')
    'tdr'         = @('الكرت وقف عن الاستجابة (TDR)', 'الشاشة تسود وترجع أو اللعبة تقفل فجأة. ROX يعطي الكرت وقت أكثر قبل ما ويندوز يعيد تشغيله، ويحدّث التعريف.')
    'runtime-vc'  = @('ملفات Visual C++ ناقصة أو خربانة', 'اللعبة تحتاج ملفات تشغيل من مايكروسوفت. ROX يثبّتها ويصلّحها لك.')
    'runtime-dx'  = @('ملفات DirectX القديمة ناقصة', 'ألعاب كثيرة تحتاج DirectX 9 / 10 / 11 القديم. ROX يثبّته لك.')
    'runtime-net' = @('مشكلة في .NET', 'اللعبة أو اللانشر يحتاج .NET. ROX يثبّت ملفات التشغيل الناقصة.')
    'missing-dll' = @('ملف DLL ناقص', 'اللعبة ما لقت ملف تحتاجه، غالباً من ملفات التشغيل (Visual C++ / DirectX).')
    'overlay'     = @('برنامج Overlay يسبب الكراش', 'برامج تطلع فوق اللعبة (Discord / Steam Overlay / MSI Afterburner / OBS) سببت الكراش. قفّل الـ Overlay حقها وجرّب.')
    'anticheat'   = @('مشكلة في الأنتي تشيت', 'الأنتي تشيت (EasyAntiCheat / BattlEye / Vanguard) طاح. افحص ملفات اللعبة وأعد تثبيت الأنتي تشيت من مجلد اللعبة.')
    'game-files'  = @('ملفات اللعبة فيها مشكلة', 'اللعبة طاحت من نفسها. افحص ملفات اللعبة، وحدّث التعريف، ونزّل الإعدادات شوي.')
    'hang'        = @('اللعبة علّقت (Not responding)', 'اللعبة وقفت تستجيب. غالباً الرام أو الديسك أو برامج الخلفية. ROX يفضّي الرام ويقفل الخلفية.')
    'memory'      = @('الذاكرة خلصت', 'الرام والذاكرة الافتراضية ما كفت. ROX يخلي ويندوز يدير ملف الصفحات (Page file) تلقائي.')
    'low-memory'  = @('ويندوز حذّر إن الذاكرة قربت تخلص', 'ROX يخلي ويندوز يدير ملف الصفحات تلقائي عشان ما تطيح الألعاب.')
    'bsod-gpu'    = @('شاشة زرقا بسبب الكرت', 'ويندوز طاح بسبب تعريف الكرت. ROX يحدّث التعريف ويعطي الكرت وقت أكثر.')
    'bsod-hw'     = @('شاشة زرقا: عدم ثبات في المعالج', 'غالباً Overclock أو XMP مو ثابت، أو حرارة، أو BIOS قديم (مهم لمعالجات Intel الجيل 13 و 14). حدّث البايوس.')
    'bsod-ram'    = @('شاشة زرقا: مشكلة في الرام', 'ممكن الرام أو XMP. ROX يفتح فحص الذاكرة من ويندوز (يحتاج ريستارت).')
    'bsod-driver' = @('شاشة زرقا: تعريف خربان', 'تعريف في الجهاز سبب الطيحة. ROX يفحص ويصلّح ملفات ويندوز.')
    'bsod-system' = @('شاشة زرقا', 'ويندوز طاح. ROX يفحص ويصلّح ملفات النظام (SFC + DISM).')
    'power'       = @('الجهاز طفى فجأة', 'بدون شاشة زرقا: غالباً الباور سبلاي أو الحرارة أو الكهرباء. نظّف المراوح وتأكد من الباور.')
    'whea'        = @('أخطاء هاردوير (WHEA)', 'المعالج أو الرام أعطوا أخطاء. غالباً Overclock أو XMP مو ثابت أو حرارة، أو BIOS قديم لمعالجات Intel 13 و 14.')
    'disk'        = @('أخطاء في الهارديسك / SSD', 'القرص يعطي أخطاء قراءة وكتابة وهذا يسبب تعليق. ROX يفحص القرص. خذ نسخة من ملفاتك المهمة.')
    'unknown'     = @('كراش سببه مو واضح', 'ROX يثبّت ملفات التشغيل الناقصة. إذا استمر: افحص ملفات اللعبة وحدّث التعريف.')
}
$script:FixText = @{
    gpu = 'صلّح الكرت'; runtimes = 'ثبّت الملفات الناقصة'; pagefile = 'صلّح الذاكرة'; verify = 'افحص ملفات اللعبة'
    sfc = 'صلّح ويندوز'; memtest = 'افحص الرام'; boost = 'فضّي الرام'; disk = 'افحص القرص'
}
$script:CatText  = @{ app = 'برنامج'; launcher = 'لانشر'; chat = 'تواصل'; browser = 'متصفح'; tool = 'أداة بث / FPS' }
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
$script:NoAnim    = [bool]$RenderTest
$script:ScoreTarget = 0.0
$script:ScoreShown  = 0.0
$script:ToastUntil  = $null
$script:TickCount   = 0
$script:Exiting     = $false
$script:CrashScanned = $false

$ui.HomeModules.ItemsSource = $script:HomeMods
$ui.ModulesList.ItemsSource = $script:Modules
$ui.GamesList.ItemsSource   = $script:Games
$ui.AppsList.ItemsSource    = $script:Apps
$ui.CrashList.ItemsSource   = $script:Crashes
$ui.DrawerLog.ItemsSource   = $script:Logs

$ui.DateText.Text    = (Get-Date).ToString('dd MMMM yyyy', [Globalization.CultureInfo]::GetCultureInfo('ar-AE'))
$ui.VersionText.Text = "ROX v$script:RoxVersion  •  $script:DataDir"

# ----------------------------------------------------------------- icon (drawn, no image files needed)
function New-RoxIcon {
    $png = Join-Path $script:DataDir 'rox.png'
    $ico = Join-Path $script:DataDir 'rox.ico'
    if ((Test-Path -LiteralPath $png) -and (Test-Path -LiteralPath $ico)) { return $png }
    try {
        $dv = New-Object System.Windows.Media.DrawingVisual
        $dc = $dv.RenderOpen()
        $grad = New-Object System.Windows.Media.LinearGradientBrush(
            [System.Windows.Media.Color]::FromRgb(0x8B, 0x5C, 0xF6), [System.Windows.Media.Color]::FromRgb(0x22, 0xD3, 0xEE), 45.0)
        $dc.DrawRoundedRectangle($grad, $null, (New-Object System.Windows.Rect(8, 8, 240, 240)), 60, 60)
        $tf = New-Object System.Windows.Media.Typeface('Segoe UI Black')
        $ft = New-Object System.Windows.Media.FormattedText('R', [Globalization.CultureInfo]::InvariantCulture,
                  [System.Windows.FlowDirection]::LeftToRight, $tf, 168.0, [System.Windows.Media.Brushes]::White)
        $dc.DrawText($ft, (New-Object System.Windows.Point(((256 - $ft.Width) / 2), ((256 - $ft.Height) / 2 - 6))))
        $dc.Close()
        $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(256, 256, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
        $rtb.Render($dv)
        $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
        $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
        $ms = New-Object System.IO.MemoryStream
        $enc.Save($ms)
        $bytes = $ms.ToArray()
        [IO.File]::WriteAllBytes($png, $bytes)
        $fs = [IO.File]::Create($ico)
        $bw = New-Object System.IO.BinaryWriter($fs)
        $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)
        $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$bytes.Length); $bw.Write([uint32]22)
        $bw.Write($bytes)
        $bw.Close()
    } catch { Write-Log "icon: $($_.Exception.Message)" }
    return $png
}

$script:IconPng = New-RoxIcon
try { $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create((New-Object System.Uri($script:IconPng))) } catch { }

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

function Set-Bar($Fill, [double]$Percent) {
    $v = [math]::Max(0.0, [math]::Min(1.0, $Percent / 100.0))
    if ($script:NoAnim) { $Fill.RenderTransform.ScaleX = $v; return }
    $a = New-Object System.Windows.Media.Animation.DoubleAnimation($v, (New-Dur 600))
    $a.EasingFunction = New-Ease
    $Fill.RenderTransform.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $a)
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

function Hide-Toast {
    $script:ToastUntil = $null
    $ui.Toast.Visibility = 'Collapsed'
}

function Open-Drawer([string]$Title) {
    $script:Logs.Clear()
    $ui.DrawerTitle.Text = $Title
    $ui.DrawerStatus.Text = 'يبدأ...'
    $ui.DrawerSpinner.Visibility = 'Visible'
    $ui.DrawerDone.Visibility = 'Collapsed'
    $ui.Drawer.Visibility = 'Visible'
    if (-not $script:NoAnim) {
        $a = New-Object System.Windows.Media.Animation.DoubleAnimation(280.0, 0.0, (New-Dur 380))
        $a.EasingFunction = New-Ease
        $ui.Drawer.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $a)
    }
}

function Close-Drawer {
    $ui.Drawer.Visibility = 'Collapsed'
}

function Complete-Drawer([bool]$Ok) {
    $ui.DrawerSpinner.Visibility = 'Collapsed'
    $ui.DrawerDone.Visibility = 'Visible'
    if ($Ok) { $ui.DrawerStatus.Text = 'خلصنا ✓' } else { $ui.DrawerStatus.Text = 'خلص مع ملاحظات - شوف السجل' }
}

function Add-LogLine($Evt) {
    $color = '#FF9A9AB0'
    switch ([string]$Evt.Kind) {
        'step' { $color = '#FFB794FF' }
        'ok'   { $color = '#FF2BEBA6' }
        'warn' { $color = '#FFFFD766' }
        'skip' { $color = '#FF5D5D78' }
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
    $script:ConfirmOnYes = $OnYes
    $script:ConfirmOnAlt = $OnAlt
    if ($AltText) { $ui.ConfirmAlt.Content = $AltText; $ui.ConfirmAlt.Visibility = 'Visible' } else { $ui.ConfirmAlt.Visibility = 'Collapsed' }
    $ui.ModalConfirm.Visibility = 'Visible'
    Start-FadeIn $ui.ModalConfirm -FromY 0
}

function Request-Restart {
    Show-Confirm 'ريستارت الجهاز؟' 'بعض التحسينات تشتغل بعد إعادة التشغيل. احفظ شغلك قبل.' 'ريستارت الحين' { Restart-Computer -Force } '' $null
    $ui.ConfirmNo.Content = 'بعدين'
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
    if ($s.Cpu -ge 0) { $ui.CpuText.Text = '{0}%' -f $s.Cpu; Set-Bar $ui.CpuFill $s.Cpu }
    if ($s.Gpu -ge 0) { $ui.GpuText.Text = '{0}%' -f $s.Gpu; Set-Bar $ui.GpuFill $s.Gpu }
    if ($s.RamTotal -gt 0) {
        $ui.RamText.Text = '{0:N1} / {1:N0} GB' -f ($s.RamUsed / 1024), ($s.RamTotal / 1024)
        Set-Bar $ui.RamFill (100.0 * $s.RamUsed / $s.RamTotal)
    }
    if ($s.Procs -gt 0) { $ui.ProcText.Text = [string]$s.Procs; Set-Bar $ui.ProcFill ([math]::Min(100, $s.Procs / 3.5)) }
}

function Update-ScoreAnim {
    $d = $script:ScoreTarget - $script:ScoreShown
    if ([math]::Abs($d) -lt 0.4) {
        if ($script:ScoreShown -ne $script:ScoreTarget) { $script:ScoreShown = $script:ScoreTarget } else { return }
    } else {
        $script:ScoreShown += $d * 0.14
    }
    $ui.ScoreText.Text = '{0:N0}%' -f $script:ScoreShown
    $ui.ScoreFill.RenderTransform.ScaleX = [math]::Max(0, [math]::Min(1, $script:ScoreShown / 100))
}

# ----------------------------------------------------------------- state / modules
function Initialize-Modules {
    $script:Modules.Clear()
    foreach ($d in $script:ModuleDefs) {
        $fav = @($script:Settings.Favorites) -contains $d.Key
        $script:Modules.Add((New-RoxItem @{ Key = $d.Key; Title = $d.Title; Subtitle = $d.Sub; Icon = $d.Icon; IsOn = $fav; Badge = 'مفعّل'; HasBadge = $false; Tag = $d.Check }))
    }
    Update-HomeModules
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
    Start-RoxJob 'تحديث حالة الجهاز' 'Get-SystemState' -Quiet -OnDone {
        param($r, $e)
        $st = $r | Select-Object -Last 1
        if (-not $st) { return }
        $script:ScoreTarget = [double]$st.Score
        foreach ($m in $script:Modules) { $m.HasBadge = [bool]$st.Checks.($m.Tag) }
        $gpu = @($st.Gpus) | Where-Object { $_ } | Select-Object -First 1
        if ($gpu) { $ui.GpuCardSub.Text = $gpu }
    }
}

function Invoke-ModuleJob([string]$Key, [string]$Title) {
    Start-RoxJob ('تطبيق: ' + $Title) 'Invoke-RoxModule -Id $P.Id' @{ Id = $Key } -OnDone {
        param($r, $e)
        Show-Toast 'تم التطبيق ✓'
        Update-State
    }
}

# ----------------------------------------------------------------- games
function ConvertTo-GameItem($G) {
    $img = $null
    if ($G.Image -and (Test-Path -LiteralPath ([string]$G.Image))) { $img = [string]$G.Image }
    $badge = [string]$G.Source
    if ($badge -eq 'Manual') { $badge = 'يدوي' }
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
}

function Save-Games { Save-RoxGames @($script:GameData) }

function Find-Games([switch]$Quiet) {
    Start-RoxJob 'البحث عن الألعاب' 'Find-InstalledGames' -Quiet:$Quiet -OnDone {
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
    $dlg.Filter = 'اللعبة (*.exe)|*.exe'
    $dlg.Title = 'اختار ملف اللعبة نفسها (مو اللانشر)'
    if ($g.InstallDir -and (Test-Path -LiteralPath ([string]$g.InstallDir))) { $dlg.InitialDirectory = [string]$g.InstallDir }
    if ($dlg.ShowDialog($window) -ne $true) { return $false }
    $old = [string]$g.Exe
    if ($old -and $g.Optimized -and $old -ne $dlg.FileName) {
        Start-RoxJob 'إلغاء التسريع القديم' 'Set-GameOptimization -Exe $P.Exe -On $false' @{ Exe = $old } -Quiet
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
    Start-RoxJob ('تسريع ' + $g.Name) 'Set-GameOptimization -Exe $P.Exe -On ([bool]$P.On)' @{ Exe = [string]$g.Exe; On = $On } -Quiet -Ctx @{ G = $g; Item = $Item; On = $On } -OnDone {
        param($r, $e, $c)
        Set-GameObjectValue $c.G 'Optimized' ([bool]$c.On)
        $c.Item.IsOn = [bool]$c.On
        Save-Games
        Update-GameWatch
        if ($c.On) { Show-Toast ('{0}: مُسرّعة ✓ - ROX بيسرّعها كل ما تفتحها' -f $c.G.Name) } else { Show-Toast ('{0}: رجعت عادي' -f $c.G.Name) }
    }
}

function Invoke-PlayGame($Item) {
    $g = $Item.Tag
    $close = [bool]$script:Settings.CloseOnGameStart
    Start-RoxJob ('تجهيز ' + $g.Name) '$r = Invoke-GameBoost -ProcessId 0 -CloseApps ([bool]$P.Close); Start-RoxGame $P.Game; $r' @{ Close = $close; Game = $g } -Quiet -Ctx @{ Name = [string]$g.Name } -OnDone {
        param($r, $e, $c)
        $res = $r | Where-Object { $_ -and $_.PSObject.Properties.Name -contains 'FreedMB' } | Select-Object -Last 1
        if ($res) { Show-Toast ('يلا! {0} - قفلت {1} برامج وفضّيت {2:N0} MB' -f $c.Name, $res.Closed, $res.FreedMB) }
        else { Show-Toast ('يلا! {0}' -f $c.Name) }
    }
}

function Add-ManualGame {
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'اللعبة (*.exe)|*.exe'
    $dlg.Title = 'اختار ملف اللعبة (.exe)'
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
    foreach ($x in $script:GameData) { if ($x.Id -eq $g.Id) { Show-Toast 'اللعبة موجودة من قبل' 'warn'; return } }
    [void]$script:GameData.Add($g)
    Save-Games
    Show-Games
    foreach ($it in $script:Games) { if ($it.Key -eq $g.Id) { $it.IsOn = $true; Set-GameOpt $it $true } }
}

function Invoke-GameDetected($Evt) {
    if (-not $script:Settings.AutoBoost) { return }
    $name = $script:GameByExe[[string]$Evt.Name]
    if (-not $name) { $name = [string]$Evt.Name }
    $ui.LiveChip.Text = 'تسريع: ' + $name
    Start-RoxJob ('تسريع ' + $name) 'Invoke-GameBoost -ProcessId ([int]$P.Pid) -CloseApps ([bool]$P.Close)' @{ Pid = [int]$Evt.Pid; Close = [bool]$script:Settings.CloseOnGameStart } -Quiet -Ctx @{ Name = $name } -OnDone {
        param($r, $e, $c)
        $res = $r | Where-Object { $_ -and $_.PSObject.Properties.Name -contains 'FreedMB' } | Select-Object -Last 1
        $line = 'أولوية عالية للعبة'
        if ($res) { $line = 'قفلت {0} برامج  •  فضّيت {1:N0} MB  •  أولوية عالية' -f $res.Closed, $res.FreedMB }
        Show-GameToast ('ROX سرّع ' + $c.Name) $line
    }
}

# Small notification in the corner that does not steal focus from the game.
function Show-GameToast([string]$Title, [string]$Line) {
    try {
        $x = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent" Topmost="True" ShowInTaskbar="False"
        SizeToContent="WidthAndHeight" ShowActivated="False" ResizeMode="NoResize" FlowDirection="RightToLeft"
        FontFamily="Segoe UI Variable Text, Segoe UI">
  <Border CornerRadius="20" Background="#F2101019" BorderBrush="#772BEBA6" BorderThickness="1" Padding="18,14" Margin="14">
    <StackPanel Orientation="Horizontal">
      <Border Width="44" Height="44" CornerRadius="14">
        <Border.Background>
          <LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#FF8B5CF6" Offset="0"/><GradientStop Color="#FF22D3EE" Offset="1"/></LinearGradientBrush>
        </Border.Background>
        <TextBlock Text="R" FontSize="24" FontWeight="Black" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
      </Border>
      <StackPanel Margin="14,0,4,0" VerticalAlignment="Center">
        <TextBlock Name="T1" FontSize="15" FontWeight="Bold" Foreground="White"/>
        <TextBlock Name="T2" FontSize="12" Foreground="#FFB9F5DC" Margin="0,3,0,0"/>
      </StackPanel>
    </StackPanel>
  </Border>
</Window>
'@
        $w = [Windows.Markup.XamlReader]::Parse($x)
        $w.FindName('T1').Text = $Title
        $w.FindName('T2').Text = $Line
        $w.Left = -4000
        $w.Top = -4000
        $w.Show()
        $w.UpdateLayout()
        $wa = [System.Windows.SystemParameters]::WorkArea
        $w.Left = $wa.Right - $w.ActualWidth - 10
        $w.Top  = $wa.Bottom - $w.ActualHeight - 10
        $t = New-Object System.Windows.Threading.DispatcherTimer
        $t.Interval = [TimeSpan]::FromSeconds(5)
        $t.Add_Tick({ $t.Stop(); $w.Close() }.GetNewClosure())
        $t.Start()
    } catch { Write-Log "game toast: $($_.Exception.Message)" }
}

# ----------------------------------------------------------------- background apps
function Update-Apps {
    Start-RoxJob 'قائمة برامج الخلفية' 'Get-BackgroundApps' -Quiet -OnDone { param($r, $e) Show-Apps $r }
}

function Show-Apps($List) {
    $script:Apps.Clear()
    $total = 0.0
    foreach ($a in @($List)) {
        if (-not $a -or -not $a.ProcessName) { continue }
        $sub = '{0}.exe' -f $a.ProcessName
        if ($a.Company) { $sub += '  •  ' + $a.Company }
        $cat = [string]$a.Category
        $script:Apps.Add((New-RoxItem @{
            Key = [string]$a.ProcessName; Title = [string]$a.Name; Subtitle = $sub; Detail = ('{0:N0} MB' -f $a.RamMB)
            Badge = $script:CatText[$cat]; Accent = $script:CatColor[$cat]; Initial = (Get-Initial $a.Name)
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
    if (-not $Names -or $Names.Count -eq 0) { Show-Toast 'اختار برامج أول' 'warn'; return }
    Start-RoxJob 'قفل برامج الخلفية' 'Stop-BackgroundApps -Names $P.Names' @{ Names = $Names } -Quiet -OnDone {
        param($r, $e)
        $res = $r | Select-Object -Last 1
        if ($res) {
            $msg = 'قفلت {0} برامج وفضّيت {1:N0} MB' -f $res.Closed, $res.FreedMB
            if (@($res.StillOpen).Count -gt 0) { $msg += '  (بعضها مفتوح لأن فيه شغل ما انحفظ)' }
            Show-Toast $msg
        }
        Update-Apps
    }
}

# ----------------------------------------------------------------- crash doctor
function Invoke-CrashScan {
    $ui.CrashSummary.Text = 'يفحص...'
    Start-RoxJob 'فحص الكراشات' 'Get-CrashFindings -Days 14' -Quiet -OnDone { param($r, $e) Show-Crashes $r }
}

function Get-CauseColor([string]$Cause) {
    switch -Regex ($Cause) {
        '^gpu|^tdr|^bsod'               { return '#FFFF6464' }
        '^runtime|^missing'             { return '#FFFFD766' }
        '^overlay|^anticheat'           { return '#FF5B9BFF' }
        '^hang|memory'                  { return '#FFB794FF' }
        '^power|^whea|^disk'            { return '#FFFF9F43' }
    }
    return '#FF8A8AA6'
}

function Show-Crashes($List) {
    $script:CrashScanned = $true
    $script:Crashes.Clear()
    $culture = [Globalization.CultureInfo]::GetCultureInfo('ar-AE')
    foreach ($f in @($List)) {
        if (-not $f -or -not $f.Cause) { continue }
        $txt = $script:CauseText[[string]$f.Cause]
        if (-not $txt) { $txt = $script:CauseText['unknown'] }
        $parts = New-Object System.Collections.Generic.List[string]
        if ($f.App) { $parts.Add([string]$f.App) }
        if ($f.Module -and $f.Module -ne 'hang') { $parts.Add('الملف: ' + $f.Module) }
        if ($f.Code -and $f.Code -ne 'hang') { $parts.Add('الكود: ' + $f.Code) }
        try { $parts.Add('آخر مرة: ' + ([datetime]$f.Last).ToString('dd MMM HH:mm', $culture)) } catch { }
        $fix = [string]$f.FixId
        $script:Crashes.Add((New-RoxItem @{
            Key = $fix; Title = $txt[0]; Detail = $txt[1]; Subtitle = ($parts -join '   •   ')
            Badge = ('{0} مرة' -f $f.Count); Accent = (Get-CauseColor ([string]$f.Cause))
            ActionText = $script:FixText[$fix]; HasAction = [bool]($fix -and $script:FixText.ContainsKey($fix)); Tag = $f
        }))
    }
    if ($script:Crashes.Count -eq 0) {
        $ui.CrashEmpty.Visibility = 'Visible'
        $ui.CrashSummary.Text = ''
    } else {
        $ui.CrashEmpty.Visibility = 'Collapsed'
        $ui.CrashSummary.Text = 'لقينا {0} نوع مشاكل - اضغط الزر الأخضر عشان ROX يصلّحها' -f $script:Crashes.Count
    }
}

# ----------------------------------------------------------------- settings
function Update-VendorTiles {
    $sel = [string]$script:Settings.GpuVendor
    $map = @{ amd = 'SetAmd'; nvidia = 'SetNvidia'; intel = 'SetIntel' }
    $glow = @{ amd = '#FFFF6464'; nvidia = '#FF2BEBA6'; intel = '#FF5B9BFF' }
    foreach ($k in $map.Keys) {
        $b = $ui[$map[$k]]
        if ($k -eq $sel) {
            $b.BorderBrush = (New-Object System.Windows.Media.BrushConverter).ConvertFromString($glow[$k])
            $b.BorderThickness = New-Object System.Windows.Thickness(2.5)
        } else {
            $b.BorderBrush = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#22FFFFFF')
            $b.BorderThickness = New-Object System.Windows.Thickness(1.5)
        }
    }
    $guess = Get-GpuVendorGuess
    $txt = ''
    if ($guess) { $txt = 'اكتشفنا في جهازك: ' + $script:VendorName[$guess] }
    if ($sel)   { $txt += '   •   اختيارك: ' + $script:VendorName[$sel] }
    $ui.SetGpuDetected.Text = $txt
}

function Set-GpuVendor([string]$V) {
    $script:Settings.GpuVendor = $V
    $script:Settings.FirstRunDone = $true
    Save-RoxSettings $script:Settings
    $ui.ModalGpu.Visibility = 'Collapsed'
    Update-VendorTiles
    Show-Toast ('تمام! ROX بيضبط لك إعدادات {0}' -f $script:VendorName[$V])
}

function Show-GpuModal {
    $guess = Get-GpuVendorGuess
    if ($guess) { $ui.ModalDetected.Text = 'اكتشفنا في جهازك كرت ' + $script:VendorName[$guess] } else { $ui.ModalDetected.Text = '' }
    $tiles = @{ amd = 'ModalAmd'; nvidia = 'ModalNvidia'; intel = 'ModalIntel' }
    foreach ($k in $tiles.Keys) {
        $b = $ui[$tiles[$k]]
        if ($k -eq $guess) {
            $b.BorderBrush = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#FFFFFFFF')
            $b.BorderThickness = New-Object System.Windows.Thickness(2.5)
        }
    }
    $ui.ModalGpu.Visibility = 'Visible'
    Start-FadeIn $ui.ModalGpu -FromY 0
}

# Copies ROX to C:\ProgramData\ROX\app and makes a desktop shortcut that opens it as administrator.
function Install-RoxCopy {
    try {
        if (-not (Test-Path -LiteralPath $script:AppDir)) { New-Item -ItemType Directory -Path $script:AppDir -Force | Out-Null }
        if ($script:Here.TrimEnd('\') -ne $script:AppDir.TrimEnd('\')) {
            foreach ($f in 'ROX.ps1', 'ROX.xaml', 'RoxEngine.ps1', 'ROX.bat') {
                $src = Join-Path $script:Here $f
                if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $script:AppDir $f) -Force }
            }
        }
        $lnkPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'ROX.lnk'
        $wsh = New-Object -ComObject WScript.Shell
        $lnk = $wsh.CreateShortcut($lnkPath)
        $lnk.TargetPath   = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $lnk.Arguments    = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}"' -f (Join-Path $script:AppDir 'ROX.ps1')
        $lnk.Description  = 'ROX - gaming optimizer'
        $lnk.WindowStyle  = 7
        $ico = Join-Path $script:DataDir 'rox.ico'
        if (Test-Path -LiteralPath $ico) { $lnk.IconLocation = $ico }
        $lnk.Save()
        $bytes = [IO.File]::ReadAllBytes($lnkPath)
        $bytes[0x15] = $bytes[0x15] -bor 0x20          # "Run as administrator"
        [IO.File]::WriteAllBytes($lnkPath, $bytes)
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
        $script:TrayIcon.ShowBalloonTip(4000, 'ROX شغّال جنب الساعة', 'يراقب ألعابك ويسرّعها. اضغط الأيقونة عشان تفتحه.', [System.Windows.Forms.ToolTipIcon]::Info)
        $script:Settings.TrayHintShown = $true
        Save-RoxSettings $script:Settings
    }
}

function New-TrayIcon {
    try {
        $ni = New-Object System.Windows.Forms.NotifyIcon
        try {
            $bmp = New-Object System.Drawing.Bitmap($script:IconPng)
            $small = New-Object System.Drawing.Bitmap($bmp, 32, 32)
            $ni.Icon = [System.Drawing.Icon]::FromHandle($small.GetHicon())
        } catch { $ni.Icon = [System.Drawing.SystemIcons]::Application }
        $ni.Text = 'ROX'
        $menu = New-Object System.Windows.Forms.ContextMenuStrip
        $menu.RightToLeft = 'Yes'
        [void]$menu.Items.Add('افتح ROX', $null, { Show-Main })
        [void]$menu.Items.Add('فضّي الرام', $null, { Start-RoxJob 'تفضية الرام' 'Invoke-CleanRam' -Quiet -OnDone { param($r, $e) $x = $r | Select-Object -Last 1; if ($x) { Show-GameToast 'ROX' ('فضّيت {0:N0} MB' -f $x.FreedMB) } } })
        [void]$menu.Items.Add('خروج', $null, { Exit-Rox })
        $ni.ContextMenuStrip = $menu
        $ni.Add_MouseClick({ param($s, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Show-Main } })
        $ni.Visible = $true
        return $ni
    } catch { Write-Log "tray: $($_.Exception.Message)"; return $null }
}

# ----------------------------------------------------------------- navigation
$script:Pages = [ordered]@{
    NavHome = 'PageHome'; NavOptimize = 'PageOptimize'; NavGames = 'PageGames'
    NavApps = 'PageApps'; NavCrash = 'PageCrash'; NavSettings = 'PageSettings'
}
$script:PageTitles = @{
    PageHome = 'الرئيسية'; PageOptimize = 'التحسينات'; PageGames = 'الألعاب'
    PageApps = 'برامج الخلفية'; PageCrash = 'طبيب الكراش'; PageSettings = 'الإعدادات'
}

function Show-Page([string]$Page) {
    foreach ($p in $script:Pages.Values) { if ($p -ne $Page) { $ui[$p].Visibility = 'Collapsed' } }
    $pg = $ui[$Page]
    $pg.Visibility = 'Visible'
    $pg.ScrollToTop()
    $ui.TitleText.Text = $script:PageTitles[$Page]
    Start-FadeIn $pg
    switch ($Page) {
        'PageApps'     { Update-Apps }
        'PageCrash'    { if (-not $script:CrashScanned) { Invoke-CrashScan } }
        'PageSettings' { Update-VendorTiles; $ui.ChkSetHvci.IsChecked = (Get-MemoryIntegrityOn) }
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

$ui.ConfirmYes.Add_Click({ $ui.ModalConfirm.Visibility = 'Collapsed'; $ui.ConfirmNo.Content = 'إلغاء'; if ($script:ConfirmOnYes) { & $script:ConfirmOnYes } })
$ui.ConfirmAlt.Add_Click({ $ui.ModalConfirm.Visibility = 'Collapsed'; $ui.ConfirmNo.Content = 'إلغاء'; if ($script:ConfirmOnAlt) { & $script:ConfirmOnAlt } })
$ui.ConfirmNo.Add_Click({ $ui.ModalConfirm.Visibility = 'Collapsed'; $ui.ConfirmNo.Content = 'إلغاء'; if ($script:ConfirmOnNo) { & $script:ConfirmOnNo; $script:ConfirmOnNo = $null } })
$ui.BtnDrawerClose.Add_Click({ Close-Drawer })

$ui.ModalAmd.Add_Click({ Set-GpuVendor 'amd' })
$ui.ModalNvidia.Add_Click({ Set-GpuVendor 'nvidia' })
$ui.ModalIntel.Add_Click({ Set-GpuVendor 'intel' })
$ui.SetAmd.Add_Click({ Set-GpuVendor 'amd' })
$ui.SetNvidia.Add_Click({ Set-GpuVendor 'nvidia' })
$ui.SetIntel.Add_Click({ Set-GpuVendor 'intel' })

# home
$ui.BtnFixAll.Add_Click({
    Show-Confirm 'حدّث وصلّح كل شي؟' ('ROX بيطبّق كل التحسينات، يحدّث التعريفات والبرامج وملفات تشغيل الألعاب، ويصلّح مشاكل الكراش وملفات ويندوز.' + "`n" + 'الإصلاح العميق ياخذ 15 إلى 40 دقيقة. تقدر تستخدم الجهاز عادي وهو شغّال.') `
        'كل شي (مع الإصلاح العميق)' { Start-RoxJob 'تحديث وإصلاح كل شي' 'Invoke-UpdateAndFixAll -DeepRepair $true' -OnDone { param($r, $e) Update-State; Request-Restart } } `
        'بدون الإصلاح العميق (أسرع)' { Start-RoxJob 'تحديث وإصلاح كل شي' 'Invoke-UpdateAndFixAll -DeepRepair $false' -OnDone { param($r, $e) Update-State; Request-Restart } }
})
$ui.BtnGaming.Add_Click({ Invoke-ModuleJob 'gaming' 'تحسين الألعاب' })
$ui.BtnGpu.Add_Click({ Invoke-ModuleJob 'gpu' 'إعدادات الكرت' })
$ui.BtnPower.Add_Click({ Invoke-ModuleJob 'power' 'الطاقة والمعالج' })
$ui.BtnSeeAll.Add_Click({ $ui.NavOptimize.IsChecked = $true })
$ui.BtnSeeAll2.Add_Click({ $ui.NavOptimize.IsChecked = $true })

# optimize
$ui.BtnOptimizeAll.Add_Click({
    Show-Confirm 'تطبيق كل التحسينات؟' 'ROX بيسوي نقطة استعادة، وبعدين يطبّق كل التحسينات. كل شي ينحفظ وتقدر ترجّعه من الإعدادات.' 'طبّق الحين' {
        Start-RoxJob 'تطبيق كل التحسينات' 'Invoke-OptimizeAll' -OnDone { param($r, $e) Update-State; Request-Restart }
    }
})
$moduleClick = {
    param($s, $e)
    $src = $e.OriginalSource
    if (-not ($src -is [System.Windows.FrameworkElement])) { return }
    $item = $src.DataContext
    if (-not ($item -is [RoxItem])) { return }
    switch ([string]$src.Tag) {
        'run' { Invoke-ModuleJob $item.Key $item.Title }
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
$ui.ChkAutoBoost.Add_Click({ $script:Settings.AutoBoost = [bool]$ui.ChkAutoBoost.IsChecked; $ui.ChkSetAuto.IsChecked = $script:Settings.AutoBoost; Save-RoxSettings $script:Settings })
$ui.ChkSetAuto.Add_Click({ $script:Settings.AutoBoost = [bool]$ui.ChkSetAuto.IsChecked; $ui.ChkAutoBoost.IsChecked = $script:Settings.AutoBoost; Save-RoxSettings $script:Settings })
$ui.ChkCloseOnStart.Add_Click({ $script:Settings.CloseOnGameStart = [bool]$ui.ChkCloseOnStart.IsChecked; $ui.ChkSetClose.IsChecked = $script:Settings.CloseOnGameStart; Save-RoxSettings $script:Settings })
$ui.ChkSetClose.Add_Click({ $script:Settings.CloseOnGameStart = [bool]$ui.ChkSetClose.IsChecked; $ui.ChkCloseOnStart.IsChecked = $script:Settings.CloseOnGameStart; Save-RoxSettings $script:Settings })

# background apps
$ui.BtnRefreshApps.Add_Click({ Update-Apps })
$ui.BtnCleanRam.Add_Click({
    Start-RoxJob 'تفضية الرام' 'Invoke-CleanRam' -Quiet -OnDone { param($r, $e) $x = $r | Select-Object -Last 1; if ($x) { Show-Toast ('فضّيت {0:N0} MB من الرام' -f $x.FreedMB) } }
})
$ui.BtnCloseSelected.Add_Click({ Stop-Apps @($script:Apps | Where-Object { $_.IsChecked } | ForEach-Object { $_.Key }) })
$ui.BtnCloseAll.Add_Click({
    $names = @($script:Apps | Where-Object { -not $_.IsOn } | ForEach-Object { $_.Key })
    $script:PendingClose = $names
    Show-Confirm 'قفّل كل برامج الخلفية؟' ('بنقفل {0} برامج (إلا اللي عليها نجمة). البرامج اللي فيها شغل ما انحفظ ما بتنقفل غصب.' -f $names.Count) 'قفّلها' { Stop-Apps $script:PendingClose }
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
        if ($item.IsOn) { $keep.Add($n); $item.IsChecked = $false; Show-Toast ($item.Title + ': ROX ما بيقفله أبد') }
        $script:Settings.KeepApps = $keep.ToArray()
        Save-RoxSettings $script:Settings
    }
})

# crash doctor
$ui.BtnScanCrash.Add_Click({ Invoke-CrashScan })
$ui.BtnDeepRepair.Add_Click({
    Show-Confirm 'إصلاح عميق للويندوز؟' 'ROX بيشغّل DISM و SFC عشان يصلّح ملفات ويندوز الخربانة. ياخذ 10 إلى 30 دقيقة ويحتاج إنترنت.' 'ابدأ الإصلاح' {
        Start-RoxJob 'إصلاح ملفات ويندوز' 'Invoke-SystemRepair' -OnDone { param($r, $e) Request-Restart }
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
        Show-Toast 'تم - إذا طلب ريستارت سوّه عشان يشتغل الإصلاح'
    }
})

# settings
$ui.ChkSetStartup.Add_Click({
    $on = [bool]$ui.ChkSetStartup.IsChecked
    $script:Settings.StartWithWindows = $on
    Save-RoxSettings $script:Settings
    Start-RoxJob 'التشغيل مع ويندوز' 'Set-RoxAutostart -On ([bool]$P.On) -ScriptPath $P.Path' @{ On = $on; Path = (Join-Path $script:AppDir 'ROX.ps1') } -Quiet -OnDone {
        param($r, $e)
        if ($e) { Show-Toast 'ما قدرنا نفعّلها' 'warn' } else { Show-Toast 'تم ✓' }
    }
})
$ui.ChkSetHvci.Add_Click({
    if ($ui.ChkSetHvci.IsChecked) {
        Start-RoxJob 'تشغيل Memory Integrity' 'Set-MemoryIntegrity -Enable $true' -Quiet -OnDone { param($r, $e) Show-Toast 'بتشتغل بعد الريستارت' }
    } else {
        $ui.ChkSetHvci.IsChecked = $true
        Show-Confirm 'تقفل Memory Integrity؟' 'مايكروسوفت تقول قفلها يعطي فريمات أكثر في الألعاب، بس يقلل الحماية ضد بعض الفيروسات. إذا لعبة اشتكت (Anti-cheat) رجّعه من هنا.' 'قفّلها' {
            $ui.ChkSetHvci.IsChecked = $false
            Start-RoxJob 'قفل Memory Integrity' 'Set-MemoryIntegrity -Enable $false' -Quiet -OnDone { param($r, $e) Show-Toast 'بتنقفل بعد الريستارت' }
        }
    }
})
$ui.BtnUndoAll.Add_Click({
    Show-Confirm 'ترجّع كل شي مثل ما كان؟' 'ROX بيلغي كل التحسينات ويرجّع إعداداتك الأصلية (الخدمات، خطة الطاقة، الريجستري، تسريع الألعاب).' 'رجّع كل شي' {
        Start-RoxJob 'إرجاع الإعدادات الأصلية' 'Invoke-RoxRestore' -OnDone {
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
        if ($script:TickCount % 12 -eq 1) { Update-Stats }
        Update-ScoreAnim
        $g = $null
        while ($script:Sync.GameEvents.TryDequeue([ref]$g)) { Invoke-GameDetected $g }
        if ($script:ShowEvent -and $script:ShowEvent.WaitOne(0)) { Show-Main }
        if ($script:ToastUntil -and (Get-Date) -gt $script:ToastUntil) { Hide-Toast }
    } catch { Write-Log "tick: $($_.Exception.Message)" }
})

# ----------------------------------------------------------------- start
Initialize-Modules
$ui.ChkAutoBoost.IsChecked    = [bool]$script:Settings.AutoBoost
$ui.ChkSetAuto.IsChecked      = [bool]$script:Settings.AutoBoost
$ui.ChkCloseOnStart.IsChecked = [bool]$script:Settings.CloseOnGameStart
$ui.ChkSetClose.IsChecked     = [bool]$script:Settings.CloseOnGameStart
$ui.ChkSetStartup.IsChecked   = [bool]$script:Settings.StartWithWindows
foreach ($g in @(Get-RoxGames)) { if ($g -and $g.Id) { [void]$script:GameData.Add($g) } }
Show-Games
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

function Save-Shot([string]$Name) {
    Invoke-Pump 8
    $root = $ui.Root
    $w = [int][math]::Max(1, $root.ActualWidth)
    $h = [int][math]::Max(1, $root.ActualHeight)
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($w, $h, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($root)
    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $path = Join-Path $RenderTest "$Name.png"
    $fs = [IO.File]::Create($path)
    $enc.Save($fs)
    $fs.Close()
    Write-Host "shot: $path ($w x $h)"
}

if ($RenderTest) {
    New-Item -ItemType Directory -Path $RenderTest -Force | Out-Null
    $window.WindowStartupLocation = 'Manual'
    $window.Left = 0; $window.Top = 0; $window.Width = 1280; $window.Height = 800
    $window.ShowActivated = $false
    try { $window.Show() } catch { Write-Host "Show failed: $($_.Exception.Message)" }
    Update-Apps
    Invoke-CrashScan
    $deadline = (Get-Date).AddSeconds(240)
    while (((Get-Date) -lt $deadline) -and ($null -ne $script:Job -or $script:JobQueue.Count -gt 0)) { Invoke-Pump 5 }
    Write-Host ("jobs finished: queue={0} running={1} score={2} games={3} apps={4} crashes={5}" -f $script:JobQueue.Count, ($null -ne $script:Job), $script:ScoreTarget, $script:GameData.Count, $script:Apps.Count, $script:Crashes.Count)
    foreach ($l in $script:Logs) { Write-Host ("log: " + $l.Title) }
    $script:ScoreShown = $script:ScoreTarget
    Update-ScoreAnim
    $script:Sync.Cpu = 23; $script:Sync.Gpu = 61; $script:Sync.RamUsed = 6300; $script:Sync.RamTotal = 16384; $script:Sync.Procs = 142
    Update-Stats
    if ($script:Games.Count -eq 0) {
        foreach ($d in @(@('VALORANT', 'Riot', $true), @('Counter-Strike 2', 'Steam', $true), @('Fortnite', 'Epic', $false), @('Call of Duty', 'Steam', $false), @('Minecraft', 'Manual', $false))) {
            $script:GameData.Add([pscustomobject]@{ Id = 'demo:' + $d[0]; Name = $d[0]; Source = $d[1]; Exe = 'C:\Games\game.exe'; Optimized = $d[2]; Image = $null }) | Out-Null
        }
        Show-Games
    }
    if ($script:Apps.Count -lt 3) {
        Show-Apps @(
            [pscustomobject]@{ ProcessName = 'chrome'; Name = 'Google Chrome'; Company = 'Google LLC'; Category = 'app'; RamMB = 1840; Keep = $false; DefaultClose = $true },
            [pscustomobject]@{ ProcessName = 'Discord'; Name = 'Discord'; Company = 'Discord Inc.'; Category = 'chat'; RamMB = 512; Keep = $true; DefaultClose = $false },
            [pscustomobject]@{ ProcessName = 'steamwebhelper'; Name = 'Steam Client WebHelper'; Company = 'Valve'; Category = 'launcher'; RamMB = 430; Keep = $false; DefaultClose = $false },
            [pscustomobject]@{ ProcessName = 'OneDrive'; Name = 'Microsoft OneDrive'; Company = 'Microsoft Corporation'; Category = 'app'; RamMB = 160; Keep = $false; DefaultClose = $true }
        )
    }
    if ($script:Crashes.Count -eq 0) {
        Show-Crashes @(
            [pscustomobject]@{ Cause = 'gpu-nvidia'; App = 'FortniteClient-Win64-Shipping.exe'; Module = 'nvwgf2umx.dll'; Code = 'c0000005'; Count = 3; Last = (Get-Date).AddHours(-5); FixId = 'gpu'; Extra = '' },
            [pscustomobject]@{ Cause = 'runtime-vc'; App = 'cod.exe'; Module = 'MSVCP140.dll'; Code = 'c0000409'; Count = 1; Last = (Get-Date).AddDays(-2); FixId = 'runtimes'; Extra = '' },
            [pscustomobject]@{ Cause = 'tdr'; App = ''; Module = ''; Code = ''; Count = 2; Last = (Get-Date).AddDays(-3); FixId = 'gpu'; Extra = '' }
        )
    }
    Show-Page 'PageHome';     Save-Shot '01-home'
    Show-Page 'PageOptimize'; Save-Shot '02-optimize'
    Show-Page 'PageGames';    Save-Shot '03-games'
    Show-Page 'PageApps'
    Invoke-Pump 3
    $deadline = (Get-Date).AddSeconds(60)
    while (((Get-Date) -lt $deadline) -and ($null -ne $script:Job -or $script:JobQueue.Count -gt 0)) { Invoke-Pump 5 }
    if ($script:Apps.Count -lt 3) {
        Show-Apps @(
            [pscustomobject]@{ ProcessName = 'chrome'; Name = 'Google Chrome'; Company = 'Google LLC'; Category = 'app'; RamMB = 1840; Keep = $false; DefaultClose = $true },
            [pscustomobject]@{ ProcessName = 'Discord'; Name = 'Discord'; Company = 'Discord Inc.'; Category = 'chat'; RamMB = 512; Keep = $true; DefaultClose = $false }
        )
    }
    Save-Shot '04-apps'
    Show-Page 'PageCrash';    Save-Shot '05-crash'
    Show-Page 'PageSettings'; Save-Shot '06-settings'
    Show-Page 'PageHome'
    Show-GpuModal;            Save-Shot '07-gpu-modal'
    $ui.ModalGpu.Visibility = 'Collapsed'
    Open-Drawer 'تحديث وإصلاح كل شي'
    foreach ($t in @(@('step', 'Power: maximum-performance plan'), @('ok', 'ROX power plan active: CPU at full speed + Turbo'), @('step', 'Games: Game Mode ON'), @('warn', 'Could not install NVIDIA app automatically'), @('info', 'Found GPU: NVIDIA GeForce RTX 4070'))) {
        Add-LogLine ([pscustomobject]@{ Kind = $t[0]; Text = $t[1] })
    }
    Save-Shot '08-drawer'
    Close-Drawer
    $ui.BtnFixAll.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    Save-Shot '09-confirm'
    $ui.ModalConfirm.Visibility = 'Collapsed'
    Show-GameToast 'ROX سرّع VALORANT' 'قفلت 6 برامج  •  فضّيت 1,240 MB  •  أولوية عالية'
    Invoke-Pump 5
    $script:Sync.Stop = $true
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
if (-not $script:Settings.FirstRunDone) { Install-RoxCopy }
elseif ($script:Here.TrimEnd('\') -ne $script:AppDir.TrimEnd('\')) { Install-RoxCopy }
$script:TrayIcon = New-TrayIcon
if (-not $Tray) {
    $window.Show()
    if (-not $script:Settings.FirstRunDone) { Show-GpuModal }
} else {
    $script:Sync.Visible = $false
}
[void]$script:App.Run()
$script:Sync.Stop = $true
try { $script:Pool.Close() } catch { }
