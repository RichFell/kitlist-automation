# Android app: github.com/RichFell/kitlist-android (label: android)
GH_REPO="RichFell/kitlist-android"
BASE_BRANCH="develop"     # PRs target develop; releases go to the default branch by hand
PHONE_AVD=""              # empty = first AVD whose name doesn't contain "wear"
USE_FIGMA=1               # keep the claude.ai Figma connector for design checks
USE_SUBAGENTS=1           # let the implement phase survey this large repo with Explore subagents
PROFILE_ALLOW=( "Bash(./gradlew *)" "Bash(adb *)" )
PROFILE_DENY=( "Bash(adb emu kill*)" "Bash(adb * emu kill*)" "Bash(adb reboot*)" "Bash(adb * reboot*)" "Bash(./gradlew publish*)" )
device_up() {
  if has_target android; then
    [ -n "$PHONE_AVD" ] || PHONE_AVD="$(emulator -list-avds 2>/dev/null | grep -vi wear | head -1)"
    start_emulator "$PHONE_AVD" 5554 phone || return 1
  fi
}
device_down() { stop_started_emulators; }
prepare_worktree() {
  # local.properties is gitignored; Gradle needs it to find the SDK.
  [ -f "$WT/local.properties" ] || printf 'sdk.dir=%s\n' "$ANDROID_HOME" > "$WT/local.properties"
}
