# ADR-0024: Push notifications for new orders

| Field    | Value |
| -------- | ----- |
| ADR      | 0024 |
| Version  | 1.0 |
| Status   | Accepted (free services; the Apple Developer Program fee is already needed for the customer app; no customer data in the payload) |
| Date     | 2026-10-31 |
| Decider  | atlas-architect |
| Based on | PRD FR-31 to FR-35, BR-14, G-1, TQ-3; ADR-0007 |

## Context

Every signed-in device of an active account gets a notification when an order is stored, within 60 seconds. The text may hold the order code, number of cakes and delivery date only. Tokens must stop receiving after sign-out, revoke or deactivation. The list is the source of truth (BR-14), so a lost push is tolerable.

## Decision Drivers

- No cost, no third-party SDK in the iOS app (ADR-0007).
- Payload without personal data; text in Vietnamese without the server sending prose.
- Small code; testable without Apple or Google.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. APNs direct for iOS, FCM HTTP v1 for Android, behind a `PushSender` protocol (chosen) | No iOS SDK; native token; both free | Two clients to write; two credentials |
| B. FCM for both | One server integration | Firebase iOS SDK (third-party package, ADR-0007) and an APNs key upload to Firebase |
| C. A push SaaS | Fewer lines | Another processor of data, possible fee |
| D. Polling only | No push service | Fails G-1 |

## Decision

Option A. APNs: provider token authentication (ES256 JWT from a `.p8` key; key id, team id, topic `app.banh.admin` as configuration), HTTP/2, per-token `production` or `sandbox` environment sent by the app. FCM: HTTP v1 with a service-account OAuth2 access token (RS256-signed assertion, cached until shortly before expiry). Payload: alert with localisation keys (`PUSH_NEW_ORDER_TITLE`, `PUSH_NEW_ORDER_BODY` with arguments order code, number of cakes, `dd/MM/yyyy`) so the Vietnamese text lives in the apps' resource files; custom data field `order_code` opens the detail (FR-33). Android shows the same keys through `body_loc_key`. No name, phone, address or note (FR-32).

Dispatch: after the order transaction commits, an in-process task reads the push tokens of active, unrevoked sessions and sends in parallel with a 10 s timeout and retries after 1 s, 5 s and 20 s on 5xx or timeout. APNs 410 or `BadDeviceToken` and FCM `UNREGISTERED` delete the token. An outbox table is not built: a crash between commit and send loses one notification, which BR-14 allows; build one if monitoring shows loss (trigger: more than 1 percent of orders without a send record in 30 days). A send failure never fails the order.

Tokens: one row per device session; sign-out, revoke, deactivation and token refresh by the app delete or replace it (data-model/04). Permission denied: the app registers no token and shows the hint (FR-34).

## Consequences

- Positive: free, no SDK on iOS, payload free of personal data, tokens die with sessions.
- Negative: two integrations to maintain; Android needs Firebase messaging in the app and a Google account for the Firebase project; push is best effort.
- Follow-up: operator creates the APNs key and the Firebase project (secrets in the host store); `PUSH_PROVIDER=recording` in tests; device test on both platforms before launch; free host must be awake at order time (it is, the order request wakes it).

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| FCM v1 uses short-lived OAuth2 tokens derived from a service account | https://firebase.google.com/docs/cloud-messaging/migrate-v1 | 2026-10-31 (search summary) | Medium |
| APNs `.p8` token auth uses an ES256 JWT, reused 20 to 60 minutes | Apple developer documentation, not fetched (secondary summary) | 2026-10-31 | Unverified |
| FCM and APNs are free of charge | Provider pages not fetched | 2026-10-31 | Unverified (PRD TQ-3 expected free) |

## Links

Related: ADR-0007, ADR-0022. Detail: architecture/07, deployment/04.
