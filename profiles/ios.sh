# iOS app: github.com/RichFell/kitlist-ios (label: ios)
GH_REPO="RichFell/kitlist-ios"
BASE_BRANCH="develop"     # PRs target develop; releases go to master by hand
SIM_NAME="iPhone 18 Pro"  # keep in sync with .claude/hooks/stop-build-check.sh
USE_FIGMA=1               # keep the claude.ai Figma connector when the ticket links a figma.com design
USE_SUBAGENTS=1           # let the implement phase survey this large repo with Explore subagents
DERIVED_DATA="$STATE_DIR/derived-data/kitlist-ios"  # shared by every run, so builds start warm
PROFILE_ALLOW=(
  "Bash($HERE/scripts/ios-build.sh*)" "Bash($HERE/scripts/ios-test.sh*)" "Bash($HERE/scripts/ios-screenshots.sh*)"
  "Bash(xcodebuild *)" "Bash(xcrun simctl *)" "Bash(xcrun xcresulttool *)"
  "Bash(swift build*)" "Bash(swift test*)" "Bash(swiftlint*)" "Bash(plutil *)"
)
PROFILE_DENY=(
  "Bash(xcodebuild archive*)" "Bash(xcodebuild -exportArchive*)" "Bash(xcrun simctl erase*)"
)
device_up() {
  if has_target ios; then boot_sim "$SIM_NAME" phone || return 1; fi
}
device_down() { shutdown_booted_sims; }
prepare_worktree() {
  # Resolve packages before Claude starts, so it can read the ServicesFactory
  # source it builds against instead of hunting for it.
  xcodebuild -resolvePackageDependencies -project "$WT/Kitlist.xcodeproj" -scheme Kitlist -derivedDataPath "$DERIVED_DATA" >>"$LOG_FILE" 2>&1 ||
    log "$KEY: warning: couldn't resolve Swift packages; the build will retry"
}
