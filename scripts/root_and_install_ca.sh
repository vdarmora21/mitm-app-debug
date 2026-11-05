#!/usr/bin/env bash
# Roots a Play Store AVD with Magisk (rootAVD), grants adb shell root, installs the
# CA module and reboots. Expects mitmproxy's CA in ~/.mitmproxy already.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/lib.sh"
: "${API:=34}" "${TARGET:=google_apis_playstore}" "${AVD:=mitm}" "${OUT:=out}"
ROOTAVD_REF=613caa44371f85e1a461bc030e07ddc2d71afe32
IMG="system-images/android-$API/$TARGET/x86_64"
mkdir -p "$OUT"
# avdmanager and the emulator can disagree on the default AVD folder; pin it.
export ANDROID_AVD_HOME=${ANDROID_AVD_HOME:-$HOME/.android/avd}
mkdir -p "$ANDROID_AVD_HOME"

log "Install system image and create AVD"
yes | sdkmanager --licenses > /dev/null || true
sdkmanager --install "${IMG//\//;}" "emulator" "platform-tools" > /dev/null
echo no | avdmanager create avd --force -n "$AVD" -k "${IMG//\//;}" -d pixel_4

log "First boot (stock)"
start_emulator

log "Patch ramdisk with rootAVD"
ROOTAVD=$RUNNER_TEMP/rootAVD
[ -d "$ROOTAVD" ] || { git clone -q https://gitlab.com/newbit/rootAVD.git "$ROOTAVD"; git -C "$ROOTAVD" checkout -q "$ROOTAVD_REF"; }
# stdin from /dev/null answers every prompt with its default (Magisk stable).
(cd "$ROOTAVD" && timeout 600 ./rootAVD.sh "$IMG/ramdisk.img" < /dev/null) 2>&1 | tee "$OUT/rootavd.log"
wait_exit

log "Second boot (rooted)"
start_emulator
adb shell pm list packages | grep -q com.topjohnwu.magisk || { echo "Magisk app missing" >&2; exit 1; }

log "Open Magisk once so it can finish setup"
adb shell pm grant com.topjohnwu.magisk android.permission.POST_NOTIFICATIONS || true
adb shell monkey -p com.topjohnwu.magisk -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
sleep 15
tap_text 'Allow' && sleep 3
dump_texts
# "Requires additional setup" -> OK reboots the device.
if tap_text 'OK'; then
  echo "Magisk asked for additional setup, waiting for reboot" >&2
  # Wait until the device has actually gone down before waiting for it to come back.
  timeout 90 sh -c 'while adb shell true 2>/dev/null; do sleep 2; done' || true
  wait_boot
  sleep 30; dismiss_anr
  adb shell monkey -p com.topjohnwu.magisk -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
  sleep 15; dismiss_anr; dump_texts
fi
adb shell 'su -v; su -V' >&2 || true

log "Grant adb shell root via the Magisk prompt"
for attempt in 1 2 3; do
  ( timeout 60 adb shell su -c id > "$OUT/su-id.txt" 2>&1 ) &
  SU_PID=$!
  for _ in $(seq 1 30); do
    kill -0 $SU_PID 2>/dev/null || break
    tap_text 'grant' && break
    dismiss_anr
    sleep 1
  done
  wait $SU_PID || true
  echo "attempt $attempt: $(cat "$OUT/su-id.txt")" >&2
  grep -q 'uid=0' "$OUT/su-id.txt" && break
  dump_texts
  sleep 5
done
grep -q 'uid=0' "$OUT/su-id.txt" || { adb logcat -d | grep -iE 'magisk|\bsu\b' | tail -60 >&2; adb exec-out screencap -p > "$OUT/su-prompt.png"; echo "Root was not granted" >&2; exit 1; }

log "Install CA module"
bash "$HERE/../build_module.sh" "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" "$OUT/user-ca-mitm.zip"
adb push "$OUT/user-ca-mitm.zip" /data/local/tmp/
adb shell su -c 'magisk --install-module /data/local/tmp/user-ca-mitm.zip'

log "Reboot with the module"
adb reboot || true
wait_boot
sleep 20  # service.sh mounts the APEX certs after boot_completed

HASH=$(openssl x509 -inform PEM -subject_hash_old -in "$HOME/.mitmproxy/mitmproxy-ca-cert.pem" -noout)
if [ "$API" -ge 34 ]; then CA_DIR=/apex/com.android.conscrypt/cacerts; else CA_DIR=/system/etc/security/cacerts; fi
adb shell "ls $CA_DIR/$HASH.0" && echo "CA is in the system store ($CA_DIR)"
