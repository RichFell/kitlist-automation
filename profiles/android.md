ListApp Android repo (Kotlin, Jetpack Compose, MVVM with coordinators): the phone app. The emulator already running is listed in `{{RUN_DIR}}/devices.txt` (`phone` with its adb serial). Always pass `-s <serial>` to adb.

- Build: `./gradlew assembleDebug` (all modules). Unit tests: `./gradlew testDebugUnitTest`. Lint: `./gradlew lintDebug`.

Screenshots (required for any visible UI change):
- Build the APK (`./gradlew :app:assembleDebug`), then install it on the emulator with `adb -s <serial> install -r <path to apk>` (APKs land in `<module>/build/outputs/apk/debug/`).
- Open the screen, preferably by deep link: `adb -s <serial> shell am start -W -a android.intent.action.VIEW -d "listapp://<path>" <package>`, or launch the main activity and navigate with `adb -s <serial> shell input`.
- Capture with `adb -s <serial> exec-out screencap -p > {{RUN_DIR}}/screenshots/01-<screen>.png`.
- Capture dark mode too (`adb -s <serial> shell cmd uimode night yes`, then set it back to `no`) if the ticket touches colors or theming.
