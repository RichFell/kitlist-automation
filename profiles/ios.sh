# iOS app: github.com/RichFell/kitlist-ios (label: ios)
GH_REPO="RichFell/kitlist-ios"
BASE_BRANCH="develop"     # PRs target develop; releases go to master by hand
SIM_NAME="iPhone 18 Pro"  # keep in sync with .claude/hooks/stop-build-check.sh
USE_FIGMA=1               # keep the claude.ai Figma connector for design checks
USE_SUBAGENTS=1           # let the implement phase survey this large repo with Explore subagents
PROFILE_ALLOW=(
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
prepare_worktree() { :; }
