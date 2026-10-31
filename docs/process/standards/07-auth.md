# Standard 07: Authentication and Authorization (`docs/system/auth.md`)

Owner: `atlas-architect`. Readers: `forge-dev`, `probe-qa`.

Purpose: who can do what and how identity is proven.

Update trigger: a new role, login method or permission. Edit in place with labels.

## Required sections

| # | Section | Content |
| - | ------- | ------- |
| 1 | Header block | |
| 2 | Actors & Roles | Anonymous customer, staff, owner, system |
| 3 | Authentication | Each login flow as a sequence diagram; credential types; token and session lifetimes; renewal; revocation |
| 4 | Authorization | Permission matrix: endpoint group by role |
| 5 | Abuse Protection | Rate limits, lockouts, attempt limits, repeat-request handling |
| 6 | Secrets & Key Handling | Names of secrets and where they live (never values) |
| 7 | Threat Notes | Short list of threats considered and mitigations |
| 8 | Open Questions / Change log | |

## Rules

1. Authorization is enforced on the server. Hiding a control in the app is not protection.
2. Only hashes of one-time codes and refresh tokens are stored.
3. Responses must not reveal whether an account exists.
4. Anything that costs money (SMS) is rate limited and flagged for owner approval.
5. No real secrets, numbers or identifiers in this file.

## Ready gate (before `forge-dev`)

Permission matrix covers every endpoint the feature adds; lifetimes and limits are stated as numbers.

## Quality checklist

A tester writes negative cases (wrong role, expired token, too many attempts) straight from this file.
