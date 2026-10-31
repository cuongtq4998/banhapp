# ADR-0026: Distribution of the admin apps and their application identifiers

| Field    | Value |
| -------- | ----- |
| ADR      | 0026 |
| Version  | 1.0 |
| Status   | Proposed (hard to reverse: the identifiers; money: store fees; owner approves) |
| Date     | 2026-10-31 |
| Decider  | atlas-architect proposes; product owner approves |
| Based on | PRD D-1, D-2, S-2, S-3; TQ-2; ADR-0005, ADR-0016 |

## Context

Up to 31 people use the admin apps. They must not appear in search. Both stores review apps. The Apple Developer Program (USD 99 a year, unverified) and Google Play registration (USD 25 once, unverified) are already required for the customer app; the admin app adds a store record on each, not a second fee. A bundle id or application id cannot change after the first upload (ADR-0016).

## Decision Drivers

- Staff install without Apple Business Manager or a Google Workspace.
- Builds that do not expire every 90 days.
- No search visibility; limited audience.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| iOS A. Unlisted app distribution (link only; Apple review; request form by the account holder) | Permanent, free, no tester management, no 90-day expiry | App Review needed (demo access, ADR-0027); form approval step; per-update review |
| iOS B. TestFlight | No store listing | Builds expire after 90 days (unverified); external testers need beta review; internal testers must be team members |
| iOS C. Custom app via Apple Business Manager | Private | Needs a business enrolment (unverified) |
| Android A. Google Play production, public listing with sign-in only | Simple installs | Anyone can find it; production access needs closed testing first on new personal accounts (12 testers for 14 days) |
| Android B. Closed testing track with a tester list (e-mail addresses or a Google Group) | Not public; no search | Testers must be listed and opt in; track rules may change |
| Android C. Managed Google Play private app | Private | Needs a Workspace organisation (unverified) |

## Decision

Recommendation: iOS A (unlisted) and Android B (closed testing), with the 12-tester production-access requirement of Google handled by using the admin testers themselves where needed (unverified for a closed-only app). If Android B proves too restrictive, Android A with the unlisted nature given up (the app shows only a sign-in). Identifiers: iOS bundle id `app.banh.admin` (tests `app.banh.admin.tests`, `app.banh.admin.uitests`), Android `namespace` and `applicationId` `app.banh.admin`, same neutral style as ADR-0016. They freeze at the first upload to TestFlight or Play internal testing. Store text states the use of customer data (name, phone, address) by staff only and links the privacy page `/privacy` (the page gains a staff section).

## Consequences

- Positive: no new fees beyond the two registrations; staff install from a link or invitation.
- Negative: each update passes App Review; Android testers need Google accounts; a review account is required (ADR-0027).
- Follow-up: owner decides ids, creates the app records, submits the unlisted request after the first successful review; forge-dev sets ids; CI signs with secrets outside the repository.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Unlisted apps: link only, App Review required, request form, account holder only | https://developer.apple.com/support/unlisted-app-distribution | 2026-10-31 (search summary) | Medium |
| New personal Play accounts need a closed test with 12 testers for 14 days before production | https://support.google.com/googleplay/android-developer/answer/14151465 | 2026-10-31 (search summary) | Medium |
| TestFlight builds expire after 90 days; Play internal track limit of 100 testers | Not verified in this research | 2026-10-31 | Unverified |
| Fees USD 99 and USD 25 | deployment.md section 9 | 2026-10-25 | Unverified |

## Links

Related: ADR-0016, ADR-0027, ADR-0021.
