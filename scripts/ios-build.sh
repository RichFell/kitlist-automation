#!/bin/bash
# ios-build.sh: builds the app for the run's simulator. Prints compiler errors,
# warnings in Kitlist's own sources, and the result; the full log path on failure.
. "$(dirname "$0")/ios-lib.sh"

log="$(new_log build)"
xcb -quiet build >"$log" 2>&1
rc=$?
print_failures "$log"
grep -E 'warning: ' "$log" | grep -E '/Kitlist(Tests|UITests)?/' | sort -u | head -15
if [ $rc -eq 0 ]; then
  echo "BUILD SUCCEEDED"
else
  grep -qE 'error: ' "$log" || tail -20 "$log"
  echo "BUILD FAILED (exit $rc). Full log: $log"
fi
exit $rc
