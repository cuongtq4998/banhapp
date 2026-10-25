# ADR-0009: Order code format, phone validation and input limits

| Field    | Value |
| -------- | ----- |
| ADR      | 0009 |
| Status   | Accepted |
| Date     | 2026-10-25 |
| Decider  | atlas-architect |
| Based on | PRD Q-T6; UI TQ-5, TQ-6; FR-8, FR-11, FR-13, FR-18, AC-12, AC-16, AC-26 |

## Context

The customer quotes the order code to the shop over Zalo or the phone. The code must be short, readable aloud, unique and not guessable. Phone numbers must be valid Vietnamese numbers (A-6). Field lengths and a quantity bound protect the system from absurd input.

## Decision Drivers

- Readable and hard to confuse (0/O, 1/I/L).
- Uniqueness guaranteed by the database.
- Validation identical on server and both clients.

## Options Considered

Order code: (1) sequential number (guessable, reveals volume); (2) random Crockford-like code `BT-XXXXXX`; (3) UUID (too long to dictate); (4) date prefix plus sequence (reveals volume).

Phone: (1) mobile only, 10 digits starting `0` plus `3`, `5`, `7`, `8` or `9`, or the `+84`/`84` form; (2) also landlines; (3) any international number; (4) full prefix allow-list.

## Decision

**Order code.** Format `BT-` followed by 6 characters from the 31-character alphabet `23456789ABCDEFGHJKMNPQRSTUVWXYZ` (no 0, 1, I, L, O), uppercase, drawn from a cryptographically secure random source. Example `BT-7K3M9Q`. About 887 million values. A unique index on the code is the guarantee; on collision the server draws again (up to 5 times, then fails with 500). Display width 9 characters; `OrderCodeDisplay` may group as `BT-7K3 M9Q` for reading but copies the plain code. Input from the customer to the shop is case-insensitive. The code is not a secret and gives no access to data (there is no lookup endpoint in this slice).

**Phone.** Client and server normalise: remove spaces, dots, hyphens and parentheses; convert a leading `+84` or `84` (when 11 digits) to `0`. Valid when the result matches `^0[35789][0-9]{8}$` (10 digits). Stored as E.164 (`+84` plus the nine digits without the leading 0). Landlines and foreign numbers are rejected with `ERR_PHONE_INVALID` because the shop contacts customers by Zalo or mobile call (A-6) and Zalo needs a mobile number. The pattern checks the first digit after 0 only, not operator prefixes, because prefix lists differ between sources and change.

**Lengths** (counted in Unicode code points after NFC normalisation and trimming of leading and trailing whitespace; Vietnamese text must be NFC so that composed and decomposed forms count the same):

| Field | Min | Max |
| ----- | --- | --- |
| Name | 1 | 100 |
| Address | 1 | 250 |
| Note | 0 | 200 (PRD FR-18) |

Clients limit input to these maxima (like the note counter); the server rejects longer values with `VALIDATION_FAILED`. Control characters (except newline in address and note) are rejected.

**Quantity.** One cake: 1 to 99 (the stepper stops at 99; configuration key `max_qty_per_cake`, default 99). This is an input-safety bound, not a business rule. The PRD limit per order is only the remaining amount of the date; if a shop sets DAILY_LIMIT above 99 per cake and needs more, the owner raises `max_qty_per_cake` in configuration.

## Consequences

- Positive: codes are dictatable; one validation spec for three implementations; fixtures in `contracts/fixtures/validation.json`.
- Negative: a customer with a landline only cannot order (the shop can add a rule later).
- Follow-up: the privacy sentence on S-8 already covers the data; no UI text change is needed because maxima are enforced by input limits.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Vietnamese mobile numbers: leading 0 then 9, 8, 7, 5 or 3, 10 digits in total; country code 84 | https://en.wikipedia.org/wiki/Telephone_numbers_in_Vietnam | 2026-10-25 | Medium |
| Operator prefix lists differ between vendor sources | https://sent.dm/resources/VN and others | 2026-10-25 | Low (hence no prefix allow-list) |
| Order code entropy: 31^6 = 887,503,681 | Calculation | 2026-10-25 | High |
| Unicode NFC normalisation for Vietnamese diacritics | Unicode standard, not fetched | 2026-10-25 | Unverified |

## Links

Related: ADR-0008.
