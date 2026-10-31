---
name: ui-test
description: Use when writing or running UI tests for the BanhApp iOS or Android app: XCUITest on a ddagent simulator lane, Compose UI tests on an Android emulator, stub backend, screenshots and the evidence report
---

# UI tests for iOS and Android

UI tests prove that a screen state from `docs/design/<feature>-ui.md` is reachable and looks right. They never call a real backend: the app starts against a stub fed from `contracts/fixtures/*.json`, so iOS and Android are checked against the same contract.

## Before you start

1. Read the UI states of the screens in scope (`docs/design/place-order-ui.md`) and the matching plan cases (`docs/test/place-order-tests.md`, sections 4.2 iOS and 4.3 Android). Every UI test names the plan case (TC-xxx) and the state (Loading, Empty, Error, Offline, Content) it covers.
2. Use accessibility identifiers (iOS) and `testTag` (Android) taken from one list in the UI document; never find elements by visible Vietnamese text, so a copy change does not break tests.
3. The stub backend is chosen by a launch argument (iOS `-uiTestStub <fixture name>`) or a debug-only instrumentation argument (Android). Release builds must not contain the stub switch.

## iOS: ddagent lane

It is installed globally; if the command is missing, add `$(npm prefix -g)/bin` to `PATH`. It needs `DEVELOPER_DIR` pointing at a full Xcode (26.x or 27; the project format is 77) and at least `DDAGENT_MIN_FREE_GB` of free disk (default 5; check `df -g /`).

```
export PATH="$(npm prefix -g)/bin:$PATH"
export DEVELOPER_DIR=/Applications/<Xcode>.app/Contents/Developer
LANE=$(ddagent lane acquire --owner <agent-name> --target "iPhone 17")   # any installed iPhone, iOS 17.5 or later
ddagent run --lane $LANE --project ios/BanhApp.xcodeproj --scheme BanhApp
ddagent lane release $LANE                                                # always, even on failure
```

`ddagent run` builds, installs and launches the app on the lane's simulator (open the window with `open -a Simulator`); it does not run XCUITest. Verified on this host: `ddagent run` on iPhone 17 (build 13.7 s, install and launch about 2 s). Running the XCUITest bundle needs `xcodebuild test`, which the host hook blocks (it points to `~/.cache/derived-data-pool/bin/dd-build.sh`, which is wired to the FPTPlay workspace and wants 20 GiB free, so it cannot build this project): never bypass the hook, run the tests in CI and report that the local XCUITest run was not possible.

Rules: one lane per agent, at most four lanes at once (shared by iOS and Android), always release. If ddagent reports no free disk or no simulator, say so in the report and rely on the CI run (`.github/workflows/ios.yml`, hosted macOS runner) as the evidence; never claim a UI test passed without a real run.

Test code lives in `ios/BanhAppUITests`. Use `XCTAttachment` screenshots for each state and name them `<TC id>-<state>`.

## Android: ddagent lane (existing AVDs)

Android lanes are in ddagent pull request cuongtq4998/ddagent#3 (`feat/android-lanes`, still open when this was written); until it is merged and reinstalled, run it from a clone of that branch (`node <clone>/bin/ddagent ...`) and isolate it from an older running daemon with `DDAGENT_HOME=<dir> DDAGENT_PORT=<free port>`. The android project must have a Gradle wrapper (`android/gradlew`, Gradle 9.6.0).

```
export JAVA_HOME=/opt/homebrew/opt/openjdk@17 ANDROID_HOME=$HOME/Library/Android/sdk
ddagent doctor --platform android          # needs JDK 17+, Android SDK, adb, emulator, one AVD; report any FAIL
LANE=$(ddagent lane acquire --platform android --owner <agent-name> --target Medium_Phone_API_36.1)
ddagent run --lane $LANE --project android --module app --task connectedDebugAndroidTest
ddagent lane release $LANE                  # always, even on failure
```

Allowed tasks: `assembleDebug` and `connectedDebugAndroidTest`. The run prints test counts and an `artifacts:` folder (junit XML, `logcat.txt`, a final screenshot, `gradle.log`); attach the real counts and path to the evidence report. Verified on this host: doctor, lane acquire, emulator boot (about 20 to 40 s), `assembleDebug` (about 5 min first build), `connectedDebugAndroidTest` (28 Compose UI tests, 0 failures; ddagent's summary line counts per class, so read the number from the junit XML) and release. To watch the run, set `DDAGENT_ANDROID_WINDOW=1` (shows the emulator window) or start the AVD yourself with `emulator -avd <name>`: an emulator that was already running is reused and never killed. The espresso-core 3.7.0 test dependency is needed on API 36.

Compose UI tests use `createComposeRule`, `testTag` selectors (`app/banh/customer/TestTags.kt`) and the same fixtures from `contracts/fixtures` (copied into the test assets by a Gradle task, not duplicated by hand). Keep emulator tests on the minimum supported level (API 26) and one recent level (API 31 or later) in CI.

## Evidence report (always)

End every UI-test task with a checklist in the chat:

- [ ] Plan cases covered (TC ids), states covered per screen
- [ ] Platform, device and OS version, commit id
- [ ] Command run and its real result (passed, failed, skipped counts)
- [ ] Screenshots attached or their path
- [ ] Not verified, with the reason (no disk, no JDK, no runner)

Failures are routed like any QA defect (`docs/process/README.md`, Loops): code defect to forge-dev, document gap to the owning agent.
