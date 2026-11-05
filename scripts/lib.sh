# Shared helpers for the emulator scripts.
EMU_OPTS=${EMU_OPTS:-"-no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -camera-back none -no-snapshot"}

log() { echo "::group::$*" >&2; echo "[$(date +%T)] $*" >&2; echo "::endgroup::" >&2; }

start_emulator() {
  "$ANDROID_HOME/emulator/emulator" -avd "$AVD" $EMU_OPTS > "$OUT/emulator-$(date +%s).log" 2>&1 &
  EMU_PID=$!
  wait_boot
}

wait_boot() {
  adb wait-for-device
  local t=0
  until [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do
    sleep 2; t=$((t + 2))
    [ $t -lt 300 ] || { echo "Boot timed out" >&2; return 1; }
  done
  adb shell input keyevent 82 || true
  sleep 5
}

# Wait for the emulator process to exit on its own (rootAVD shuts it down).
wait_exit() {
  local t=0
  while kill -0 "$EMU_PID" 2>/dev/null; do
    sleep 2; t=$((t + 2))
    if [ $t -ge 120 ]; then adb emu kill || true; sleep 5; fi
    [ $t -lt 180 ] || { kill -9 "$EMU_PID" || true; break; }
  done
}

# Tap the first on-screen node whose text matches $1 (case-insensitive).
tap_text() {
  adb shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1 || return 1
  local b
  b=$(adb exec-out cat /sdcard/ui.xml | grep -oiE "text=\"$1\"[^>]*bounds=\"\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]\"" | head -1 | grep -oE '\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]') || return 1
  [ -n "$b" ] || return 1
  set -- $(echo "$b" | tr '[],' '   ')
  adb shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 ))
}
