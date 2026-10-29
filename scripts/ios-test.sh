#!/bin/bash
# ios-test.sh                                   runs all unit tests (KitlistTests)
# ios-test.sh KitlistTests/FooTests [...]       runs only the given tests
# Prints compile errors, failing tests and the test counts; the full log path on failure.
. "$(dirname "$0")/ios-lib.sh"

[ $# -gt 0 ] || set -- KitlistTests
only=()
for t in "$@"; do only+=("-only-testing:$t"); done

log="$(new_log test)"
xcb test "${only[@]}" >"$log" 2>&1
rc=$?
print_failures "$log"
print_test_summary "$log"
if [ $rc -eq 0 ] && ! tests_ran "$log"; then
  echo "No tests ran. Check the test names: $*"
  exit 1
fi
if [ $rc -eq 0 ]; then
  echo "TESTS PASSED"
else
  grep -qE "error: |failed|✘ " "$log" || tail -20 "$log"
  echo "TESTS FAILED (exit $rc). Full log: $log"
fi
exit $rc
