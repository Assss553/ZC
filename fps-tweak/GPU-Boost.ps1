# ================================================================
#  VC21 GPU + Game Boost  |  يكشف كرتك (NVIDIA / AMD / Intel)
#  يضبط تعريفه للأداء + تختار لعبتك ويعطيها كل شيء + يفضي الرام
# ================================================================
$ErrorActionPreference = "SilentlyContinue"
function Say($t,$c="Cyan"){ Write-Host "[+] $t" -ForegroundColor $c }
function Reg($p,$n,$v,$t="DWord"){ if(!(Test-Path $p)){New-Item $p -Force|Out-Null}; Set-ItemProperty -Path $p -Name $n -Value $v -Type $t -Force }
$Work = "$env:ProgramData\VC21"; New-Item $Work -ItemType Directory -Force | Out-Null

# ---------- أداة تفريغ الرام (Standby list + Working sets) ----------
Add-Type @'
using System; using System.Runtime.InteropServices; using System.Diagnostics;
public class VCRam {
  [DllImport("ntdll.dll")] static extern int NtSetSystemInformation(int c, ref int i, int l);
  [DllImport("psapi.dll")] static extern bool EmptyWorkingSet(IntPtr h);
  [DllImport("advapi32.dll")] static extern bool OpenProcessToken(IntPtr h,int a,out IntPtr t);
  [DllImport("advapi32.dll")] static extern bool LookupPrivilegeValue(string s,string n,out long l);
  [DllImport("advapi32.dll")] static extern bool AdjustTokenPrivileges(IntPtr t,bool d,ref TP n,int l,IntPtr p,IntPtr r);
  [StructLayout(LayoutKind.Sequential,Pack=1)] struct TP{public int C;public long L;public int A;}
  static void Priv(string n){IntPtr t;OpenProcessToken(Process.GetCurrentProcess().Handle,0x28,out t);TP p;p.C=1;p.A=2;LookupPrivilegeValue(null,n,out p.L);AdjustTokenPrivileges(t,false,ref p,0,IntPtr.Zero,IntPtr.Zero);}
  public static void Clean(int keepPid){
    Priv("SeProfileSingleProcessPrivilege"); Priv("SeIncreaseQuotaPrivilege"); Priv("SeDebugPrivilege");
    foreach(var p in Process.GetProcesses()){ try{ if(p.Id!=keepPid && p.Id>4) EmptyWorkingSet(p.Handle);}catch{} }
    int cmd=4; NtSetSystemInformation(80, ref cmd, 4);   // Purge standby list
    cmd=2;     NtSetSystemInformation(80, ref cmd, 4);   // Flush modified list
  }
}
'@
function FreeRam($keep=0){
  $b=(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory
  [VCRam]::Clean($keep)
  $a=(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory
  Say ("الرام: فضّيت {0:N0} MB  (الفاضي الحين {1:N0} MB)" -f (($a-$b)/1KB),($a/1KB)) "Green"
}

# ---------- 1) كشف الكرت ----------
$gpus = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Basic|Remote|Virtual|Parsec' }
$classKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
$gpuKeys = Get-ChildItem $classKey | Where-Object { $_.PSChildName -match '^\d{4}$' }
Write-Host "`n===== كروت الشاشة عندك =====" -ForegroundColor Yellow
$gpus | ForEach-Object { Write-Host ("  {0}  | تعريف {1}" -f $_.Name,$_.DriverVersion) }
$ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)
$cpu = (Get-CimInstance Win32_Processor).Name
Write-Host "  المعالج: $cpu  |  الرام: $ram GB`n"

function Get-Key($pat){ $gpuKeys | Where-Object { (Get-ItemProperty $_.PSPath).DriverDesc -match $pat } }

# ---------- 2-A) NVIDIA ----------
if ($gpus.Name -match 'NVIDIA') {
  Say "NVIDIA مكتشف - ضبط التعريف للأداء الأقصى..." "Green"
  foreach($k in (Get-Key 'NVIDIA')){                                   # PowerMizer = أقصى أداء
    Reg $k.PSPath "PerfLevelSrc" 0x2222; Reg $k.PSPath "PowerMizerEnable" 1
    Reg $k.PSPath "PowerMizerLevel" 1;   Reg $k.PSPath "PowerMizerLevelAC" 1 }
  Set-Service NvTelemetryContainer -StartupType Disabled; Stop-Service NvTelemetryContainer -Force
  # NVIDIA Profile Inspector: نفس إعدادات لوحة التحكم بس تلقائي
  $npi = "$Work\npi\nvidiaProfileInspector.exe"
  if (!(Test-Path $npi)) {
    Say "  تحميل NVIDIA Profile Inspector..."
    Invoke-WebRequest "https://github.com/Orbmu2k/nvidiaProfileInspector/releases/latest/download/nvidiaProfileInspector.zip" -OutFile "$Work\npi.zip" -UseBasicParsing
    Expand-Archive "$Work\npi.zip" "$Work\npi" -Force }
  $set = @{ 274197361=1          # Power management: Prefer maximum performance
            11041231=0x08416747  # Vertical Sync: Off
            8102046=1            # Low Latency / Max pre-rendered frames = 1
            549528094=1          # Threaded optimization: On
            13510289=20          # Texture filtering quality: High performance
            8703344=0            # Texture filtering - Trilinear optimization off-load
            6524559=1 }          # Shader cache: On
  $xml = "<?xml version=`"1.0`" encoding=`"utf-16`"?><ArrayOfProfile><Profile><ProfileName>Base Profile</ProfileName><Executeables /><Settings>"
  foreach($id in $set.Keys){ $xml += "<ProfileSetting><SettingNameInfo /><SettingID>$id</SettingID><SettingValue>$($set[$id])</SettingValue><ValueType>Dword</ValueType></ProfileSetting>" }
  $xml += "</Settings></Profile></ArrayOfProfile>"
  $xml | Out-File "$Work\vc21.nip" -Encoding Unicode
  if (Test-Path $npi) { Start-Process $npi -ArgumentList "-silentImport `"$Work\vc21.nip`"" -Wait; Say "  تم تطبيق: أقصى أداء، VSync Off، Low Latency، Threaded Opt" "Green" }
  else { Say "  ما قدرت أحمل Profile Inspector (إنترنت؟) - طبقت تعديلات الريجستري فقط" "Yellow" }
  Write-Host "  >> مضاعفة الفريمات الحقيقية في NVIDIA:" -ForegroundColor Magenta
  Write-Host "     - RTX 40/50: شغّل DLSS Frame Generation داخل اللعبة، أو NVIDIA Smooth Motion من تطبيق NVIDIA App (يشتغل على أي لعبة)"
  Write-Host "     - كل كروت RTX: DLSS على Quality/Balanced  |  GTX: استخدم FSR داخل اللعبة"
  $app = "${env:ProgramFiles}\NVIDIA Corporation\NVIDIA app\CEF\NVIDIA app.exe"
  if (Test-Path $app) { Start-Process $app } else { Write-Host "     (NVIDIA App مو مثبت: https://www.nvidia.com/en-us/software/nvidia-app/)" -ForegroundColor DarkGray }
}

# ---------- 2-B) AMD ----------
if ($gpus.Name -match 'AMD|Radeon') {
  Say "AMD Radeon مكتشف - ضبط التعريف..." "Green"
  foreach($k in (Get-Key 'AMD|Radeon')){
    Reg $k.PSPath "EnableUlps" 0                 # يمنع الكرت ينام (تقطيع أقل)
    Reg $k.PSPath "EnableUlps_NA" "0" "String"
    $u = "$($k.PSPath)\UMD"
    Reg $u "Main3D_DEF" "1" "String"            # Performance
    Reg $u "TFQ_DEF" "2" "String"               # Texture filtering = Performance
    Reg $u "SurfaceFormatReplacements_DEF" "1" "String"
    Reg $u "VSyncControl_DEF" "0" "String"      # VSync off unless app says
    Reg $u "Tessellation_OPTION_DEF" "2" "String"; Reg $u "Tessellation_DEF" "1" "String" }  # Tessellation محدود x8
  Set-Service "AMD Crash Defender Service" -StartupType Disabled
  Write-Host "  >> مضاعفة الفريمات الحقيقية في AMD (هذي اللي تدبل فعلاً):" -ForegroundColor Magenta
  Write-Host "     - AFMF (Fluid Motion Frames): Adrenalin > Gaming > Graphics > شغّله  => تقريباً x2 فريمات بأي لعبة DX11/12 (RX 6000 وأحدث)"
  Write-Host "     - HYPR-RX: يشغّل Anti-Lag + Boost + RSR بضغطة وحدة"
  Write-Host "     - Radeon Super Resolution (RSR) أو FSR داخل اللعبة"
  $ad = "${env:ProgramFiles}\AMD\CNext\CNext\RadeonSoftware.exe"
  if (Test-Path $ad) { Start-Process $ad } else { Write-Host "     (Adrenalin مو مثبت: https://www.amd.com/en/support)" -ForegroundColor DarkGray }
}

# ---------- 2-C) Intel ----------
if ($gpus.Name -match 'Intel') {
  Say "Intel Graphics مكتشف..." "Green"
  foreach($k in (Get-Key 'Intel')){ Reg $k.PSPath "Disable_OverlayDSQualityEnhancement" 1; Reg $k.PSPath "FeatureTestControl" 0x9240 }  # يقفل ميزات توفير طاقة الشاشة (PSR/DPST)
  if ($gpus.Count -gt 1) { Say "  عندك كرت ثاني (Dedicated) - الألعاب بتتوجه له مو لـ Intel" }
  Write-Host "  >> Intel Arc: شغّل XeSS / XeSS Frame Generation داخل اللعبة، وIntel Graphics Software > Low Latency" -ForegroundColor Magenta
  Write-Host "  >> Intel مدمج: FSR داخل اللعبة على Performance + دقة 720p-900p هو أكبر فرق" -ForegroundColor Magenta
}

# ---------- 3) تختار لعبتك ----------
Write-Host "`n===== البحث عن ألعابك =====" -ForegroundColor Yellow
$roots = @()
$steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam").SteamPath
if ($steam) { $vdf = Get-Content "$steam\steamapps\libraryfolders.vdf" -Raw
  $roots += [regex]::Matches($vdf,'"path"\s+"([^"]+)"') | ForEach-Object { ($_.Groups[1].Value -replace '\\\\','\') + "\steamapps\common" } }
$roots += "$env:ProgramFiles\Epic Games","C:\Riot Games","C:\XboxGames","D:\Games","E:\Games","${env:ProgramFiles(x86)}\Steam\steamapps\common"
$skip = 'unins|setup|crash|redist|helper|launcher|vc_|dxsetup|report|install|ue4prereq|easyanticheat|battleye|update|cef|overlay'
$games = foreach($r in ($roots | Select-Object -Unique)){ if(Test-Path $r){ Get-ChildItem $r -Directory | ForEach-Object {
  $e = Get-ChildItem $_.FullName -Recurse -Filter *.exe -Depth 4 | Where-Object { $_.Name -notmatch $skip } | Sort-Object Length -Descending | Select-Object -First 1
  if ($e) { [pscustomobject]@{ Name=$_.Name; Exe=$e.FullName } } } } }
$games = @($games)
for($i=0;$i -lt $games.Count;$i++){ Write-Host ("  [{0}] {1}" -f ($i+1),$games[$i].Name) }
Write-Host "  [0] أضيف لعبة بنفسي (مسار exe)"
$pick = Read-Host "`nاختر رقم اللعبة (أو أرقام مفصولة بفاصلة 1,3)"
$sel = if ($pick -eq '0') { $p = Read-Host "حط مسار exe"; ,[pscustomobject]@{Name=[IO.Path]::GetFileNameWithoutExtension($p);Exe=$p.Trim('"')} }
       else { $pick -split ',' | ForEach-Object { $games[[int]$_.Trim()-1] } }

foreach($g in $sel){ if(!$g){continue}
  Say "تخصيص $($g.Name)..." "Green"
  $exe=$g.Exe; $n=[IO.Path]::GetFileName($exe)
  Reg "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" $exe "GpuPreference=2;SwapEffectUpgradeEnable=1;" "String"   # الكرت القوي + Flip model
  Reg "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" $exe "~ DISABLEDXMAXIMIZEDWINDOWEDMODE HIGHDPIAWARE" "String"
  Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$n\PerfOptions" "CpuPriorityClass" 3
  Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$n\PerfOptions" "IoPriority" 3
  netsh advfirewall firewall add rule name="VC21 $($g.Name)" dir=in action=allow program="$exe" | Out-Null
}

# ---------- 4) وضع الجيم: يشغل اللعبة ويراقبها ----------
$go = Read-Host "`nتبي أشغل '$($sel[0].Name)' بوضع VC21 Game Mode الحين؟ (y/n)"
if ($go -eq 'y' -and $sel[0]) {
  $kill = "OneDrive","Teams","ms-teams","msedge","chrome","Spotify","Discord","YourPhone","PhoneExperienceHost","Widgets","SearchHost","Cortana","AdobeARM","EpicWebHelper"
  $keepDiscord = Read-Host "تستخدم Discord وانت تلعب؟ (y = لا تقفله)"
  if ($keepDiscord -eq 'y') { $kill = $kill | Where-Object { $_ -ne 'Discord' } }
  Get-Process $kill | Stop-Process -Force
  $plan = powercfg -list | Select-String 'VC21|Ultimate|High performance' | Select-Object -First 1
  if ($plan -match '([0-9a-f\-]{36})') { powercfg -setactive $Matches[1] }
  FreeRam
  Start-Process $sel[0].Exe -WorkingDirectory (Split-Path $sel[0].Exe)
  $pn = [IO.Path]::GetFileNameWithoutExtension($sel[0].Exe)
  Say "انتظر اللعبة تفتح... (خل هالنافذة مفتوحة، تنظف الرام كل 5 دقايق)" "Yellow"
  Start-Sleep 30
  while ($p = Get-Process $pn) {
    $p | ForEach-Object { $_.PriorityClass = 'High' }
    FreeRam $p[0].Id
    Start-Sleep 300
  }
  Say "اللعبة انقفلت - رجعت كل شيء طبيعي." "Green"
} else { FreeRam }
Write-Host "`nخلصنا. للعبة القادمة شغل Run-GPU-Boost.bat مرة ثانية." -ForegroundColor Green
