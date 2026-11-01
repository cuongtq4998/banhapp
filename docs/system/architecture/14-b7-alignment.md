# System Architecture: Slice B7 alignment, push token route, dispatch, provider switch, dependency

Part of [architecture.md](../architecture.md) (index, version, change log), section 30. New in v1.18 [v1.18 | 2026-11-01]. Slice B7 (push to phones) is built; the system documents now follow the code. Sources read: `Config/PushConfig`, `PushSetup`, `Services/Admin/Push/*`, `Repositories/Admin/PushStore.swift`, `AuthStore+Sessions.swift`, `SettingsWriter+Staff.swift`, `Routes/Admin/PushTokenRoutes.swift`, `Routes/OrderRoutes.swift`, `Http/Outbound/*`, `Tests/AppTests/Push/`, `backend/.env.example`, `Package.swift`, dev guide B7 paragraph. Format as in [13-b6-alignment.md](13-b6-alignment.md).

## 30.1 Decisions and corrections

| Topic | Rule | Written in |
| ----- | ---- | ---------- |
| Token route | `PUT /v1/admin/push-token` is built (owner and staff, `adminGroup()`), 204. The token and `apns_environment` go on the calling session; the same token is cleared on every other session in the same transaction. A body `platform` that differs from the session's own platform is 422 `PLATFORM_MISMATCH` | api/06 10.8, api/05 section 9, auth.md |
| Field codes | `UNKNOWN_FIELD`, `PLATFORM_INVALID`, `TOKEN_INVALID` (empty, over 512, space or control character), `APNS_ENVIRONMENT_INVALID` (iOS needs it; Android value ignored and not stored), `PLATFORM_MISMATCH`. Only the first bad field is reported, unlike the settings forms (see defect D-3) | api/06 10.8 |
| Provider switch | `PUSH_PROVIDER` is `off`, `recording` or `live`. Earlier text elsewhere said `none` and `real`: no document does now. Unset is `off` (warning in the log, `app.services.push` nil). `recording` is refused when `APP_ENV=production` | deployment/04 section 11, `.env.example` |
| Live configuration | `live` needs `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`, `APNS_TOPIC`, `FCM_PROJECT_ID`, `FCM_SERVICE_ACCOUNT_JSON`. A missing value, an unparsable key or service-account JSON, an unknown provider value, or any credential without `PUSH_PROVIDER` stops the start. A key pasted on one line with `\n` is restored | deployment/04, abuse-secrets-threats |
| Clearing | `push_token` and `push_apns_environment` are nulled together in the statement that revokes: sign-out, sign-out of others, replacement by a new sign-in, refresh reuse, deactivation. A dead token is cleared by value (`PushStore.clear`) | data-model/04 section 3.12, session-lifecycle |
| Dispatch | After `POST /v1/orders` stored a new order (`.created`; not a replay, not a refusal), `OrderRoutes` calls `PushDispatcher.notifyNewOrder` after the transaction. It runs on `BackgroundWork` (like mail) and cannot change the order answer | admin-order-handling section 3, ADR-0024 |
| Recipients | `PushStore.targets`: sessions of the shop with `revoked_at IS NULL`, `refresh_expires_at` in the future and a token, on accounts that are active and not `review`. All are sent in parallel | data-model/04 section 3.12 |
| Retry and dead tokens | A send that throws (429, 5xx, network) is retried after 1, 5 and 20 s, then counted as failed. A `rejected` answer is not retried. 410, `BadDeviceToken` and `UNREGISTERED` mean "dead": the token is deleted. One log line holds counts only (targets, sent, removed, failed) | deployment/04 alerts |
| Payload | Only order code, cake count and delivery date `dd/MM/yyyy` (`PushMessage` has no other field). APNs alert `title-loc-key`, `loc-key`, `loc-args`, custom `order_code`, thread id `new_orders`, priority 10, expiry 1 h. FCM HTTP v1 uses `android.notification.title_loc_key`, `body_loc_key`, `body_loc_args`, `channel_id` `new_orders`, `data.order_code`, priority high, `ttl` 3600s. `PushPayloadPrivacyTests` searches the real request bytes for name, phone, address, note | api/06 10.12 |
| Dependency | `swift-crypto` became a direct dependency of the backend package (range `3.0.0..<6.0.0`, resolved 5.0.3). Products `Crypto` (ES256 for the APNs token) and `_CryptoExtras` (RS256 for the Google OAuth assertion). `_CryptoExtras` is an underscore product: its API is not covered by the usual stability promise, so a major upgrade needs a build check. Both were already in the tree through Vapor | this section, ADR-0024 |

## 30.2 Outbound clients: UNVERIFIED

`ApnsPushSender` (ES256 provider token reused 40 minutes, HTTP/2, production host or sandbox host by the token's stored environment) and `FcmPushSender` with `FcmAccessTokens` (RS256 assertion exchanged for an OAuth2 token, cached until one minute before expiry) were written from public documentation and have never run against Apple or Google (no credentials exist). Tests use `FakeOutboundTransport` and check the request shape and the JWT signatures. Before go-live one real device per platform must receive a push: needs the Apple Developer Program and an FCM project (DP-Q4, not approved). The FR-25 target of 60 s from commit to phone is therefore unmeasured.

## 30.3 Other differences found (B7)

| Item | Finding | Resolution |
| ---- | ------- | ---------- |
| architecture/10 26.2, 11 27.2, 12 28.x | Said the push route is deferred | Fixed: built in B7 |
| auth.md role table (about line 73) | "deferred, push slice" | Fixed (v2.5) |
| api/05 route table | "DEFERRED to the push slice" | Fixed |
| api/06 10.12 | FCM keys without the `android.` path | Fixed |
| deployment/04 | Provider values and the six `live` values not stated as one rule | Fixed (v1.13) |
| data-model/04 | Only sign-out, others and deactivation named; environment column not mentioned | Fixed (v1.13) |
| Dev guide | B7 paragraph and the other paragraphs say "push token route (B7)" as not built in B1 to B6 text; true at their dates; owned by forge-dev | None |
| Task wording `none`/`real` | The code and docs use `off`/`live` | Docs kept |

## 30.4 Open defects for forge-dev

| ID | Defect | Severity |
| -- | ------ | -------- |
| D-3 | `PushTokenRequest.parse` reports the first bad field only; api/06 now says so. If clients should see every problem at once, it should collect like `FormReader`. Not a bug today (one phone, one code path) | Low |
| D-4 | The new-order dispatch has no outbox (BR-9, R-AO-3): a process end between commit and send loses the push. Accepted in ADR-0024; the counter that decides on an outbox ("orders without a push record") has no data source yet | Low |
| D-5 | `PUSH_PROVIDER=off` logs a warning on every start including local runs and tests that use no provider | Info |

Still open from earlier: purge task, review-account sign-in (architecture/11 27.2). Query for other agents: none.
