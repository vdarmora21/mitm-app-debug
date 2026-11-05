#!/usr/bin/env bash
# Sends the device through mitmdump and opens an HTTPS page in Chrome.
set -euo pipefail
: "${OUT:=out}"
adb shell settings put global http_proxy 10.0.2.2:8080
adb shell am start -a android.intent.action.VIEW -d https://example.com -p com.android.chrome || true
sleep 10
# Dismiss Chrome's first-run screens if they show up, then reload.
for t in 'Use without an account' 'Accept & continue' 'No thanks' 'Got it'; do
  bash -c ". $(dirname "$0")/lib.sh; tap_text '$t'" || true; sleep 2
done
adb shell am start -a android.intent.action.VIEW -d https://example.com -p com.android.chrome || true
sleep 20
adb exec-out screencap -p > "$OUT/screen.png"
adb logcat -d > "$OUT/logcat.txt"
