# iOS + watchOS apps: github.com/RichFell/ListApp (labels: ios, watchos)
GH_REPO="RichFell/ListApp"
BASE_BRANCH="develop"     # PRs target develop; releases go to master by hand
SIM_NAME="iPhone 17 Pro"  # keep in sync with .claude/hooks/stop-build-check.sh
WATCH_SIM_NAME=""         # empty = first available Apple Watch simulator
PROFILE_ALLOW=(
  "Bash(xcodebuild *)" "Bash(xcrun simctl *)" "Bash(xcrun xcresulttool *)"
  "Bash(swift build*)" "Bash(swift test*)" "Bash(swiftlint*)" "Bash(plutil *)"
)
PROFILE_DENY=(
  "Bash(xcodebuild archive*)" "Bash(xcodebuild -exportArchive*)" "Bash(xcrun simctl erase*)"
)
device_up() {
  if has_target ios; then boot_sim "$SIM_NAME" phone || return 1; fi
  if has_target watchos; then
    [ -n "$WATCH_SIM_NAME" ] || WATCH_SIM_NAME="$(first_watch_sim)"
    [ -n "$WATCH_SIM_NAME" ] || { log "$KEY: no Apple Watch simulator installed"; return 1; }
    boot_sim "$WATCH_SIM_NAME" watch || return 1
  fi
}
device_down() { shutdown_booted_sims; }
prepare_worktree() { :; }
