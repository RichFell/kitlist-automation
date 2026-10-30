Kitlist Android repo (Kotlin, Jetpack Compose, MVVM with coordinators): the phone app. The emulator already running is listed in `{{RUN_DIR}}/devices.txt` (`phone` with its adb serial). Always pass `-s <serial>` to adb.

- Verify with `scripts/check.sh` (build, unit tests and lint; prints only failures). `scripts/check.sh test` runs unit tests only. Single module: `app`.
- No screenshots: don't install the app or capture the screen.
