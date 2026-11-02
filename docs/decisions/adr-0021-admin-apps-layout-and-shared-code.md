# ADR-0021: Admin apps in the monorepo and how code is shared

| Field    | Value |
| -------- | ----- |
| ADR      | 0021 |
| Version  | 1.1 [v1.1 | 2026-11-01] (as built in admin part 1; v1.0: decision) |
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

## As built (admin part 1) [v1.1 | 2026-11-01]

The decision stands. What exists, and where it differs from the text above:

- Android: all six modules and `build-logic` exist (`banh.android.library`, `banh.android.compose`). `:core:design` was extracted: the customer design package moved there unchanged (plus admin components) and the customer app imports it. The Compose compiler spike worked in a library module (AGP 9.4, Kotlin 2.4.21). `:admin` is the admin app. Customer data and order code stay in `:app` (moving them was not needed). `ImportDirectionTest` now only forbids a `design` package inside `:app`.
- iOS: `ios/BanhAdmin.xcodeproj` (format 77, synchronized folders, scheme `BanhAdmin`) with local packages `ios/Packages/BanhCore` (money, `ShopDay`, `Load`, `APIClient`, `APIError`, `HTTPTransport`) and `BanhDesign`. Not as planned: `BanhCore` holds no repository protocols, and the admin Codable types live in `BanhAdmin/Core/Models`, not in `BanhContracts` (Android has them in `:core:model`).
- Known duplication: the customer iOS app does NOT use the packages. Its `Core/Design` and `Core/Network` stay, and the packages hold a copy of design and network code, because moving them would touch every customer file. Condition to remove it: the next customer iOS change that already touches most files (or a bug fixed twice in both copies), done as its own change with the customer UI and unit tests green. Until then a change to design tokens or the error envelope is made in both places; the dev guide says so.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Convention plugins over `allprojects` | https://docs.gradle.org/current/userguide/sharing_build_logic_between_subprojects.html | 2026-10-27 (via ADR-0018) | High |
| SE-0386 `package` access, SE-0466 default isolation | See ADR-0018 sources | 2026-10-27 | High |

## Links

Built state: architecture/15-client-part1-alignment.md. Amends ADR-0018 (trigger fired). Related: ADR-0004, ADR-0007, ADR-0026.
