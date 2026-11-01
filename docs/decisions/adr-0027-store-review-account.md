# ADR-0027: Store review account for an app with e-mail-code sign-in only

| Field    | Value |
| -------- | ----- |
| ADR      | 0027 |
| Version  | 1.3 [v1.3 | 2026-11-01] (As built: sign-in, `review-account on|off`, migration 0006); 1.2 (B4: review accounts hidden from staff list, count and `PATCH`) |
| Status   | Accepted, option B (product owner, 2026-10-31): fixed-code staff account of kind `review` that sees fake demo orders only [v1.1 | 2026-10-31] |
| Date     | 2026-10-31 |
| Decider  | atlas-architect proposes; product owner decided on 2026-10-31 [v1.1 | 2026-10-31] |
| Based on | PRD S-3 (unverified), NFR Security and Privacy; ADR-0022, ADR-0026 |

## Context

Store reviewers must be able to use every feature, which usually means a demo account. A reviewer cannot receive a code at a shop mailbox, and the admin app shows real customer names, phones and addresses. A fixed code for a real staff account would be a back door to customer data.

## Decision Drivers

- Reviewers can sign in and see realistic screens.
- No access to real customer data; no permanent back door.
- Little code, easy to remove.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. A real staff account with a fixed code | Trivial | Exposes real orders; permanent secret |
| B. Review account kind `review`: fixed code from the secret `REVIEW_ACCOUNT_CODE`, sees only demo orders (fake data flagged `is_demo`), no push, no settings changes persisted to real data, enabled only while `REVIEW_ACCOUNT_EMAIL` is set (recommended) | No real data; removable by clearing two variables | A code path and a flag in order queries to test |
| C. A separate staging backend for review builds | Real isolation | A second build configuration submitted to review differs from the shipped build; Apple may object |
| D. Reviewer given a live code by the owner during review | No back door | Review delays; reviewer timing cannot be controlled |

## Decision

Option B (owner decision 2026-10-31). `account.kind` is `normal` or `review`. When `REVIEW_ACCOUNT_EMAIL` and `REVIEW_ACCOUNT_CODE` are set, that address signs in with the fixed code (the only exception to ADR-0022, never with `AUTH_FIXED_CODE`), the account has role `staff`, every order query for a `review` account adds `AND is_demo`, and the account receives no push. Demo orders are inserted by the operator (three fake rows with `is_demo = true`, which are excluded from every normal query and from `day_load`). The variables are set before submission and removed after approval; the account is created and removed by the operator command `review-account on|off`. Use of the account is logged as a security event. Option D is not chosen.

## Consequences

- Positive: no real data reachable; short lifetime.
- Negative: queries carry one more predicate (covered by a test that a normal account never sees `is_demo` rows and a review account never sees others); a fixed code exists while enabled.
- Follow-up: the account is only built and tested with fakes now; real submission waits for the store accounts (DP-Q4, not yet approved) [v1.1 | 2026-10-31]. forge-dev adds `is_demo` to `customer_order` (data-model/05) and the command.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Reviewers must be able to use every feature, so apps with sign-in need demo access | Apple App Review Guidelines 2.1, not read (PRD S-3) | 2026-10-31 | Unverified |

## Links

Related: ADR-0022, ADR-0026. Detail: auth.md section 1 and auth/abuse-secrets-threats.md section 5.

Built in slice B4 [v1.2 | 2026-11-01]: `GET /v1/owner/staff` and the 30-account count skip `kind = 'review'`; `PATCH /v1/owner/staff/{id}` on a review account is 404; the address of a review account still blocks a new staff account (`EMAIL_TAKEN`).

## As built [v1.3 | 2026-11-01]

Built after slice B7 (backend only; sources `Config/ReviewAccountConfig.swift`, `Services/Admin/Auth/{SignInService,SignInVerifyService,ReviewAccountCommand}.swift`, `Repositories/Admin/ReviewAccountStore.swift`, migration `0006_review_account.sql`). Details and open points: architecture/16. Differences from the text above:

- Command: `review-account on|off`, run with the application role (`APP_ENV`, `DATABASE_URL`, `SHOP_ID`). `on` also needs both variables in its own environment.
- Variables: `REVIEW_ACCOUNT_EMAIL` and `REVIEW_ACCOUNT_CODE` both or none (one alone stops the start); the code is exactly 6 digits; sign-in needs `AUTH_CODE_PEPPER` like every sign-in. It is allowed in production by design: the review runs on the shipped build, so the secret cannot be limited to staging.
- Sign-in: the review address requests a code like any address (202, same limits, no mail); the stored hash is that of the fixed code; the verified session is `staff` with `sign_in_method = 'review'` and security event `sign_in_review`. No other address ever receives the fixed hash; with the variables absent the code is refused like an unregistered address.
- `on` creates or switches on the account row (display name "Review Demo") and resets exactly three demo orders: two `New` and one `Confirmed`, fake names and phones, `is_demo = true`, outside `day_load` and outside the per-phone count. It refuses an address that already belongs to a normal account (`addressTaken`) and a shop without an active district, slot and cake.
- `off` deletes the demo orders with their lines and history, deletes the review sessions, voids open codes and sets `is_active = false`. The account row is KEPT, not removed as the Decision text says, because the append-only `security_event` refers to it. Migration 0006 lets `order_event` rows of `is_demo` orders be deleted; real orders stay append-only.
- Removing the variables does not end sessions: the auth middleware does not look at the review configuration, so an open review session stays valid until its 7 days end unless `off` is run. Runbook: run `off`, then remove the variables (deployment/04 section 11).
