# ServicesFactory Swift package: github.com/RichFell/ServicesFactory (label: servicesfactory)
GH_REPO="RichFell/ServicesFactory"
BASE_BRANCH="develop"     # PRs target develop; releases go to main by hand
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
