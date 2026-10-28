# ServicesFactory Swift package: github.com/RichFell/kitlist-ios-services (label: servicesfactory)
GH_REPO="RichFell/kitlist-ios-services"
BASE_BRANCH="main"        # branch from and open PRs against main
# Builds and tests run on macOS, so no simulator is needed.
PROFILE_ALLOW=(
  "Bash(swift build*)" "Bash(swift test*)" "Bash(swift package resolve*)"
  "Bash(swift package update*)" "Bash(swift package describe*)" "Bash(swift package show-dependencies*)"
  "Bash(swiftlint*)"
)
PROFILE_DENY=(
  "Bash(swift package registry*)" "Bash(swift package-registry*)"
)
device_up() { :; }
device_down() { :; }
prepare_worktree() { :; }
