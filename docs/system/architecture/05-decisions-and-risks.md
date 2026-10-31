# System Architecture: Decision index, risks and open questions

Part of [architecture.md](../architecture.md) (index, version, change log), sections 12, 13. Moved from architecture.md v1.7 with the wording unchanged unless a line carries a newer label [v1.8 | 2026-10-27].

## 12. Decision Index

| ADR | Decision | Status |
| --- | -------- | ------ |
| [ADR-0001](../../decisions/adr-0001-backend-language-framework.md) | Backend: Swift with Vapor (owner) | Accepted |
| [ADR-0002](../../decisions/adr-0002-database.md) | PostgreSQL (owner) | Accepted |
| [ADR-0003](../../decisions/adr-0003-hosting.md) | Free trial hosting: Render free container plus Neon free Postgres; paid path recorded | Accepted for the trial |
| [ADR-0004](../../decisions/adr-0004-repository-layout.md) | Monorepo with `ios/`, `android/`, `backend/`, `contracts/` | Accepted |
| [ADR-0005](../../decisions/adr-0005-minimum-os-versions.md) | iOS 17 and Android API 26 | Accepted |
| [ADR-0006](../../decisions/adr-0006-native-vs-single-codebase.md) | Two native apps | Accepted |
| [ADR-0007](../../decisions/adr-0007-mobile-architecture.md) | Mobile architecture: iOS MVVM-C, Android MVI, manual DI, no third-party iOS packages (amended 2026-10-27, v1.5) | Accepted |
| [ADR-0008](../../decisions/adr-0008-daily-limit-concurrency-idempotency.md) | Daily-limit counter and idempotency key | Accepted |
| [ADR-0009](../../decisions/adr-0009-order-code-and-input-validation.md) | Order code, phone, lengths, quantity bound | Accepted |
| [ADR-0010](../../decisions/adr-0010-price-change-at-confirmation.md) | Reject and re-review on price change | Accepted |
| [ADR-0011](../../decisions/adr-0011-offline-caching-and-draft.md) | Catalog cache and persisted draft | Accepted |
| [ADR-0012](../../decisions/adr-0012-blur-glass-fallback.md) | Native glass/blur, solid fallback, no paid library | Accepted |
| [ADR-0013](../../decisions/adr-0013-configuration-source-and-sample-data.md) | Configuration in tables, sample flag | Accepted |
| [ADR-0014](../../decisions/adr-0014-abuse-protection.md) | Rate limits, no SMS (amended 2026-10-29: per-address and per-phone limits built) | Accepted |
| [ADR-0015](../../decisions/adr-0015-zalo-and-phone-contact.md) | Zalo web link and `tel:` | Accepted |
| [ADR-0016](../../decisions/adr-0016-application-identifiers.md) | Android application ID and iOS bundle id `app.banh.customer` | Accepted for development; frozen at first store upload |
| [ADR-0017](../../decisions/adr-0017-read-api-caching-rate-limit-assets.md) | Catalog ETag, shared read rate limit, versioned asset URLs, catalog size | Accepted |
| [ADR-0018](../../decisions/adr-0018-modular-package-architecture.md) | Package architecture: layering enforced by tests, feature folders inside the layers, module and package splits only on triggers (rewritten 2026-10-27, v2.0) | Accepted (owner decision 2026-10-27) |
| [ADR-0019](../../decisions/adr-0019-client-address-trust-model.md) | Client address trust model: proxy hop count replaces `TRUST_PROXY` | Proposed (owner to confirm) |
| [ADR-0020](../../decisions/adr-0020-test-infrastructure.md) | Test infrastructure: iOS stub backend, Android fakes, shared throwaway CI database | Accepted |
| [ADR-0021](../../decisions/adr-0021-admin-apps-layout-and-shared-code.md) | Admin apps: second Xcode project, local packages, Android modules with build-logic [v1.10 \| 2026-10-31] | Accepted |
| [ADR-0022](../../decisions/adr-0022-admin-sign-in-sessions-recovery.md) | E-mail code sign-in, opaque access and rotating refresh tokens, reuse detection, owner recovery | Accepted (owner, 2026-10-31) [v1.11 | 2026-10-31] |
| [ADR-0023](../../decisions/adr-0023-email-delivery.md) | E-mail delivery by HTTPS API provider, sender domain | Proposed (money flag kept; code independent of the provider behind `EmailSender`; go-live blocked) [v1.11 | 2026-10-31] |
| [ADR-0024](../../decisions/adr-0024-push-notifications.md) | APNs direct and FCM v1 behind `PushSender` | Accepted |
| [ADR-0025](../../decisions/adr-0025-cake-image-storage.md) | Cake images as bytes in PostgreSQL | Accepted |
| [ADR-0026](../../decisions/adr-0026-admin-app-distribution-and-identifiers.md) | Unlisted iOS, closed-track Android, ids `app.banh.admin` | Accepted (owner, 2026-10-31); store fees not yet approved [v1.11 | 2026-10-31] |
| [ADR-0027](../../decisions/adr-0027-store-review-account.md) | Store review account with demo orders only | Accepted, option B (owner, 2026-10-31) [v1.11 | 2026-10-31] |
| [ADR-0028](../../decisions/adr-0028-status-change-conflict-detection.md) | Stale-view detection by `expected_status` | Accepted |
| [ADR-0029](../../decisions/adr-0029-order-list-search-and-90-day-window.md) | Keyset list, `unaccent` search, rolling 90-day window | Accepted |
| [ADR-0030](../../decisions/adr-0030-cancel-reason-and-per-phone-limit.md) | Cancel reason column and per-phone count rule | Accepted |
| [ADR-0031](../../decisions/adr-0031-cake-add-and-remove-model.md) | Soft removal of cakes | Accepted |

