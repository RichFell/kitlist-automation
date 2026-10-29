Kitlist Android repo (Kotlin, Jetpack Compose, MVVM with coordinators): the phone app. The emulator already running is listed in `{{RUN_DIR}}/devices.txt` (`phone` with its adb serial). Always pass `-s <serial>` to adb.

- Verify with `scripts/check.sh` (build, unit tests and lint; prints only failures). `scripts/check.sh test` runs unit tests only. Single module: `app`.

Screenshots (required for any visible UI change):
- After `scripts/check.sh build`, install with `adb -s <serial> install -r app/build/outputs/apk/debug/app-debug.apk`. The package is `app.kitlist.android`.
- Open the screen by deep link: `adb -s <serial> shell am start -W -a android.intent.action.VIEW -d "kitlist://<path>" app.kitlist.android`. Top-level paths are the `deepLinkPath` values in `ui/navigation/TopLevelDestination.kt`; deeper paths are in each feature coordinator's `resolve`. If there is no link, launch `app.kitlist.android/.MainActivity` and navigate with `adb -s <serial> shell input`.
- Capture with `adb -s <serial> exec-out screencap -p > {{RUN_DIR}}/screenshots/01-<screen>.png`.
- Capture dark mode too (`adb -s <serial> shell cmd uimode night yes`, then set it back to `no`) if the ticket touches colors or theming.
