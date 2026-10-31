# ADR-0027: Store review account for an app with e-mail-code sign-in only

| Field    | Value |
| -------- | ----- |
| ADR      | 0027 |
| Version  | 1.0 |
| Status   | Proposed (security and customer data: owner decides) |
| Date     | 2026-10-31 |
| Decider  | atlas-architect proposes; product owner decides |
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

Recommendation: option B. `account.kind` is `normal` or `review`. When `REVIEW_ACCOUNT_EMAIL` and `REVIEW_ACCOUNT_CODE` are set, that address signs in with the fixed code (the only exception to ADR-0022, never with `AUTH_FIXED_CODE`), the account has role `staff`, every order query for a `review` account adds `AND is_demo`, and the account receives no push. Demo orders are inserted by the operator (three fake rows with `is_demo = true`, which are excluded from every normal query and from `day_load`). The variables are set before submission and removed after approval; the account is created and removed by the operator command `review-account on|off`. Use of the account is logged as a security event. The owner can instead choose D.

## Consequences

- Positive: no real data reachable; short lifetime.
- Negative: queries carry one more predicate (covered by a test that a normal account never sees `is_demo` rows and a review account never sees others); a fixed code exists while enabled.
- Follow-up: owner approves; forge-dev adds `is_demo` to `customer_order` (data-model/05) and the command.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Reviewers must be able to use every feature, so apps with sign-in need demo access | Apple App Review Guidelines 2.1, not read (PRD S-3) | 2026-10-31 | Unverified |

## Links

Related: ADR-0022, ADR-0026. Detail: auth.md section 1 and auth/abuse-secrets-threats.md section 5.
