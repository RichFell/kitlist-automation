Kitlist iOS repo (SwiftUI, MVVM-C): the iOS app. Xcode's MCP tools are not available in unattended runs. Build and test with the helpers below, run from the worktree root. They already know the simulator and the shared DerivedData, print only errors, failing tests and the result, and keep the full log in `{{RUN_DIR}}/logs/`. When you need more detail, grep that log instead of rerunning.

- Build: `{{SCRIPTS}}/ios-build.sh`
- Unit tests: `{{SCRIPTS}}/ios-test.sh` runs all of `KitlistTests`. Pass test IDs such as `KitlistTests/FlatEditorViewModelTests` to run only those.
- The app, `KitlistTests` and `KitlistUITests` all use synchronized folders: create Swift files on disk.
- No screenshots: don't write or run screenshot UI tests.
- Swift packages are already resolved. The ServicesFactory source the app builds against is in `{{DERIVED_DATA}}/SourcePackages/checkouts/ServicesFactory`, and the pinned version is in `Kitlist.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`. List its files with Glob and read its public API there; don't look for other checkouts or look versions up online.
