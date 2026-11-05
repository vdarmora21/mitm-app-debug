#!/usr/bin/env bash
# Runs inside the booted emulator job: routes the device through mitmdump on the
# runner (10.0.2.2 is the host as seen from the emulator) and collects evidence.
set -euo pipefail
OUT=${OUT:-out}
mkdir -p "$OUT"

adb wait-for-device
adb shell getprop ro.build.version.release > "$OUT/android-version.txt"
adb shell getprop ro.build.version.sdk >> "$OUT/android-version.txt"

adb shell settings put global http_proxy 10.0.2.2:8080
adb shell am start -a android.intent.action.VIEW -d http://example.com || true
sleep 30

adb exec-out screencap -p > "$OUT/screen.png"
adb logcat -d > "$OUT/logcat.txt"
adb shell settings put global http_proxy :0
