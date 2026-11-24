#!/bin/sh
# Builds ROX-Phone.apk (does everything on the phone) and ROX-TV.apk (shows the translation over the HDMI input).
#   sudo apt-get install android-sdk-platform-23 aapt apksigner dalvik-exchange zipalign default-jdk
set -e; cd "$(dirname "$0")"; SDK=/usr/lib/android-sdk/platforms/android-23/android.jar
build() { # $1 variant  $2 manifest  $3 out  $4 assets dir (or "")
  rm -rf build && mkdir -p build/gen build/obj build/m && cp $2 build/m/AndroidManifest.xml
  aapt package -f -m --auto-add-overlay --custom-package app.rox.mobile -J build/gen -M build/m/AndroidManifest.xml -S variants/$1/res -S res -I $SDK
  javac -nowarn -source 8 -target 8 -bootclasspath $SDK -d build/obj build/gen/app/rox/mobile/R.java src/app/rox/mobile/*.java
  dalvik-exchange --dex --output=build/classes.dex build/obj
  aapt package -f --auto-add-overlay -0 wasm -0 gz -0 apk -M build/m/AndroidManifest.xml -S variants/$1/res -S res ${4:+-A $4} -I $SDK -F build/u.apk
  (cd build && aapt add u.apk classes.dex >/dev/null && zipalign -f 4 u.apk a.apk)
  apksigner sign --ks rox.keystore --ks-pass pass:roxpass --out $3 build/a.apk; rm -f $3.idsig; rm -rf build; echo "-> $3"
}
# TV: reads the screen, OCR (tesseract) + translation + dictionary -> everything except the TV apk itself
rm -rf .a && mkdir -p .a/tv .a/phone/www && cp -r assets/www assets/data .a/tv/
build tv AndroidManifest-tv.xml ROX-TV.apk .a/tv
# phone: the remote. It only needs its own page and the TV app to hand to Downloader
cp assets/www/app.html assets/www/icon.svg .a/phone/www/ && cp ROX-TV.apk .a/phone/tv.apk
build phone AndroidManifest.xml ROX-Phone.apk .a/phone
rm -rf .a
