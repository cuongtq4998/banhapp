# ADR-0015: Opening Zalo and the phone dialer

| Field    | Value |
| -------- | ----- |
| ADR      | 0015 |
| Status   | Accepted |
| Date     | 2026-10-25 |
| Decider  | atlas-architect |
| Based on | UI TQ-2; FR-2, FR-12, AC-3, AC-17 |

## Context

The home and confirmation screens open Zalo and the dialer with the shop's contact. The behaviour when Zalo is not installed and the use of the Zalo brand mark are open.

## Decision Drivers

- Works without Zalo installed (graceful).
- No private or undocumented URL schemes.
- No brand-rights risk.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. Open the web link `https://zalo.me/<number>` (universal/app link); the Zalo app takes it if installed, otherwise the browser shows the Zalo page | One link on both platforms; no scheme registration; no app-installed check | Behaviour with and without Zalo is unverified by an official source; must be tested on devices |
| B. Custom scheme `zalo://` after `canQueryURL` check | Direct to the app | Undocumented scheme (unverified); needs `LSApplicationQueriesSchemes` / Android `<queries>`; breaks silently |
| C. Zalo Official Account SDK | Official | Heavy SDK, registration, not needed |

## Decision

Option A. The shop data holds `zalo_contact` (digits of the Zalo phone number in international form without `+`, or an official account id) and `phone_contact` (display and dial number in E.164). The app opens `https://zalo.me/{zalo_contact}` as a normal external URL and `tel:{phone_contact}` for the dialer. If the system reports that the URL cannot be opened, the app shows the toast `ERR_OPEN_ZALO` / `ERR_OPEN_PHONE` (already specified). No `canOpenURL` pre-check, no custom scheme, no entitlement. Verification on real devices with and without Zalo is a required test (probe-qa) before release.

Brand mark: the apps show the text label "Zalo" with a generic chat icon (system symbol / Material Symbol). The Zalo logo is not used until the shop confirms the right to use it and the brand guideline is read (unverified).

## Consequences

- Positive: no extra permissions or scheme lists; simple code.
- Negative: without Zalo installed the customer lands on a web page; accepted (the phone button remains).
- Follow-up: UI query to canvas-ui about the Zalo icon (see report).

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| `zalo.me` links are used as personal chat links; official behaviour without the app not found | Search found no official documentation (a vendor guide and third-party posts only) | 2026-10-25 | Unverified |
| Zalo brand usage terms | Not found | 2026-10-25 | Unverified |
| `tel:` URL scheme opens the dialer on iOS and Android | Platform documentation, not fetched | 2026-10-25 | Medium (standard behaviour) |

## Links

Related: ADR-0013.
