Kitlist iOS repo (SwiftUI, MVVM-C): the iOS app. Xcode's MCP tools are not available in unattended runs. Build, test and capture screenshots with the helpers below, run from the worktree root. They already know the simulator and the shared DerivedData, print only errors, failing tests and the result, and keep the full log in `{{RUN_DIR}}/logs/`. When you need more detail, grep that log instead of rerunning.

- Build: `{{SCRIPTS}}/ios-build.sh`
- Unit tests: `{{SCRIPTS}}/ios-test.sh` runs all of `KitlistTests`. Pass test IDs such as `KitlistTests/FlatEditorViewModelTests` to run only those.
- The app, `KitlistTests` and `KitlistUITests` all use synchronized folders: create Swift files on disk and never edit `project.pbxproj` by hand.
- Swift packages are already resolved. The ServicesFactory source the app builds against is in `{{DERIVED_DATA}}/SourcePackages/checkouts/ServicesFactory`, and the pinned version is in `Kitlist.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. List its files with Glob and read its public API there; don't look for other checkouts or look versions up online.

Screenshots (required for any visible UI change):
- Keep the UI test class `KitlistUITests/PRScreenshotTests.swift`. Add a test per screen this ticket changes that launches the app, navigates there (add accessibility identifiers where you need them), and attaches `XCUIScreen.main.screenshot()` as an `XCTAttachment` named like `01-lists-empty-state` with `lifetime = .keepAlways`. Commit the screenshot tests; later tickets reuse them.
- Capture with `{{SCRIPTS}}/ios-screenshots.sh <test name>...`, for example `ios-screenshots.sh test09FlatEditorWeight test10FlatEditorSuggestions`. It runs those tests and saves each attachment as `{{RUN_DIR}}/screenshots/<attachment name>.png`, so don't copy files yourself.
- If the ticket touches colors or theming, also run it with `--dark` first in the arguments. It uses the same tests in dark mode and adds a `-dark` suffix to the file names, so don't write separate dark-mode tests.
- To check a screenshot, Read the small copy in `{{RUN_DIR}}/screenshot-previews/`, and only the screens you need to confirm.
