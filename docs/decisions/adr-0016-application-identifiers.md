# ADR-0016: Application identifiers (Android application ID, iOS bundle id)

| Field    | Value |
| -------- | ----- |
| ADR      | 0016 |
| Version  | 1.0 [v1.0 \| 2026-10-26] |
| Status   | Accepted for development; frozen at the first store upload (see Decision) |
| Date     | 2026-10-26 |
| Decider  | atlas-architect (owner may override before the first store upload; non-blocking) |
| Based on | Slice 0 code: `android/app/build.gradle.kts`, `ios/BanhApp.xcodeproj/project.pbxproj`; dev-guide section 2 |

## Context

Slice 0 shipped the Android application ID `app.banh.customer` as a placeholder, and the iOS project still carries `com.cuongtran.BanhApp` (the Xcode template default, which embeds a personal name in a public repository). Both identifiers are compiled into the signed builds and registered in the stores. The Android application ID can never change after publication: Google Play treats a changed ID as a different app. The same is true in practice for the iOS bundle id (a changed id is a different app in App Store Connect). The identifiers are not shown to customers and need no domain registration (see Sources).

## Decision Drivers

- Hard to reverse after the first store upload; free to change until then.
- Public repository: no personal name or private account in an identifier.
- One name for both platforms, easy to explain in the dev guide and in store consoles.
- Not tied to a hosting provider or to the API host name (the host is a placeholder `<API_HOST>`, R-8).

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. `app.banh.customer` on both platforms (Android `namespace` and `applicationId`; iOS bundle id; tests `app.banh.customer.tests`, `app.banh.customer.uitests`) | Neutral, already used in all Kotlin packages, valid on both platforms, no personal data | Resembles a reverse domain `banh.app` that the shop may not own; harmless to the stores, which do not verify it |
| B. `com.cuongtran.BanhApp` on iOS and a different name on Android | No change now | Personal name in a public repository and in store listings of a business app; two names for one product |
| C. A reverse domain the owner registers (for example the shop's own) | Conventional; unique by construction | Costs money (domain); blocks development until the owner decides; the domain decision belongs to R-8 anyway |

## Decision

Option A. Android `namespace` and `applicationId` stay `app.banh.customer`; the iOS app, unit-test and UI-test bundle ids become `app.banh.customer`, `app.banh.customer.tests` and `app.banh.customer.uitests` (dev query to forge-dev). Kotlin packages follow the namespace. The ids freeze when the first build is uploaded to Play internal testing or TestFlight; until then they may change by pull request. If the owner prefers a reverse domain of their own (option C), they must say so before the store accounts are created; this does not block development. The identifiers are not secrets and stay in the repository.

## Consequences

- Positive: no personal name in the repository identifiers; one name on both stores; no cost.
- Negative: if the id is already taken on a store (collision is possible because nothing is reserved), registration fails and a new id must be chosen before launch; none is known to be taken (unchecked).
- Follow-up: forge-dev updates `PRODUCT_BUNDLE_IDENTIFIER` and removes `DEVELOPMENT_TEAM` from `project.pbxproj` into a git-ignored local xcconfig (dev query, architecture.md section 14); dev-guide section 2 drops "placeholder".

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Application ID needs at least two segments, letters, digits and underscores; it identifies the app on the device and in Google Play; never change it after publishing, or Play treats the upload as a new app | https://developer.android.com/build/configure-app-module | 2026-10-26 | High |
| The reverse-domain convention is not required or verified by Play | Same page does not mention it | 2026-10-26 | Medium (absence in the page) |
| Apple bundle id uniqueness and permanence in App Store Connect | Apple documentation, not fetched | 2026-10-26 | Unverified |
| `app.banh.customer` is free on both stores | Not checked | 2026-10-26 | Unverified |

## Links

Related: ADR-0004, ADR-0005, ADR-0007; deployment.md section 4 (store submission); architecture.md risk R-8.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-26 | First version. |
