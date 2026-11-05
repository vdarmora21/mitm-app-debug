# Shared helpers for the emulator scripts.
EMU_OPTS=${EMU_OPTS:-"-no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -camera-back none -no-snapshot"}

log() { echo "::group::$*" >&2; echo "[$(date +%T)] $*" >&2; echo "::endgroup::" >&2; }

start_emulator() {
  EMU_LOG="$OUT/emulator-$(date +%s).log"
  "$ANDROID_HOME/emulator/emulator" -avd "$AVD" $EMU_OPTS > "$EMU_LOG" 2>&1 &
  EMU_PID=$!
  wait_boot || { echo "--- emulator log ---" >&2; tail -60 "$EMU_LOG" >&2; return 1; }
}

wait_boot() {
  timeout 180 adb wait-for-device || { echo "No device after 180s" >&2; return 1; }
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

# Print the visible on-screen texts (for logs).
dump_texts() {
  adb shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1 || return 0
  adb exec-out cat /sdcard/ui.xml | grep -oE 'text="[^"]+"' | head -20 >&2 || true
}

# Dismiss "X isn't responding" dialogs that slow software-rendered emulators show.
dismiss_anr() {
  local i
  for i in 1 2 3; do tap_text 'Wait' || return 0; sleep 2; done
}

# Tap the first node whose text, content-desc or resource-id contains $1.
tap_match() {
  adb shell uiautomator dump /sdcard/ui.xml > /dev/null 2>&1 || return 1
  local node b
  node=$(adb exec-out cat /sdcard/ui.xml | grep -oE '<node [^>]*>' | grep -iE "(text|content-desc|resource-id)=\"[^\"]*$1[^\"]*\"" | grep 'enabled="true"' | head -1)
  b=$(echo "$node" | grep -oE 'bounds="\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]"' | grep -oE '\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]')
  [ -n "$b" ] || return 1
  set -- $(echo "$b" | tr '[],' '   ')
  adb shell input tap $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 ))
}
