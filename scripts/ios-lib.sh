# Shared by the ios-*.sh helpers that Claude runs from the worktree root during a
# ticket. run_claude exports KITLIST_RUN_DIR and KITLIST_DERIVED_DATA. Each helper
# keeps the full xcodebuild log in RUN_DIR/logs and prints only a short summary, so
# Claude doesn't rerun a build just to see output that a grep filter dropped.
set -u
[ -n "${KITLIST_RUN_DIR:-}" ] && [ -n "${KITLIST_DERIVED_DATA:-}" ] ||
  { echo "KITLIST_RUN_DIR and KITLIST_DERIVED_DATA aren't set; these helpers run inside the ticket runner."; exit 2; }
[ -d Kitlist.xcodeproj ] || { echo "Run this from the worktree root (Kitlist.xcodeproj not found)."; exit 2; }
SIM_ID="$(awk '$1 == "phone" { print $2; exit }' "$KITLIST_RUN_DIR/devices.txt" 2>/dev/null)"
[ -n "$SIM_ID" ] || { echo "No phone simulator listed in $KITLIST_RUN_DIR/devices.txt."; exit 2; }
LOG_DIR="$KITLIST_RUN_DIR/logs"
mkdir -p "$LOG_DIR"

# new_log NAME -> a fresh numbered log path, e.g. logs/test-3.log
new_log() {
  local n=1
  while [ -e "$LOG_DIR/$1-$n.log" ]; do n=$((n + 1)); done
  echo "$LOG_DIR/$1-$n.log"
}

xcb() {
  xcodebuild -project Kitlist.xcodeproj -scheme Kitlist -destination "platform=iOS Simulator,id=$SIM_ID" \
    -derivedDataPath "$KITLIST_DERIVED_DATA" "$@"
}

# Compiler errors and failing tests (XCTest and Swift Testing) from a log.
print_failures() {
  grep -E '(error|fatal error): ' "$1" | sort -u | head -30
  grep -E "Test Case '.*' failed|✘ " "$1" | sort -u | head -30
}

# Test counts from a log. Prints nothing when no test ran.
print_test_summary() {
  grep -E 'Executed [0-9]+ tests?' "$1" | tail -1
  grep -E 'Test run with [0-9]+ tests?' "$1" | tail -1
}

tests_ran() { grep -qE 'Executed [1-9][0-9]* tests?|Test run with [1-9][0-9]* tests?' "$1"; }
