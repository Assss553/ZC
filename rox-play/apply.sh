#!/usr/bin/env bash
# ROX Play: one Android app that pairs with the PS4/PS5 and streams it directly (chiaki-ng, no Sony app, no screen
# recording), with ROX translation inside the stream and ROX TV support. Run from the chiaki-ng root.
# Based on chiaki-ng (AGPL-3.0); this script and rox-play/ are the full ROX changes.
set -euo pipefail
R="$(cd "$(dirname "$0")" && pwd)"
sub() { grep -qF -- "$2" "$1" || { echo "anchor not found in $1: $2"; exit 1; }; python3 - "$1" "$2" "$3" <<'PY'
import sys; p,a,b=sys.argv[1:4]; s=open(p,encoding='utf-8').read(); open(p,'w',encoding='utf-8').write(s.replace(a,b,1))
PY
echo "patched $1"; }
A=android/app
# branding (same as the earlier ROX Play build)
sub $A/build.gradle 'applicationId "com.metallic.chiaki"' 'applicationId "com.rox.play"'
sub $A/src/main/res/values/strings.xml '<string name="app_name">Chiaki</string>' '<string name="app_name">ROX</string>'
sub $A/src/main/res/layout/activity_main.xml 'app:layout_behavior=".main.FloatingActionButtonBackgroundBehavior"' 'app:layout_behavior="com.metallic.chiaki.main.FloatingActionButtonBackgroundBehavior"'
sub $A/src/main/res/layout/activity_main.xml 'app:layout_behavior=".main.FloatingActionButtonSpeedDialBehavior"' 'app:layout_behavior="com.metallic.chiaki.main.FloatingActionButtonSpeedDialBehavior"'
# ROX translation: ML Kit text recognition (on-device, bundled model)
sub $A/build.gradle '    implementation libs.oboe' '    implementation libs.oboe
    implementation "com.google.mlkit:text-recognition:16.0.1"'
# ROX code + data
mkdir -p $A/src/main/java/com/rox/play/rox $A/src/main/assets
cp "$R"/java/com/rox/play/rox/*.java $A/src/main/java/com/rox/play/rox/
cp -r "$R"/assets/* $A/src/main/assets/
# hook into the stream screen: read the video surface, show the Arabic subtitle, serve ROX TV
S=$A/src/main/java/com/metallic/chiaki/stream/StreamActivity.kt
sub $S '		viewModel.session.attachToSurfaceView(binding.surfaceView)' '		viewModel.session.attachToSurfaceView(binding.surfaceView)
		com.rox.play.rox.RoxStream.attach(this, binding.surfaceView, binding.mainStreamLayout)'
sub $S '	override fun onDestroy()
	{' '	override fun onDestroy()
	{
		com.rox.play.rox.RoxStream.detach()'
# the TV app must not be compressed inside the APK twice
echo "ROX applied"
