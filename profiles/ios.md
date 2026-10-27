ListApp Apple repo (SwiftUI, MVVM-C): the iOS app and, as it's added, the watchOS app. Xcode's MCP tools are not available in unattended runs; use `xcodebuild` and `xcrun` directly. Find scheme names with `xcodebuild -list -project ListApp.xcodeproj`; CLAUDE.md wins if it names them.

- iOS build: `xcodebuild -project ListApp.xcodeproj -scheme ListApp -destination 'platform=iOS Simulator,id=<phone id>' build`
- iOS unit tests: same command with `test -only-testing:ListAppTests` instead of `build`.
- watchOS (when the ticket targets watchos): build and test the watch scheme with `-destination 'platform=watchOS Simulator,id=<watch id>'`. If the ticket targets watchos but the project has no watch target yet, creating it means editing the Xcode project file, which isn't allowed; report blocked and say a human needs to add the target first.
- The project uses synchronized folders: create Swift files on disk and never edit `project.pbxproj` by hand.
- The `<phone id>` and `<watch id>` come from `{{RUN_DIR}}/devices.txt`.

Screenshots (required for any visible UI change, on each platform the ticket targets):
- iOS: keep a UI test class `ListAppUITests/PRScreenshotTests.swift`. Add a test per screen this ticket changes that launches the app, navigates there (add accessibility identifiers where you need them), and attaches `XCUIScreen.main.screenshot()` as an `XCTAttachment` named like `01-lists-empty-state` with `lifetime = .keepAlways`. Run only those tests with `-only-testing:ListAppUITests/PRScreenshotTests/<testName>` and `-resultBundlePath {{RUN_DIR}}/screenshots.xcresult`, then `xcrun xcresulttool export attachments --path {{RUN_DIR}}/screenshots.xcresult --output-path {{RUN_DIR}}/xcresult-attachments` and copy the PNGs into `{{RUN_DIR}}/screenshots/` under their attachment names (the export's manifest.json maps files to names). Commit the screenshot tests; later tickets reuse them.
- watchOS: same approach with the watch app's UI test target if it has one, named `watch-01-<screen>`. Without one, install and launch the watch app on the watch simulator (`xcrun simctl install <watch id> <app path>`, `xcrun simctl launch <watch id> <bundle id>`) and capture with `xcrun simctl io <watch id> screenshot {{RUN_DIR}}/screenshots/watch-01-<screen>.png`.
- Capture dark mode too if the ticket touches colors or theming (iOS only; watchOS is always dark).
