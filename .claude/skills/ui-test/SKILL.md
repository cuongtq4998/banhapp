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

## iOS: ddagent lane (iPhone simulators only)

ddagent drives iOS and iPadOS simulators only. It is installed globally; if the command is missing, add `$(npm prefix -g)/bin` to `PATH`. It needs `DEVELOPER_DIR` pointing at a full Xcode (26.x or 27; the project format is 77) and at least `DDAGENT_MIN_FREE_GB` of free disk (default 20; check `df -g /`).

```
export PATH="$(npm prefix -g)/bin:$PATH"
export DEVELOPER_DIR=/Applications/<Xcode>.app/Contents/Developer
LANE=$(ddagent lane acquire --owner <agent-name> --target "iPhone 17")   # any installed iPhone, iOS 17.5 or later
ddagent run --lane $LANE --project ios/BanhApp.xcodeproj --scheme BanhApp
ddagent lane release $LANE                                                # always, even on failure
```

Rules: one lane per agent, at most four lanes at once, always release. Do not run raw `xcodebuild`; the host hook blocks it and ddagent is the supported route. If ddagent reports no free disk or no simulator, say so in the report and rely on the CI run (`.github/workflows/ios.yml`, hosted macOS runner) as the evidence; never claim a UI test passed without a real run.

Test code lives in `ios/BanhAppUITests`. Use `XCTAttachment` screenshots for each state and name them `<TC id>-<state>`.

## Android: emulator

ddagent does not drive Android. Use the emulator and Gradle:

```
~/Library/Android/sdk/emulator/emulator -list-avds              # for example Medium_Phone_API_36.1
~/Library/Android/sdk/emulator/emulator -avd <name> -no-snapshot-save &
~/Library/Android/sdk/platform-tools/adb wait-for-device
cd android && gradle :app:connectedDebugAndroidTest             # needs JDK 17 and Gradle 9.6.0
```

The host currently has no JDK, so the local run is blocked; CI is the evidence until JDK 17 is installed. Compose UI tests live in `android/app/src/androidTest`, use `createAndroidComposeRule`, `testTag` selectors and the same fixtures (copied into the test assets by a Gradle task from `contracts/fixtures`, not duplicated by hand). Keep emulator tests on the minimum supported level (API 26) and one recent level (API 31 or later) in CI.

## Evidence report (always)

End every UI-test task with a checklist in the chat:

- [ ] Plan cases covered (TC ids), states covered per screen
- [ ] Platform, device and OS version, commit id
- [ ] Command run and its real result (passed, failed, skipped counts)
- [ ] Screenshots attached or their path
- [ ] Not verified, with the reason (no disk, no JDK, no runner)

Failures are routed like any QA defect (`docs/process/README.md`, Loops): code defect to forge-dev, document gap to the owning agent.
