# System Architecture: Review account, D-3 and D-4 as built, log redaction, status of the PRD technical questions

Part of [architecture.md](../architecture.md) (index, version, change log), section 32. New in v1.20 [v1.20 | 2026-11-01]. The store-review account (ADR-0027) and the fixes for QA defects D-3 (cancel against a wrong `day_load`) and D-4 (library logs) are merged; the system documents now follow the code. Sources read: `backend/Sources/App/Config/ReviewAccountConfig.swift`, `Services/Admin/Auth/{SignInService,SignInVerifyService,ReviewAccountCommand}.swift`, `Repositories/Admin/{ReviewAccountStore,AdminOrderStore}.swift`, `Http/{RedactingLogHandler,AdminAuthMiddleware}.swift`, `backend/db/migrations/0006_review_account.sql`, dev guide paragraph v1.20. Format as in [15-client-part1-alignment.md](15-client-part1-alignment.md). Nothing was run; tests were not read.

## 32.1 Review account as built

| Topic | Rule | Written in |
| ----- | ---- | ---------- |
| Switch | `REVIEW_ACCOUNT_EMAIL` and `REVIEW_ACCOUNT_CODE` both set or both empty; one alone stops the start. The code is exactly 6 digits. Sign-in needs `AUTH_CODE_PEPPER` (the code is compared as an HMAC like every code). Allowed with `APP_ENV=production` by design: the review uses the shipped build. The configuration prints as `ReviewAccountConfig(redacted)` | ADR-0027 v1.3, deployment/04 section 11 |
| Sign-in | The review address requests a code like any address (202, same limits, no mail); the stored hash is the fixed code's. Verification gives a `staff` session with `sign_in_method = 'review'` and security event `sign_in_review`. No other address gets the fixed hash. With the variables absent, or set to another address, the request is stored like an unregistered address and the code is refused (`CODE_INVALID`) | auth.md v2.7, ADR-0027 v1.3 |
| `review-account on` | Needs both variables. In one transaction: clears old demo data, creates or switches on the account (name "Review Demo"), then inserts exactly 3 demo orders on the next days: 2 `New`, 1 `Confirmed`, `is_demo = true`, fake names and phones, no `day_load` row, skipped by the per-phone count. Safe to repeat (resets the three). Refuses an address that is a normal account, and a shop without an active district, slot and cake | deployment/04 section 11, data-model/05 section 11 |
| `review-account off` | Deletes demo orders with lines and history, deletes review sessions, voids open codes, sets `is_active = false`. The account row STAYS (ADR-0027 first text said "removed"): `security_event` is append-only and refers to it | ADR-0027 v1.3 |
| Migration `0006` | `order_event_append_only()` still refuses `UPDATE`; it allows `DELETE` only when the order has `is_demo`. Real orders keep an append-only history. Forward-only | data-model/05 section 15, data-model/02 |
| Visibility | Unchanged from B4: review accounts are not in the staff list, not counted toward 30, `PATCH` is 404, no push, order queries add `AND is_demo = true` (normal accounts `false`) | architecture/12, 14 |
| Sessions outlive the variables | `AdminAuthMiddleware` does not look at the review configuration. Removing the variables stops new sign-ins only; an open review session stays valid for its 7 days unless `off` is run. Runbook: run `off`, then remove the variables | deployment/04 section 11 |

## 32.2 D-3, D-4 and logging as built

| Topic | Rule | Written in |
| ----- | ---- | ---------- |
| D-3 cancel and `day_load` | A cancel against a `day_load` row with fewer cakes than the order (manual SQL only) violates `day_load_within_limit`; the transaction rolls back and the route answers 500 `INTERNAL_ERROR` with `details.reason = DAY_LOAD_INCONSISTENT`, log line "Request failed" with the reason only. No `GREATEST` floor (ADR-0030). A missing row is left alone | data-model/05 section 11, api/06 10.11 |
| D-4 log redaction | `RedactingLogHandler` wraps `app.logger` and the HTTP server logger. Events written by the `App` module pass unchanged (they follow BR-7). Events of other modules are dropped below `info`; from `info` up only the message and the keys `database-id`, `psql_connection_id`, `request-id` are kept. So `debug` and `trace` no longer write SQL, bound values, rows, query strings, customer data or the `Authorization` header | api/05 section 9, deployment/01, deployment/04 section 16, architecture/03 |
| Residual risk | The message text of a foreign event at `info` or above is kept as written. If a library ever puts a value into a message, it would pass. Test to keep: run a request with a sentinel phone and token at `trace` and search the output | open, forge |

## 32.3 Stale statements corrected

