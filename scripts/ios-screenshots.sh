#!/bin/bash
# ios-screenshots.sh test01Foo test02Bar          light mode
# ios-screenshots.sh --dark test01Foo             dark mode; file names get a -dark suffix
# Runs those KitlistUITests/PRScreenshotTests tests, then saves each PNG attachment
# as RUN_DIR/screenshots/<attachment name>.png (what the PR shows) and a small copy
# in RUN_DIR/screenshot-previews/ that is cheaper to look at.
. "$(dirname "$0")/ios-lib.sh"

mode=light suffix=""
if [ "${1:-}" = --dark ]; then mode=dark suffix=-dark; shift; fi
[ $# -gt 0 ] || { echo "Usage: ios-screenshots.sh [--dark] <PRScreenshotTests test name>..."; exit 2; }
only=()
for t in "$@"; do only+=("-only-testing:KitlistUITests/PRScreenshotTests/$t"); done

# A new bundle name every run: xcodebuild refuses a -resultBundlePath that exists.
mkdir -p "$KITLIST_RUN_DIR/xcresults" "$KITLIST_RUN_DIR/screenshots" "$KITLIST_RUN_DIR/screenshot-previews"
bundle="$KITLIST_RUN_DIR/xcresults/screenshots-$mode-$(date +%H%M%S).xcresult"
log="$(new_log screenshots)"

xcrun simctl ui "$SIM_ID" appearance "$mode"
xcb test "${only[@]}" -resultBundlePath "$bundle" >"$log" 2>&1
rc=$?
[ "$mode" = light ] || xcrun simctl ui "$SIM_ID" appearance light
print_failures "$log"
print_test_summary "$log"
if ! tests_ran "$log"; then
  grep -qE 'error: ' "$log" || tail -20 "$log"
  echo "No screenshot tests ran. Check the test names, and that the tests compile. Full log: $log"
  exit 1
fi

out="$KITLIST_RUN_DIR/xcresults/export-$(basename "$bundle" .xcresult)"
xcrun xcresulttool export attachments --path "$bundle" --output-path "$out" >/dev/null 2>&1 ||
  { echo "Exporting attachments from $bundle failed."; exit 1; }

saved=0
while IFS="$(printf '\t')" read -r file name; do
  # "01-lists-empty_0_<UUID>.png" -> "01-lists-empty"
  name="$(printf '%s' "$name" | sed -E 's/(_[0-9]+_[0-9A-Fa-f-]+)?\.png$//' | tr ' ' '-')"
  cp "$out/$file" "$KITLIST_RUN_DIR/screenshots/$name$suffix.png" || continue
  sips -Z 800 "$out/$file" --out "$KITLIST_RUN_DIR/screenshot-previews/$name$suffix.png" >/dev/null 2>&1
  echo "saved screenshots/$name$suffix.png"
  saved=$((saved + 1))
done < <(jq -r '.[].attachments[] | select(.exportedFileName | endswith(".png"))
                | [.exportedFileName, .suggestedHumanReadableName] | @tsv' "$out/manifest.json")

if [ $saved -eq 0 ]; then
  echo "The tests attached no PNGs. Attach XCUIScreen.main.screenshot() with lifetime = .keepAlways."
  exit 1
fi
[ $rc -eq 0 ] || { echo "Some screenshot tests FAILED (exit $rc). Full log: $log"; exit $rc; }
echo "SCREENSHOTS SAVED: $saved"
