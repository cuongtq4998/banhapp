# ADR-0023: E-mail delivery service for sign-in codes

| Field    | Value |
| -------- | ----- |
| ADR      | 0023 |
| Version  | 1.2 [v1.2 | 2026-10-31] (recovery mails removed, PRD v1.6) |
| Status   | Proposed, money flag kept (a sender domain costs about USD 10 to 15 per year and is NOT approved: the owner allows the free tier only for now, 2026-10-31). Code and tests do not depend on the provider, so building goes on; real go-live with staff is blocked until the owner approves a sender domain and paid hosting [v1.1 | 2026-10-31] |
| Date     | 2026-10-31 |
| Decider  | atlas-architect proposes; product owner approves the domain and the account |
| Based on | PRD admin-orders v1.6 FR-1, FR-7, BR-4, BR-13, A-8, S-5 (ids as in product/admin-orders/08, section 15); TQ-1; ADR-0003 |

## Context

Sign-in codes and the new-device notice go out by e-mail. Volume is far below any free tier (tens of people, about one code a week each, plus abuse limits). The API runs on a host that blocks outbound SMTP on free web services (ports 25, 465, 587) since 26 September 2025, so the provider must be reachable by HTTPS. Codes that land in spam break sign-in, so the sender needs SPF, DKIM and DMARC on a domain the shop controls.

## Decision Drivers

- No recurring fee at this volume; no card if possible.
- HTTPS API (no SMTP), simple REST call.
- Deliverability: authenticated sender domain.
- Tests and local runs must not send mail.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. Resend, free plan (3,000 mails a month, 100 a day, one sending domain per its blog) | Small REST API, domain verification with SPF and DKIM | Free plan pauses at the cap; third-party pages disagree on the domain count; needs a domain |
| B. Brevo free (300 a day, API included) | Higher daily cap | Larger product built for marketing; quota shared with campaigns; approval step unconfirmed |
| C. Postmark, Mailgun, SES | Strong deliverability; SES about USD 0.10 per 1,000 | Postmark free tier tiny (unverified); SES needs an AWS account and card, sandbox exit |
| D. SMTP from the host | None | Blocked on the free host |
| E. Send from a free-mail address | No domain | Fails DMARC alignment, goes to spam, provider terms |

## Decision

Two parts [v1.1 | 2026-10-31].

1. Code path (decided now, no money): all mail goes through one protocol `EmailSender` (`Services/Admin/Mail/`) with `send(EmailMessage)` where `EmailMessage` holds recipient, subject and plain-text body (Vietnamese, the code only, no link) and nothing provider-specific. Sign-in, notice and cap logic (30 s wait, 3 an hour, `MAIL_MAX_PER_DAY`, one retry after 5 s, send after the response, failure logged without the address) live above the protocol and are identical for every implementation. Implementations: `RecordingEmailSender` (tests; codes read from the recorder), `ConsoleEmailSender` (local; code printed to stdout; refused when `APP_ENV` is `staging` or `production`), and one HTTPS adapter per provider in `Http/Outbound/` (`ResendEmailSender` first; Brevo or another is one more class and one value of `MAIL_PROVIDER`). Admin slices A0 to A5 are built and tested with the recording and console senders only; no domain, account or key is needed for them. `AUTH_FIXED_CODE` is allowed only in `local` and `staging` (startup refuses it in production).
2. Provider and domain (Proposed, money): Resend free plan behind the protocol, Brevo as fallback, sender subdomain `mail.<SHOP_DOMAIN>` with SPF, DKIM and DMARC (`p=none` first, `quarantine` after a week of clean reports). This needs the domain and a provider account. Until the owner approves them, no real person receives a code from the system.

Development on the free tier (owner decision 2026-10-31): `local` uses the console sender; automated tests the recording sender; the free staging service may use a real provider only if the operator tests with their own mailbox under the provider's no-domain test sender (a test sender restricted to the account owner's address; unverified, check at that time). Free-tier limits that matter: the free host sleeps after idle (first code mail can take a minute) and in-memory limits reset on restart; both are acceptable for development and are the reason go-live is blocked.

Go-live gate: sign-in codes by e-mail to staff and owner, with the checklist in deployment/04 section 17, may start only when the owner has approved (a) the sender domain and the mail provider account and (b) paid always-on hosting (ADR-0003 v1.4). Sending real codes from a free-mail address (option E) or from the provider's shared test sender is not a substitute: it fails DMARC alignment or reaches only the account owner.

## Consequences

- Positive: cost USD 0 at this volume besides the domain; no SMTP.
- Negative: a domain is needed (also wanted for the API host, R-8); free plan has a daily cap, so a flood of code requests could block sign-in until the next day (limits in ADR-0022 reduce this; upgrade is about USD 20 a month, unverified).
- Follow-up (blocked until money approval): owner buys the domain and creates the provider account; operator sets DNS records and checks one test message to Gmail and one other mailbox; mail provider added to the data-processor list in the privacy page.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Resend free plan 3,000 a month and 100 a day; pauses at cap; domains per team differ by source | https://resend.com/pricing.md ; https://resend.com/blog/new-free-tier | 2026-10-31 (search summary) | Medium |
| Brevo free plan 300 a day, shared by marketing and transactional | https://help.brevo.com/hc/en-us/articles/208580669 | 2026-10-31 (search summary) | Medium |
| Render free web services block outbound SMTP ports 25, 465, 587 since 2025-09-26 | https://render.com/changelog/free-web-services-will-no-longer-allow-outbound-traffic-to-smtp-ports | 2026-10-31 (search summary) | Medium to high |
| Resend no-domain test sender limited to the account owner's address | Not verified in this research | 2026-10-31 | Unverified |
| SES price about USD 0.10 per 1,000 | PRD S-5 (comparison sites) | 2026-10-31 | Low to medium |

## Links

Related: ADR-0003, ADR-0022. Detail: deployment/04.
