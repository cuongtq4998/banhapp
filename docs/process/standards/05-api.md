# Standard 05: API Specification (`docs/system/api.md`)

Owner: `atlas-architect`. Readers: `forge-dev` (backend and mobile clients), `probe-qa`.

Purpose: the contract between clients and server. Contract first: this file is written before the code.

Update trigger: any endpoint, field or error change. Edit in place with labels.

## Required sections

| # | Section | Content |
| - | ------- | ------- |
| 1 | Header block | |
| 2 | Conventions | Base path and versioning, authentication, content type, idempotency, pagination, error format, rate limits |
| 3 | Endpoint Index | Table: method, path, auth/role, purpose, FR traced |
| 4 | Endpoint Specs | One subsection per endpoint (below) |
| 5 | Error Catalogue | Machine-readable code, HTTP status, meaning, client behavior |
| 6 | Compatibility Policy | How the API evolves |
| 7 | Open Questions / Change log | |

### Each endpoint spec contains

Method and path; required role; request parameters and body (table: field, type, required, rules); responses per status (schema table); possible error codes; side effects; idempotency behavior; one example request and response with fake data.

## Rules

1. Additive changes only inside a version (new optional fields). A breaking change creates a new version and keeps the old one until old clients are gone.
2. Clients never send values the server must compute (for example prices and totals).
3. Errors are machine-readable codes plus a human message key; clients show text by code.
4. Field names agree with `data-model.md` and business terms in the PRD.
5. Every endpoint traces to an FR. Examples are valid against the schema and contain fake data.
6. State rate limits and authentication for each endpoint group.

## Ready gate (before `forge-dev`)

Every endpoint the feature needs is fully specified including errors and idempotency.

## Quality checklist

A client developer builds against the spec without asking; a tester writes request cases for every status and error code.