| File | Was | Now |
| ---- | --- | --- |
| deployment/04 section 11 | variables "only while enabled"; command "deferred" | built, rules and runbook |
| auth.md role table | "DEFERRED to the launch slice" | built (v2.7) |
| architecture/07 components | `review-account on/off` deferred | built |
| architecture/10, 11, 12, 13, 14 | deferred or "still open" | pointer to this file |
| ADR-0027 | no as-built text, "account removed" | v1.3 As built |
| data-model/05 | no migration 0006, no `DAY_LOAD_INCONSISTENT`, `bootstrap-owner` | all three fixed |
| api/05 section 9 | one-line logging rule | redaction rule of 32.2 |

Not changed on purpose: architecture/07 slice A6 and deployment/04 section 18 stay as written, because the store submission is still blocked by the money approvals (DP-Q4); only the account is built.

## 32.4 Admin-orders PRD technical questions (PRD 07-open-questions)

| TQ | Answer in | Truly answered? |
| -- | --------- | --------------- |
| TQ-1 e-mail delivery, test delivery | ADR-0023, deployment/04, `EmailSender` and `recording` provider | NO. ADR-0023 is Proposed: the sender domain and provider account are money and not approved (DP-Q4). Test delivery is answered (recording sender, `AUTH_FIXED_CODE` only outside production); real delivery is not, and no provider was ever called |
| TQ-2 delivery of the admin app | ADR-0026, deployment/04 section 13 | Decided, NOT verified. Unlisted iOS and Android closed testing are unverified against the stores; fees not approved; ids not frozen |
| TQ-3 push | ADR-0024, architecture/14, api/06 10.8 and 10.12 | Decided and built behind `PushSender`; NOT verified against live APNs and FCM (no accounts, no device test). Token handling at sign-out and switch-off is answered |
| TQ-5 stale-view conflicts, list indexes | ADR-0028, ADR-0029, api/06 10.9 and 10.11 | Yes, built |
| TQ-6 image upload | ADR-0025 v1.2, api/07 10.17, architecture/13 | Yes, built |
| TQ-7 90-day rule | ADR-0029 v1.5, api/06 10.9 | Yes, built |
| TQ-8 per-phone limit, reason | ADR-0030, data-model/05 section 11 | Yes, built |
| TQ-11 counters | architecture/09 25.1, ADR-0022, data-model/04 | Yes, built |
| TQ-12 unfinished count | architecture/09 25.1 | Superseded by PRD v1.6 (no Unfinished view); `unfinished_count` badge stays. Yes |
| TQ-13 new-device notice | architecture/09 25.1, session-lifecycle section 3 | Yes, built |

Closed by earlier text: TQ-4, TQ-9, TQ-10 (deferred). The PRD still lists TQ-1 to TQ-3, TQ-5 to TQ-8, TQ-11 to TQ-13 as Open; that is scribe-requirements' file. Query: close TQ-5 to TQ-8 and TQ-11 to TQ-13 with a pointer here; keep TQ-1 and TQ-2 open (money, store accounts) and TQ-3 open until a live push test.

## 32.5 Open recommendations for the orchestrator (no code changed)

| Question | Recommendation | Why |
| -------- | -------------- | --- |
| Should D-3 (`DAY_LOAD_INCONSISTENT`) get its own error code? | No. Keep 500 `INTERNAL_ERROR` with `details.reason`. Add one alert line to deployment/04 section 16: any log line "Request failed" with that reason | A broken counter is a server fault the app cannot act on; a public code would invite client branches and a new `message_key` in both apps for a case that only manual SQL causes. The staff already sees the generic server-trouble message. The operator needs the log, not the code |
| Should the auth middleware also reject review sessions when review config is absent? | Yes. In `AdminAuthMiddleware`, after the session lookup, answer 401 `UNAUTHENTICATED` when `isReview` and the configuration is nil or its address differs from the account address (same predicate as `SignInVerifyService`). Keep `off` for clean-up of data | Makes removing the variables an immediate kill switch, which is the point of a fixed-code secret (a leaked code is ended by a restart, with no database command and no 7-day tail). Cost: one predicate and one test (review session, variables removed: 401; normal session unaffected). No customer-visible change. If not done, the runbook note in deployment/04 is the only guard |

Both are small and reversible; the second tightens security without extra cost, so it needs no owner decision unless the orchestrator sees a reason to ask.

## 32.6 Defects and notes for forge-dev

| ID | Item | Severity |
| -- | ---- | -------- |
| F-1 | 32.5 second row: reject review sessions when the review configuration is absent, with a test | Medium, recommended |
| F-2 | Residual log risk of 32.2: add a sentinel test at `trace` over a request with phone, address and `Authorization` | Low |
| F-3 | `ReviewAccountCommand` prints nothing about which address was switched (good). Check that a changed `REVIEW_ACCOUNT_EMAIL` followed by `on` leaves the old row inactive: `clear` deactivates every review account of the shop, `enableAccount` then creates the new one | Info, test only |

Queries for other agents: scribe-requirements, PRD TQ statuses (32.4). canvas-ui documents untouched.
