Kitlist iOS repo (SwiftUI, MVVM-C): the iOS app. Xcode's MCP tools are not available in unattended runs; use `xcodebuild` and `xcrun` directly. Find scheme names with `xcodebuild -list -project Kitlist.xcodeproj`; CLAUDE.md wins if it names them.

- iOS build: `xcodebuild -project Kitlist.xcodeproj -scheme Kitlist -destination 'platform=iOS Simulator,id=<phone id>' -derivedDataPath {{DERIVED_DATA}} -quiet build`. Always pass that `-derivedDataPath`: it is shared between runs, so builds start warm.
- iOS unit tests: same command with `test -only-testing:KitlistTests` instead of `build`.
- The project uses synchronized folders: create Swift files on disk and never edit `project.pbxproj` by hand.
- The `<phone id>` comes from `{{RUN_DIR}}/devices.txt`.
- Swift packages are already resolved. The ServicesFactory source the app builds against is in `{{DERIVED_DATA}}/SourcePackages/checkouts/ServicesFactory`, and the pinned version is in `Kitlist.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. Read its public API there; don't look for other checkouts or look versions up online.

Screenshots (required for any visible UI change):
- iOS: keep a UI test class `KitlistUITests/PRScreenshotTests.swift`. Add a test per screen this ticket changes that launches the app, navigates there (add accessibility identifiers where you need them), and attaches `XCUIScreen.main.screenshot()` as an `XCTAttachment` named like `01-lists-empty-state` with `lifetime = .keepAlways`. Run only those tests with `-only-testing:KitlistUITests/PRScreenshotTests/<testName>` and `-resultBundlePath {{RUN_DIR}}/screenshots.xcresult`, then `xcrun xcresulttool export attachments --path {{RUN_DIR}}/screenshots.xcresult --output-path {{RUN_DIR}}/xcresult-attachments` and copy the PNGs into `{{RUN_DIR}}/screenshots/` under their attachment names (the export's manifest.json maps files to names). Commit the screenshot tests; later tickets reuse them.
- Capture dark mode too if the ticket touches colors or theming.
