# ================================================================
#  FPS Tweak - VC21   |   Windows 10 / 11   |   شغله كمسؤول (Admin)
# ================================================================
$WallpaperText = "VC21"   # النص اللي ينكتب بالخلفية (غيره لو تبي)
$ErrorActionPreference = "SilentlyContinue"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "شغل السكربت كمسؤول (Run as Administrator)" -ForegroundColor Red; pause; exit
}
function Say($t,$c="Cyan"){ Write-Host "[+] $t" -ForegroundColor $c }
function Reg($p,$n,$v,$t="DWord"){ if(!(Test-Path $p)){New-Item $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name $n -Value $v -Type $t -Force }

# ---------- 0) نقطة استعادة ----------
Say "إنشاء نقطة استعادة (Restore Point)..."
Enable-ComputerRestore -Drive "$env:SystemDrive\"
Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" "SystemRestorePointCreationFrequency" 0
Checkpoint-Computer -Description "Before FPS Tweak VC21" -RestorePointType MODIFY_SETTINGS

# ---------- 1) خطة طاقة Ultimate Performance ----------
Say "إنشاء خطة طاقة VC21 Ultimate..."
$out = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
if ($out -match '([0-9a-f\-]{36})') {
    $g = $Matches[1]
    powercfg -changename $g "VC21 Ultimate FPS" | Out-Null
    powercfg -setactive $g
    powercfg -setacvalueindex $g SUB_PROCESSOR PROCTHROTTLEMIN 100
    powercfg -setacvalueindex $g SUB_PROCESSOR PROCTHROTTLEMAX 100
    powercfg -setacvalueindex $g SUB_PROCESSOR CPMINCORES 100          # Core parking off
    powercfg -setacvalueindex $g 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0  # USB suspend off
    powercfg -setacvalueindex $g SUB_PCIEXPRESS ASPM 0
    powercfg -setacvalueindex $g SUB_DISK DISKIDLE 0
    powercfg -setactive $g
}
powercfg -h off   # يقفل السبات ويوفر مساحة

# ---------- 2) إيقاف خدمات غير ضرورية (آمنة فقط) ----------
# ما نلمس: الصوت، الشبكة، Windows Update، Defender، Steam، Xbox (للألعاب)، الطابعة لو تحتاجها
Say "إيقاف الخدمات غير الضرورية (الآمنة فقط)..."
$services = @(
 "DiagTrack",          # تتبع وإرسال بيانات لمايكروسوفت
 "dmwappushservice",   # WAP push (تتبع)
 "SysMain",            # Superfetch - يستهلك رام وقرص
 "WSearch",            # فهرسة البحث - تستهلك قرص ومعالج
 "MapsBroker",         # الخرائط
 "lfsvc",              # الموقع الجغرافي
 "RetailDemo",         # وضع العرض بالمحلات
 "Fax",
 "WerSvc",             # تقارير الأخطاء
 "PcaSvc",             # Program Compatibility Assistant
 "TrkWks",             # تتبع الروابط
 "WMPNetworkSvc",      # مشاركة Windows Media
 "RemoteRegistry",
 "diagnosticshub.standardcollector.service",
 "edgeupdate","edgeupdatem"
)
foreach($s in $services){ Stop-Service $s -Force; Set-Service $s -StartupType Disabled; Say "  off: $s" "DarkGray" }

# ---------- 3) تطبيقات الخلفية والتليمتري ----------
Say "إيقاف تطبيقات الخلفية والتتبع..."
Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1
Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" 2
Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BackgroundAppGlobalToggle" 0
Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled" 0
Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SystemPaneSuggestionsEnabled" 0
Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat" "ChatIcon" 3
Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0     # Widgets
Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
Get-ScheduledTask -TaskPath "\Microsoft\Windows\Customer Experience Improvement Program\" | Disable-ScheduledTask | Out-Null
Get-ScheduledTask -TaskPath "\Microsoft\Windows\Application Experience\" | Disable-ScheduledTask | Out-Null

# ---------- 4) تحسينات الألعاب و GPU ----------
Say "تفعيل Game Mode و Hardware GPU Scheduling..."
Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
Reg "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1
Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2     # HAGS
Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0                          # تسجيل الخلفية يأكل فريمات
Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 2
Reg "HKCU:\System\GameConfigStore" "GameDVR_HonorUserFSEBehaviorMode" 1
Reg "HKCU:\System\GameConfigStore" "GameDVR_DXGIHonorFSEWindowsCompatible" 1
$mm = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
Reg $mm "SystemResponsiveness" 0
Reg $mm "NetworkThrottlingIndex" 0xffffffff
Reg "$mm\Tasks\Games" "GPU Priority" 8
Reg "$mm\Tasks\Games" "Priority" 6
Reg "$mm\Tasks\Games" "Scheduling Category" "High" "String"
Reg "$mm\Tasks\Games" "SFIO Priority" "High" "String"
Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38
# ماوس بدون تسارع
Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" "String"
Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" "String"
Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" "String"
# تأثيرات بصرية = أفضل أداء (يوفر GPU و رام)
Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2
Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0
Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String"
# الشبكة (Ping أقل)
Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" | ForEach-Object {
  Reg $_.PSPath "TcpAckFrequency" 1; Reg $_.PSPath "TCPNoDelay" 1 }

# ---------- 5) تخصيص الألعاب: High Performance GPU + أولوية عالية ----------
Say "تخصيص الألعاب المثبتة (GPU عالي + أولوية High)..."
$gameDirs = @("${env:ProgramFiles(x86)}\Steam\steamapps\common","$env:ProgramFiles\Epic Games","C:\Riot Games","C:\XboxGames",
              "D:\SteamLibrary\steamapps\common","E:\SteamLibrary\steamapps\common","D:\Games","E:\Games")
