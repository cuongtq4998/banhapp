# ADR-0021: Admin apps in the monorepo and how code is shared

| Field    | Value |
| -------- | ----- |
| ADR      | 0021 |
| Version  | 1.0 |
| Status   | Accepted (no money, no customer data; reversible by moving folders) |
| Date     | 2026-10-31 |
| Decider  | atlas-architect |
| Based on | PRD admin-orders D-1, D-2; ADR-0004, ADR-0007, ADR-0018 v2.1; CLAUDE.md |

## Context

The admin app is a separate app on iOS and Android, built in this repository against the same backend (D-1, D-2). ADR-0018 named the trigger "a second app needs the design system or shared code" for both clients. That trigger has fired, so the package extraction that ADR-0018 deferred starts now. The customer iOS project uses project format 77 and the scheme `BanhApp`; both must stay (hosted CI has Xcode 26.x only).

## Decision Drivers

- The customer app release must not be put at risk by admin work.
- Share only what two apps really share: design tokens and components, money and date formatting, the HTTP client and error envelope, contract types.
- Keep project format 77, scheme `BanhApp`, and the 200-line rule.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. A second target and scheme inside `BanhApp.xcodeproj` | One project file | Hand edits of one large project file by two parallel agents; customer scheme and CI share its fate |
| B. A second Xcode project `ios/BanhAdmin.xcodeproj` (format 77) beside the first, both using local packages in `ios/Packages/` (chosen) | Customer project untouched; separate CI path filter; packages are the only shared code | Two project files; package extraction must come first |
| C. Copy the needed code into the admin app | No extraction | Two diverging copies of the design system |
| D. Android: separate Gradle build in `android-admin/` | Isolation | Cannot share modules without publishing; duplicate wrapper and versions |

## Decision

Option B for iOS and a multi-module Gradle build for Android.

- iOS: `ios/BanhAdmin/` (app), `ios/BanhAdminTests/`, `ios/BanhAdminUITests/`, `ios/BanhAdmin.xcodeproj` (format 77, scheme `BanhAdmin`). Local packages in `ios/Packages/`: `BanhDesign` (tokens, components, fonts handling stays in each app), `BanhCore` (money and date formatting, `Load` state, HTTP client with the error envelope, repository protocols). Both apps import them; `BanhContracts` (`contracts/swift/`) is extended with admin Codable types. Resources (strings, assets) stay in each app target (ADR-0018 `Bundle.module` rule). `package` access between targets, `public` at the boundary; `defaultIsolation` set per target as in ADR-0018.
- Android: `settings.gradle.kts` includes `:app` (customer, `app.banh.customer`), `:admin` (`app.banh.admin`), `:core:design`, `:core:common`, `:core:network`, `:core:model`, and `build-logic/` with convention plugins (four library modules reach the threshold of ADR-0018). A spike on `:core:design` with the Compose compiler plugin comes first (unverified, ADR-0018).
- Backend: unchanged target; no new top-level folder under `Sources/App` (the layering test fails on unknown folders). Admin code lives in `Routes/Admin/`, `Services/Admin/` (with `Auth`, `Orders`, `Settings`, `Mail`, `Push` subfolders), `Repositories/Admin/`; the HTTP clients of the mail and push providers live in `Http/Outbound/` because they use Vapor.
- Fixtures: `contracts/fixtures/admin/` for admin requests and responses (JSON, shared by the three suites).
- CI: new path-filtered `admin-ios.yml` and `admin-android.yml`; `ios.yml` and `android.yml` also trigger on `ios/Packages/**` and `android/core/**` respectively.

## Consequences

- Positive: the customer project and scheme do not move; one design system; packages get `swift test` without a simulator.
- Negative: extraction work before admin features; two Xcode projects to keep in step; Android Compose-in-library-module behaviour is unverified.
- Follow-up: forge-dev extracts packages as the first admin slice, updates the dev guide and the import-direction script (`BanhAdmin` may import packages, never `BanhApp`); ADR-0018 v2.2 records the trigger. Application ids: ADR-0026.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Convention plugins over `allprojects` | https://docs.gradle.org/current/userguide/sharing_build_logic_between_subprojects.html | 2026-10-27 (via ADR-0018) | High |
| SE-0386 `package` access, SE-0466 default isolation | See ADR-0018 sources | 2026-10-27 | High |

## Links

Amends ADR-0018 (trigger fired). Related: ADR-0004, ADR-0007, ADR-0026.
