# Android + Wear OS apps: github.com/RichFell/ListApp_Android (labels: android, wearos)
GH_REPO="RichFell/ListApp_Android"
BASE_BRANCH="develop"     # PRs target develop; releases go to the default branch by hand
PHONE_AVD=""              # empty = first AVD whose name doesn't contain "wear"
WEAR_AVD=""               # empty = first AVD whose name contains "wear"
PROFILE_ALLOW=( "Bash(./gradlew *)" "Bash(adb *)" )
PROFILE_DENY=( "Bash(adb emu kill*)" "Bash(adb * emu kill*)" "Bash(adb reboot*)" "Bash(adb * reboot*)" "Bash(./gradlew publish*)" )
device_up() {
  if has_target android; then
    [ -n "$PHONE_AVD" ] || PHONE_AVD="$(emulator -list-avds 2>/dev/null | grep -vi wear | head -1)"
    start_emulator "$PHONE_AVD" 5554 phone || return 1
  fi
  if has_target wearos; then
    [ -n "$WEAR_AVD" ] || WEAR_AVD="$(emulator -list-avds 2>/dev/null | grep -i wear | head -1)"
    start_emulator "$WEAR_AVD" 5556 watch || return 1
  fi
}
device_down() { stop_started_emulators; }
prepare_worktree() {
  # local.properties is gitignored; Gradle needs it to find the SDK.
  [ -f "$WT/local.properties" ] || printf 'sdk.dir=%s\n' "$ANDROID_HOME" > "$WT/local.properties"
}
