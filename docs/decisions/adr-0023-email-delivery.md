# ADR-0023: E-mail delivery service for sign-in codes

| Field    | Value |
| -------- | ----- |
| ADR      | 0023 |
| Version  | 1.0 |
| Status   | Proposed (money: a sender domain costs about USD 10 to 15 per year; customer data: staff addresses go to a provider) |
| Date     | 2026-10-31 |
| Decider  | atlas-architect proposes; product owner approves the domain and the account |
| Based on | PRD FR-1, FR-43, BR-5, A-8, S-5; TQ-1; ADR-0003 |

## Context

Sign-in codes and recovery notices go out by e-mail. Volume is far below any free tier (tens of people, about one code a week each, plus abuse limits). The API runs on a host that blocks outbound SMTP on free web services (ports 25, 465, 587) since 26 September 2025, so the provider must be reachable by HTTPS. Codes that land in spam break sign-in, so the sender needs SPF, DKIM and DMARC on a domain the shop controls.

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

Option A behind a `MailSender` protocol (`Services/Admin/Mail/`), implemented over HTTPS in `Http/Outbound/`. B is the documented fallback; switching changes one class and one variable. Sender: a subdomain such as `mail.<SHOP_DOMAIN>` with SPF, DKIM and a DMARC record (`p=none` first, then `quarantine` after a week of clean reports). Mail body: plain text in Vietnamese, the code only, no link (a link invites phishing). The send happens after the response; one retry after 5 s; a failure is logged without the address and the person asks for a new code. Global daily cap `MAIL_MAX_PER_DAY` (default 80) protects the provider quota.

Test and local delivery (TQ-1): `MAIL_PROVIDER=recording` in tests (codes read from the recorder); `console` in `local` (code printed to stdout, refused when `APP_ENV` is `staging` or `production`); `AUTH_FIXED_CODE` allowed only in `local` and `staging` (the app refuses to start with it in production). Staging may use the real provider with the operator's own mailboxes.

## Consequences

- Positive: cost USD 0 at this volume besides the domain; no SMTP.
- Negative: a domain is needed (also wanted for the API host, R-8); free plan has a daily cap, so a flood of code requests could block sign-in until the next day (limits in ADR-0022 reduce this; upgrade is about USD 20 a month, unverified).
- Follow-up: owner buys the domain and creates the provider account; operator sets DNS records and checks one test message to Gmail and one other mailbox; mail provider added to the data-processor list in the privacy page.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Resend free plan 3,000 a month and 100 a day; pauses at cap; domains per team differ by source | https://resend.com/pricing.md ; https://resend.com/blog/new-free-tier | 2026-10-31 (search summary) | Medium |
| Brevo free plan 300 a day, shared by marketing and transactional | https://help.brevo.com/hc/en-us/articles/208580669 | 2026-10-31 (search summary) | Medium |
| Render free web services block outbound SMTP ports 25, 465, 587 since 2025-09-26 | https://render.com/changelog/free-web-services-will-no-longer-allow-outbound-traffic-to-smtp-ports | 2026-10-31 (search summary) | Medium to high |
| SES price about USD 0.10 per 1,000 | PRD S-5 (comparison sites) | 2026-10-31 | Low to medium |

## Links

Related: ADR-0003, ADR-0022. Detail: deployment/04.
