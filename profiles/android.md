ListApp Android repo (Kotlin, Jetpack Compose, MVVM with coordinators): the phone app and, as it's added, the Wear OS app. The emulators already running are listed in `{{RUN_DIR}}/devices.txt` (`phone` and/or `watch` with their adb serials). Always pass `-s <serial>` to adb.

- Build: `./gradlew assembleDebug` (all modules). Unit tests: `./gradlew testDebugUnitTest`. Lint: `./gradlew lintDebug`.
- Wear OS (when the ticket targets wearos): the watch app is its own Gradle module (see `settings.gradle.kts` and CLAUDE.md; e.g. `./gradlew :wear:assembleDebug`). If the ticket targets wearos and no wear module exists yet, create it only if the ticket asks for that; otherwise report blocked.

Screenshots (required for any visible UI change, on each platform the ticket targets):
- Build the APK (`./gradlew :app:assembleDebug`, or the wear module's), then install it on the right emulator with `adb -s <serial> install -r <path to apk>` (APKs land in `<module>/build/outputs/apk/debug/`).
- Open the screen, preferably by deep link: `adb -s <serial> shell am start -W -a android.intent.action.VIEW -d "listapp://<path>" <package>`, or launch the main activity and navigate with `adb -s <serial> shell input`.
- Capture with `adb -s <serial> exec-out screencap -p > {{RUN_DIR}}/screenshots/01-<screen>.png`; name Wear OS shots `watch-01-<screen>.png`.
- Capture dark mode on the phone too (`adb -s <serial> shell cmd uimode night yes`, then set it back to `no`) if the ticket touches colors or theming.
