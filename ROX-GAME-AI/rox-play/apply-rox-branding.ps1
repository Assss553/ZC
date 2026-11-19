# Applies ROX Play branding on top of an unmodified chiaki-ng checkout (run from the chiaki-ng root).
# All changes are text replacements so the full modified source stays reproducible and public (AGPL-3.0).
$ErrorActionPreference = "Stop"

function Replace-InFile($path, $from, $to) {
    $c = Get-Content -Raw -Encoding UTF8 $path
    if (-not $c.Contains($from)) { throw "Branding anchor not found in ${path}: $from" }
    Set-Content -NoNewline -Encoding UTF8 $path ($c.Replace($from, $to))
    Write-Host "patched $path"
}

# 1) ROX colours: orange accent on black (no blue)
Replace-InFile "gui/src/qml/qtquickcontrols2.conf" "Accent=#00a7ff" "Accent=#FF7A00`r`nBackground=#0A0A0A"
Replace-InFile "gui/src/qml/Main.qml" 'Material.accent: "#00a7ff"' "Material.accent: `"#FF7A00`"`r`n    Material.background: `"#0A0A0A`""

# 2) Name shown to the user
Replace-InFile "gui/src/main.cpp" 'QGuiApplication::setApplicationDisplayName("chiaki-ng");' 'QGuiApplication::setApplicationDisplayName("ROX Play");'
Replace-InFile "gui/src/main.cpp" 'QString("chiaki-ng:%1")' 'QString("ROX Play:%1")'
Replace-InFile "gui/src/qmlmainwindow.cpp" 'QGuiApplication::setApplicationDisplayName("chiaki-ng");' 'QGuiApplication::setApplicationDisplayName("ROX Play");'
Replace-InFile "gui/src/qmlmainwindow.cpp" 'QString("chiaki-ng:%1")' 'QString("ROX Play:%1")'
