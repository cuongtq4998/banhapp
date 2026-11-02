# ADR-0034: Customer order tracking by phone number only

| Field    | Value |
| -------- | ----- |
| ADR      | 0034 |
| Version  | 1.1 [v1.1 | 2026-11-02] (clarifications, Decision 7; v1.0: first version) |
| Status   | Accepted as the owner's decision of 2026-11-02 (C); it affects customer data, so the residual risk in Consequences must be seen by the owner |
| Date     | 2026-11-02 |
| Decider  | owner (business choice); atlas-architect (mitigations) |
| Based on | PRD place-order part 08 (FR-22 to FR-27, BR-16 to BR-18, AC-38 to AC-47), admin-orders FR-28 to FR-30; ADR-0030 (5 orders per phone), ADR-0019, ADR-0017 |

## Context

The customer must follow an order without signing in and without push. The PRD default was order code plus phone. The owner decided: the customer types a phone number only and sees that phone's orders.

## Decision

`POST /v1/orders/lookup` (api/10) takes a normalised phone and returns that phone's orders, newest first, paged. Mitigations are part of the decision, not options:

1. Minimum data: phone masked, district only (no street address, no note, no customer name), no cancel reason, no staff names, no internal records.
2. Same answer shape for a phone with orders and one without (200, `orders: []`); constant-ish timing by a minimum response time; no existence signal in headers, errors or limits.
3. Rate limits per phone and per client address (and per installation if sent), counted whether or not orders exist; 429 identical for both cases.
4. Page size 10, at most 5 pages (50 orders) per phone and window; opaque cursor bound to the phone.
5. No personal data in logs; the phone is never in a URL (POST body), responses `no-store`.
6. Window: open orders at any age; `Finished` and `Cancelled` 30 days after `status_changed_at` (assumption of the owner, Q-O8).
7. Clarifications [v1.1 | 2026-11-02]: a request with a valid cursor does not count against the per-phone limit (the first page did), it counts against address and installation limits; the client address comes only from the platform proxy header named in `CLIENT_ADDRESS_HEADER` with `TRUSTED_PROXY_HOPS`, never from a client-supplied header; the response floor must exceed the p99 of the one shared indexed query and an alert fires when it is exceeded; `as_of` is enough for the offline line; the app's 9 to 11 digit check is a hint only (api/10 10.14.5, 10.14.7).

## Rejected alternatives

| Option | For | Against |
| ------ | --- | ------- |
| Order code plus phone (PRD default, BR-17) | Two factors; the code is a random secret the guesser lacks; per-pair wrong-try limit | Owner chose phone only; no "all my orders" without the phone anyway; code must be kept by the customer |
| SMS one-time code | Proves the person holds the phone; strongest | Money (SMS provider, per-message cost) and a provider account; delay; needs owner approval (escalation case a); abuse for SMS pumping |
| Orders kept on the device only | No server exposure | Lost on reinstall or another phone; the owner asked for lookup by phone |

## Consequences

Residual risk (owner to see): the phone number is the only secret. Anyone who knows or guesses a number can see that phone's cakes, dates, district, fees and masked phone for the window. Per-address limits do not stop a distributed guesser; per-phone limits let an attacker block a victim's lookups for the rest of the window (the victim sees the wait message, can phone the shop). Neighbours and relatives who know the number see orders (possible surprise gift privacy). Upgrade path with no data change: require the order code as a second field (add `order_code` to the body; wrong pair gives the same empty answer), or an SMS code if the owner accepts the cost. Recommendation: accept phone-only for launch, watch 429 counts (deployment alert), and decide on the code requirement if abuse appears.

Follow-up: tests of equal shape and timing band, limiter keys, log scan for phones, cursor reuse with another phone.

## Sources

OWASP guidance on user enumeration and rate limiting (https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html, from memory, not fetched; medium confidence).