$exes = foreach($d in $gameDirs){ if(Test-Path $d){ Get-ChildItem $d -Recurse -Filter *.exe -Depth 3 |
          Where-Object { $_.Name -notmatch 'unins|setup|crash|redist|helper|launcher|vc_|dxsetup|report|install' -and $_.Length -gt 5MB } } }
foreach($e in $exes){
  Reg "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" $e.FullName "GpuPreference=2;" "String"          # GPU القوي
  Reg "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" $e.FullName "~ DISABLEDXMAXIMIZEDWINDOWEDMODE HIGHDPIAWARE" "String"
  Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($e.Name)\PerfOptions" "CpuPriorityClass" 3  # High
  Say "  game: $($e.Name)" "DarkGray"
}

# ---------- 6) تنظيف رام وملفات مؤقتة ----------
Say "تنظيف الملفات المؤقتة والرام..."
Remove-Item "$env:TEMP\*","$env:SystemRoot\Temp\*","$env:SystemRoot\Prefetch\*" -Recurse -Force
ipconfig /flushdns | Out-Null
$kill = "OneDrive","Teams","ms-teams","Cortana","YourPhone","PhoneExperienceHost","GameBar","Widgets","msedge"
Get-Process $kill | Stop-Process -Force
Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" "OneDrive" "" "String"; Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" "OneDrive"

# ---------- 7) الخلفية السوداء VC21 ----------
Say "إنشاء الخلفية السوداء ($WallpaperText)..."
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
$sc = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$w=[Math]::Max($sc.Width,1920); $h=[Math]::Max($sc.Height,1080)
$bmp = New-Object Drawing.Bitmap $w,$h
$gr = [Drawing.Graphics]::FromImage($bmp)
$gr.TextRenderingHint = "AntiAliasGridFit"; $gr.Clear([Drawing.Color]::Black)
$font = New-Object Drawing.Font "Segoe UI Black",([int]($h/4)),([Drawing.FontStyle]::Bold),([Drawing.GraphicsUnit]::Pixel)
$fmt = New-Object Drawing.StringFormat; $fmt.Alignment="Center"; $fmt.LineAlignment="Center"
$gr.DrawString($WallpaperText,$font,[Drawing.Brushes]::White,(New-Object Drawing.RectangleF 0,0,$w,$h),$fmt)
$wp = "$env:USERPROFILE\Pictures\VC21_wallpaper.png"; $bmp.Save($wp,[Drawing.Imaging.ImageFormat]::Png); $gr.Dispose(); $bmp.Dispose()
Add-Type 'using System.Runtime.InteropServices; public class WP{[DllImport("user32.dll")]public static extern int SystemParametersInfo(int a,int b,string c,int d);}'
Reg "HKCU:\Control Panel\Desktop" "WallpaperStyle" "10" "String"
[WP]::SystemParametersInfo(20,0,$wp,3) | Out-Null

# ---------- 8) فحص Steam وإصلاحه ----------
Say "فحص Steam..." "Yellow"
$steamPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam").SteamPath
if (-not $steamPath) { $steamPath = "${env:ProgramFiles(x86)}\Steam" }
$steamExe = Join-Path $steamPath "steam.exe"
if (-not (Test-Path $steamExe)) {
    Say "المشكلة: Steam غير مثبت. حمله من https://store.steampowered.com/about/" "Red"
} elseif (Get-Process steam) {
    Say "Steam شغال تمام ✔" "Green"
} else {
    Say "Steam مقفل - أحاول أشغله..." "Yellow"
    if (-not (Test-Connection store.steampowered.com -Count 1 -Quiet)) { Say "المشكلة المحتملة: ما فيه إنترنت أو سيرفرات ستيم واقفة" "Red" }
    $svc = Get-Service "Steam Client Service"
    if ($svc -and $svc.StartType -eq 'Disabled') { Set-Service "Steam Client Service" -StartupType Manual; Say "  تم تفعيل Steam Client Service (كانت معطلة)" }
    Get-Process steamwebhelper,steamservice | Stop-Process -Force
    Start-Process $steamExe; Start-Sleep 20
    if (Get-Process steam) { Say "Steam اشتغل ✔" "Green" }
    else {
        Say "ما اشتغل - أحاول إصلاح (حذف ملفات الكاش المعطوبة)..." "Yellow"
        Remove-Item "$steamPath\appcache\httpcache","$steamPath\package\*.tmp" -Recurse -Force
        Start-Process $steamExe -ArgumentList "-clearbeta"; Start-Sleep 25
        if (Get-Process steam) { Say "Steam اشتغل بعد الإصلاح ✔" "Green" }
        else {
            Say "Steam ما اشتغل. الأسباب المحتملة:" "Red"
            Say "  - برنامج حماية/جدار ناري يحجبه (أضف steam.exe للاستثناءات)" "Red"
            Say "  - ملفات ناقصة: شغل $steamPath\bin\SteamService.exe /repair كمسؤول" "Red"
            Say "  - آخر سجل خطأ: $steamPath\logs\bootstrap_log.txt" "Red"
            Get-Content "$steamPath\logs\bootstrap_log.txt" -Tail 5 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkRed }
        }
    }
}

Write-Host "`n=========================================" -ForegroundColor Green
Write-Host " تم! سو ريستارت للجهاز عشان تتفعل كل التعديلات" -ForegroundColor Green
Write-Host " للتراجع: rstrui.exe  (نقطة الاستعادة: Before FPS Tweak VC21)" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
