# ================================================================
#  VC21 Driver Updater - يحذف التعريف القديم ويركب أحدث تعريف تلقائي
#  NVIDIA / AMD / Intel + باقي تعريفات الجهاز من Windows Update
# ================================================================
param([switch]$Verify)
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue"       # يسرع التحميل كثير
[Net.ServicePointManager]::SecurityProtocol = "Tls12"
function Say($t,$c="Cyan"){ Write-Host "[+] $t" -ForegroundColor $c }
$W = "$env:ProgramData\VC21\drivers"; New-Item $W -ItemType Directory -Force | Out-Null
$UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
Start-Transcript "$W\log.txt" -Append | Out-Null

function Get-Gpu { Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Basic|Remote|Virtual|Parsec|Meta' } }
function NvVer($dv){ $p=$dv.Split('.'); $s=($p[2][-1]+$p[3]); [version]("{0}.{1}" -f $s.Substring(0,3),$s.Substring(3)) }
function Get-7z {
  $z="$env:ProgramFiles\7-Zip\7z.exe"
  if(!(Test-Path $z)){ Say "  تثبيت 7-Zip (لفك ملف التعريف)..."; winget install -e --id 7zip.7zip --silent --accept-package-agreements --accept-source-agreements | Out-Null }
  $z }
function Remove-OldDisplayDrivers($vendorPattern){
  Say "  حذف التعريفات القديمة من النظام بالكامل..." "Yellow"
  $list = pnputil /enum-drivers | Out-String
  $blocks = $list -split "(\r?\n){2,}"
  foreach($b in $blocks){
    if ($b -match 'Published Name:\s+(oem\d+\.inf)' ) { $inf=$Matches[1]
      if ($b -match 'Class Name:\s+Display' -and $b -match $vendorPattern) {
        pnputil /delete-driver $inf /uninstall /force | Out-Null; Say "    حذفت $inf" "DarkGray" } } }
  # بقايا البرامج القديمة
  Remove-Item "$env:LOCALAPPDATA\NVIDIA\DXCache","$env:LOCALAPPDATA\NVIDIA\GLCache","$env:LOCALAPPDATA\AMD\DxCache","$env:LOCALAPPDATA\AMD\DxcCache","$env:LOCALAPPDATA\D3DSCache" -Recurse -Force
}
# نمنع Windows Update يركب تعريف قديم فوق الجديد وقت التثبيت
$DS="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"
function Block-WU { Set-ItemProperty $DS SearchOrderConfig 0 -Type DWord -Force }
function Unblock-WU { Set-ItemProperty $DS SearchOrderConfig 1 -Type DWord -Force }

# ======================= وضع التحقق بعد الريستارت =======================
if ($Verify) {
  Write-Host "`n===== التحقق بعد الريستارت =====" -ForegroundColor Yellow
  $st = Get-Content "$W\state.json" -Raw | ConvertFrom-Json
  foreach($g in Get-Gpu){
    $ok = $g.ConfigManagerErrorCode -eq 0
    Write-Host ("  {0} | تعريف {1} | {2}" -f $g.Name,$g.DriverVersion,($(if($ok){"شغال ✔"}else{"فيه مشكلة ✘ كود $($g.ConfigManagerErrorCode)"})))
  }
  foreach($s in $st){ $now=(Get-Gpu|Where-Object Name -match $s.Vendor).DriverVersion
    if ($s.Vendor -eq 'NVIDIA' -and (NvVer $now) -ge [version]$s.Target) { Say "NVIDIA على آخر إصدار $($s.Target) ✔" "Green" }
    elseif ($s.Vendor -ne 'NVIDIA') { Say "$($s.Vendor): التعريف الحالي $now" "Green" }
    else { Say "NVIDIA ما تحدث للهدف $($s.Target) - أعيد المحاولة..." "Red"; & $PSCommandPath; exit } }
  $bad = Get-PnpDevice -PresentOnly | Where-Object { $_.Status -eq 'Error' }
  if ($bad) { Say "أجهزة ناقصة تعريف:" "Red"; $bad | ForEach-Object { Write-Host "    $($_.FriendlyName)" -ForegroundColor Red } }
  else { Say "كل أجهزة الكمبيوتر تعريفاتها مركبة ✔" "Green" }
  Unblock-WU; Stop-Transcript | Out-Null; exit
}

# ======================= البداية =======================
Say "إنشاء نقطة استعادة قبل تغيير التعريفات..."
Checkpoint-Computer -Description "Before VC21 Driver Update" -RestorePointType DEVICE_DRIVER_INSTALL
if (!(Test-Connection 8.8.8.8 -Count 1 -Quiet)) { Say "ما فيه إنترنت - شيك الاتصال وأعد التشغيل" "Red"; exit }
$state=@(); $needReboot=$false
Block-WU

# ======================= NVIDIA =======================
$nv = Get-Gpu | Where-Object Name -match 'NVIDIA'
if ($nv) {
  $cur = NvVer $nv.DriverVersion
  $mobile = $nv.Name -match 'Laptop|Max-Q|Mobile| M$' -or (Get-CimInstance Win32_Battery)
  Say "NVIDIA: $($nv.Name) | الإصدار الحالي $cur"
  # NVIDIA تعريف Game Ready موحد لكل كروت GTX 900 → RTX 50 ، فنسأل عن أحدث كرت ونأخذ نفس التعريف
  $pfid = if($mobile){1056}else{1066}; $psid = if($mobile){133}else{131}
  $api = "https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php?func=DriverManualLookup&psid=$psid&pfid=$pfid&osID=57&languageCode=1033&isWHQL=1&dch=1&sort1=0&numberOfResults=1"
  $r = Invoke-RestMethod $api -UserAgent $UA
  $latest = [version]$r.IDS[0].downloadInfo.Version; $url = $r.IDS[0].downloadInfo.DownloadURL
  if (!$latest) {   # احتياط: نبني الرابط من صفحة NVIDIA
    $latest=$null; Say "  ما قدرت أجيب رقم آخر إصدار من NVIDIA - بركب NVIDIA App يحدث تلقائي" "Yellow"
    winget install -e --id Nvidia.NvidiaApp --silent --accept-package-agreements --accept-source-agreements }
  elseif ($cur -ge $latest) { Say "  تعريفك محدث على آخر إصدار ($latest) ✔" "Green" }
  else {
    Say "  فيه إصدار أحدث: $latest  → تحميل..." "Yellow"
    $f="$W\nvidia_$latest.exe"; Invoke-WebRequest $url -OutFile $f -UserAgent $UA
    if ((Get-Item $f).Length -lt 200MB) { Say "  التحميل خربان - أعد تشغيل الأداة" "Red" }
    else {
      $z=Get-7z; Remove-Item "$W\nv" -Recurse -Force; & $z x $f "-o$W\nv" -y | Out-Null
      Get-Process NVDisplay.Container,nvcontainer,"NVIDIA app","NVIDIA Share" | Stop-Process -Force
      Remove-OldDisplayDrivers 'NVIDIA'
      Say "  تثبيت التعريف الجديد (تثبيت نظيف - الشاشة بترمش، عادي)..." "Yellow"
      Start-Process "$W\nv\setup.exe" -ArgumentList "-s -clean -noreboot -noeula -nofinish -passive" -Wait
      $state += @{Vendor='NVIDIA';Target="$latest"}; $needReboot=$true; Say "  تم تثبيت NVIDIA $latest ✔" "Green" } }
}

# ======================= AMD =======================
$amd = Get-Gpu | Where-Object Name -match 'AMD|Radeon'
if ($amd) {
  $k = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}" | Where-Object { (Get-ItemProperty $_.PSPath).DriverDesc -match 'AMD|Radeon' } | Select-Object -First 1
  $cur = (Get-ItemProperty $k.PSPath).RadeonSoftwareVersion
  Say "AMD: $($amd.Name) | Adrenalin الحالي: $(if($cur){$cur}else{'غير مثبت'})"
  $html = (Invoke-WebRequest "https://www.amd.com/en/support/download/drivers.html" -UserAgent $UA -UseBasicParsing).Content
  $m = [regex]::Match($html,'https://drivers\.amd\.com/drivers/installer/[^"]+?/whql-amd-software-adrenalin-edition-([\d\.]+)-minimalsetup-[^"]+?_web\.exe')
  if (!$m.Success) { Say "  ما قدرت أجيب رابط AMD - افتح https://www.amd.com/en/support/download/drivers.html" "Red" }
  elseif ($cur -and ([version]$cur -ge [version]$m.Groups[1].Value)) { Say "  تعريفك محدث على آخر إصدار ($cur) ✔" "Green" }
  else {
    $latest=$m.Groups[1].Value; Say "  فيه إصدار أحدث: $latest → تحميل..." "Yellow"
    $f="$W\amd_$latest.exe"; Invoke-WebRequest $m.Value -OutFile $f -UserAgent $UA -Headers @{Referer="https://www.amd.com/"}
    Get-Process RadeonSoftware,AMDRSServ,cncmd | Stop-Process -Force
    Remove-OldDisplayDrivers 'Advanced Micro Devices|AMD'
    Say "  تثبيت Adrenalin $latest (يحمل التعريف المناسب لكرتك ويركبه)..." "Yellow"
    Start-Process $f -ArgumentList "-INSTALL -BOOT -LOG `"$W\amd_install.log`"" -Wait
    $state += @{Vendor='AMD';Target=$latest}; $needReboot=$true; Say "  تم ✔" "Green" }
}

# ======================= Intel =======================
$intel = Get-Gpu | Where-Object Name -match 'Intel'
if ($intel) {
  Say "Intel: $($intel.Name) | الإصدار الحالي $($intel.DriverVersion)"
  if ($intel.Name -match 'Arc') {
    $html = (Invoke-WebRequest "https://www.intel.com/content/www/us/en/download/785597/intel-arc-iris-xe-graphics-windows.html" -UserAgent $UA -UseBasicParsing).Content
    $m = [regex]::Match($html,'https://downloadmirror\.intel\.com/\d+/gfx_win_([\d\.]+)\.exe')
    $latest = $m.Groups[1].Value
    if ($m.Success -and [version]$intel.DriverVersion -lt [version]$latest) {
      Say "  فيه إصدار أحدث: $latest → تحميل..." "Yellow"
      $f="$W\intel_$latest.exe"; Invoke-WebRequest $m.Value -OutFile $f -UserAgent $UA
      Remove-OldDisplayDrivers 'Intel'
      Start-Process $f -ArgumentList "-s --overwrite" -Wait   # Intel installer: silent clean
      $state += @{Vendor='Intel';Target=$latest}; $needReboot=$true; Say "  تم ✔" "Green"
    } elseif ($m.Success) { Say "  محدث ✔" "Green" }
  }
  else { Say "  Intel مدمج - التحديث عبر Windows Update + Intel Driver Assistant" }
  winget install -e --id Intel.IntelDriverAndSupportAssistant --silent --accept-package-agreements --accept-source-agreements | Out-Null
}

# ============ باقي تعريفات الجهاز (الصوت، الشبكة، الشيبست، البلوتوث...) ============
Unblock-WU
Say "البحث عن كل تعريفات الجهاز الناقصة/القديمة في Windows Update..." "Yellow"
$s = New-Object -ComObject Microsoft.Update.Session
$sm = New-Object -ComObject Microsoft.Update.ServiceManager; $sm.ClientApplicationID="VC21"
$srch = $s.CreateUpdateSearcher(); $srch.ServerSelection = 2   # Windows Update
$res = $srch.Search("IsInstalled=0 and Type='Driver' and IsHidden=0")
$upd = New-Object -ComObject Microsoft.Update.UpdateColl
foreach($u in $res.Updates){
  if ($state.Vendor -and ($u.Title -match ($state.Vendor -join '|')) -and $u.DriverClass -eq 'Display') { continue }  # لا يرجع تعريف كرت أقدم
  $u.AcceptEula(); $upd.Add($u) | Out-Null; Say "  + $($u.Title)" "DarkGray" }
if ($upd.Count) {
  $d=$s.CreateUpdateDownloader(); $d.Updates=$upd; $d.Download() | Out-Null
  $i=$s.CreateUpdateInstaller(); $i.Updates=$upd; $r=$i.Install()
  Say "تم تثبيت $($upd.Count) تعريف ✔" "Green"; if($r.RebootRequired){$needReboot=$true} }
else { Say "كل تعريفات الجهاز الثانية محدثة ✔" "Green" }

# ======================= ريستارت + تحقق تلقائي =======================
if ($needReboot) {
  $state | ConvertTo-Json | Out-File "$W\state.json"
  Block-WU
  Copy-Item $PSCommandPath "$W\Driver-Update.ps1" -Force
  Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" "VC21Verify" "powershell -NoProfile -ExecutionPolicy Bypass -NoExit -File `"$W\Driver-Update.ps1`" -Verify"
  Remove-Item "$W\nv" -Recurse -Force
  Say "الجهاز بيسوي ريستارت بعد 20 ثانية، وبعدها الأداة تتأكد إن كل شيء تركب صح." "Yellow"
  Stop-Transcript | Out-Null
  shutdown /r /t 20 /c "VC21: إكمال تثبيت التعريفات"
} else { Say "كل شيء محدث - ما يحتاج ريستارت ✔" "Green"; Stop-Transcript | Out-Null }