Amended on 2026-10-31 [v1.10 | 2026-10-31]: ADR-0003 v1.4 (paid path before real use), ADR-0014 v1.3, ADR-0017 v1.2, ADR-0018 v2.2. Mapping of admin-orders technical questions: TQ-1 to ADR-0023; TQ-2 to ADR-0026; TQ-3 to ADR-0024; TQ-4 to ADR-0022; TQ-5 to ADR-0028 and ADR-0029; TQ-6 to ADR-0025; TQ-7 to ADR-0029; TQ-8 to ADR-0030; TQ-9 to ADR-0022 and ADR-0031; TQ-10 to ADR-0022.

Amended on 2026-10-27 [v1.6]: ADR-0001 (toolchain floor 6.2), ADR-0004 (no `tools/`, ddagent external, per-component CI), ADR-0007 (toolchain table moved to the dev guide), ADR-0013 (warning deferred), ADR-0014 (see above).

Amended on 2026-10-27 [v1.8 | 2026-10-27]: ADR-0007 v1.5 (iOS MVVM-C, Android MVI) and ADR-0018 v2.0 (owner decisions of the same day).

Mapping of the open technical questions: Q-T1 to ADR-0008; Q-T2 to ADR-0013; Q-T3 and TQ-1 to ADR-0005; Q-T4 to deployment.md section 4; Q-T5 to ADR-0003; Q-T6 and TQ-5, TQ-6 to ADR-0009; TQ-2 to ADR-0015; TQ-3 and TQ-7 to ADR-0011; TQ-4 to ADR-0010; TQ-8 to ADR-0012.

## 13. Risks & Open Questions (the change log is in [architecture.md](../architecture.md))

| ID | Risk or question | Impact | Mitigation |
| -- | ---------------- | ------ | ---------- |
| R-1 | Free plan terms change; server sleep (about 1 minute) and database suspend slow the first request after idle | Slower or timed-out first order, possible forced cost | Apps wake the server at launch, same-key retry, alerts; paid upgrade path (ADR-0003) |
| R-2 | Zalo web link behaviour without the app is unverified | Contact flow | Device test before release; phone button remains |
| R-3 | Store accounts and review (owner fees, new personal Google Play accounts may need closed testing before production, unverified) | Release date | Start accounts early (deployment.md section 9) |
| R-4 | Retention period for personal data not stated (BR-12); Vietnamese personal data law may apply (unverified) | Compliance, privacy page text | Owner states the period; legal review recommended |
| R-5 | Ordering rules duplicated in two apps | Drift | Server authority, shared fixtures |
| R-6 | Server-side Swift: small ecosystem, slow release builds, Linux differences, Vapor 5 migration ahead | Delivery speed, hiring, later slices (SMS, push) | Build in CI with caching, test on Linux per pull request, pin versions, yearly upgrade review (ADR-0001) |
| R-8 | The API host name is compiled into the apps | A host change after release needs an app update | Custom domain before store release (launch cost, owner) |
| R-9 | Free-tier hosting is not for real customers' orders (no backups on the host, sleep) | Lost or missed orders | Trial only; nightly encrypted dump; move to the paid path before launch (ADR-0003) |
| R-10 | Concurrency code can behave differently in release builds than in debug tests (the `withDeadline` crash, Swift 6.2.4) [v1.4 | 2026-10-26] | A crash only visible in production-like builds | NIO scheduled-task timer; release-binary smoke test in CI; live check after any change to `Support/Deadline.swift`; revisit when the Swift toolchain is upgraded |
| R-7 | Material3 Expressive APIs may be experimental in the stable library | API churn | Opt-in, pinned version, wrapper components (ADR-0007) |

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| AR-Q1 | Owner decisions on ADR-0001 to 0005 and 0010 | Developers start after the decisions | No longer | technical and business | Closed 2026-10-25: all decided; ADR-0003 stays conditional on no card or cost appearing | Owner |
