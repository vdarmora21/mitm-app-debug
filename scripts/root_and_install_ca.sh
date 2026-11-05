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
(cd "$ROOTAVD" && ./rootAVD.sh "$IMG/ramdisk.img" < /dev/null) 2>&1 | tee "$OUT/rootavd.log"
wait_exit

log "Second boot (rooted)"
start_emulator
adb shell pm list packages | grep -q com.topjohnwu.magisk || { echo "Magisk app missing" >&2; exit 1; }

log "Grant adb shell root via the Magisk prompt"
( adb shell su -c id > "$OUT/su-id.txt" 2>&1 ) &
SU_PID=$!
for _ in $(seq 1 30); do
  kill -0 $SU_PID 2>/dev/null || break
  tap_text 'grant' && break
  sleep 1
done
wait $SU_PID || true
cat "$OUT/su-id.txt"
grep -q 'uid=0' "$OUT/su-id.txt" || {
  adb exec-out screencap -p > "$OUT/su-prompt.png"
  adb exec-out cat /sdcard/ui.xml > "$OUT/su-prompt.xml" 2>/dev/null || true
  echo "Root was not granted" >&2; exit 1
}

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
