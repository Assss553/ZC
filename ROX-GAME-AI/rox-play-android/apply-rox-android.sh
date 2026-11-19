#!/usr/bin/env bash
# ROX Play (Android): ROX changes on top of an unmodified chiaki-ng checkout. Run from the chiaki-ng root.
# Public and reproducible (AGPL-3.0). The app talks to the console directly (Remote Play protocol):
# PIN pairing + stream on the phone, no Sony app needed.
set -euo pipefail
sub() { grep -qF -- "$2" "$1" || { echo "anchor not found in $1: $2"; exit 1; }; python3 - "$1" "$2" "$3" <<'PY'
import sys; p,a,b=sys.argv[1:4]; s=open(p,encoding='utf-8').read(); open(p,'w',encoding='utf-8').write(s.replace(a,b))
PY
echo "patched $1"; }
sub android/app/build.gradle 'applicationId "com.metallic.chiaki"' 'applicationId "com.rox.play"'
sub android/app/src/main/res/values/strings.xml '<string name="app_name">Chiaki</string>' '<string name="app_name">ROX Play</string>'
