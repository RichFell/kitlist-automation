# Simulator and emulator lifecycle. Each run only shuts down what it started.
# Every device a run uses is listed in $RUN_DIR/devices.txt as "<role> <id or serial> <name>",
# which is how Claude finds which simulator or emulator to target.

has_target() { case " $TARGETS " in *" $1 "*) return 0 ;; esac; return 1; }

# boot_sim NAME ROLE
boot_sim() {
  local name="$1" role="$2" udid
  udid="$(xcrun simctl list devices available | grep -m1 -F "    $name (" | grep -oE '[0-9A-F-]{36}')"
  [ -n "$udid" ] || { log "$KEY: no simulator named \"$name\""; return 1; }
  if ! xcrun simctl list devices booted | grep -q "$udid"; then
    xcrun simctl boot "$udid" >/dev/null 2>&1 || { log "$KEY: couldn't boot \"$name\""; return 1; }
    echo "$udid" >> "$RUN_DIR/.booted-sims"
  fi
  xcrun simctl bootstatus "$udid" >/dev/null 2>&1 || true
  echo "$role $udid $name" >> "$RUN_DIR/devices.txt"
}
shutdown_booted_sims() {
  local udid
  [ -f "$RUN_DIR/.booted-sims" ] || return 0
  while read -r udid; do xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true; done < "$RUN_DIR/.booted-sims"
  rm -f "$RUN_DIR/.booted-sims"
}

# start_emulator AVD PORT ROLE
start_emulator() {
  local avd="$1" port="$2" role="$3" serial="emulator-$2" i
  [ -n "$avd" ] || { log "$KEY: no $role AVD found; create one in Android Studio's Device Manager"; return 1; }
  if ! adb devices 2>/dev/null | grep -q "^$serial[[:space:]]*device$"; then
    nohup emulator -avd "$avd" -port "$port" -no-window -no-audio -no-boot-anim -no-snapshot-save \
      >"$RUN_DIR/emulator-$role.log" 2>&1 &
    echo "$serial" >> "$RUN_DIR/.started-emulators"
    adb -s "$serial" wait-for-device
  fi
  for i in $(seq 1 120); do
    if [ "$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then
      echo "$role $serial $avd" >> "$RUN_DIR/devices.txt"; return 0
    fi
    sleep 2
  done
  log "$KEY: $role emulator ($avd) didn't finish booting"; return 1
}
stop_started_emulators() {
  local serial
  [ -f "$RUN_DIR/.started-emulators" ] || return 0
  while read -r serial; do adb -s "$serial" emu kill >/dev/null 2>&1 || true; done < "$RUN_DIR/.started-emulators"
  rm -f "$RUN_DIR/.started-emulators"
}
