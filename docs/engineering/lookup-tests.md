# Lookup tests (backend)

Tests of `POST /v1/orders/lookup` (api/10, ADR-0034). Code: `backend/Tests/AppTests/Lookup`, plus
`Admin/OrderAmountToCollectTests.swift` for the admin amount.

## Run the database tests

The database tests (`LookupDatabaseTests`, and every admin test) need a real PostgreSQL 16. They
read `DATABASE_MIGRATION_URL`; when it is unset they are skipped, not failed, so a green run
without it proves nothing about SQL. Always set it for a lookup run.

```
createdb -h 127.0.0.1 -p 54329 -U banh <fresh name>
cd backend
DATABASE_MIGRATION_URL=postgres://banh@127.0.0.1:54329/<fresh name> swift test --filter Lookup
```

Use a brand-new database per full run (migrations and seed rows persist). Check the summary line
shows no skipped tests. The QA package needs `QA_ALLOW_DB_MUTATION=1` as well
(`cd backend/Tests/qa`).

## Which test class covers what

| Class | Covers |
|---|---|
| `LookupSecurityTests` | answer key allow-list, phone forms, 422, cursor binding, identical 429, log privacy |
| `LookupPagingTests` | 10 per page, 5 pages, 50 orders, page 5 has no next cursor, injectable page size |
| `LookupLimitTests` | address (31st refused), installation (21st), cursor accounting, proxy header rules |
| `LookupBodyAndOutageTests` | 8 KB body limit on a live listener, 503 shape and no phone in the log |
| `LookupFloorTests` | `lookup_floor_exceeded` warning line without phone |
| `LookupAmountTests` | `amount_to_collect_vnd` for fee 0, real fee, null fee |
| `LookupDatabaseTests` | real SQL: window edge, order, microsecond cursor, same query for empty phone |

Route tests use `LookupRouteTestCase.start(policy:)` with `FakeLookupStore`; pass a `LookupPolicy`
to change one knob (`pageSize`, `perAddressPerHour`, `clientAddressHeader`, ...). The in-memory
HTTP client skips the body limit, so the size test starts a real listener (like
`RequestBodyLimitTests`).

## Cursor format

The cursor is base64 of `<placed_at microseconds>|<order id>|<page>|<tag>`:

- placed_at is an integer count of microseconds since 1970 (PostgreSQL precision; a rounded
  floating-point time would mis-order orders placed in the same second).
- page counts from 1 and drives the 5 page cap.
- tag is a keyed hash (secret `LOOKUP_KEY_SECRET`) over the normalised phone plus the three
  fields, so a cursor works only for the phone it was issued for and any edit is refused with
  `CURSOR_INVALID`.
- There is no separate version field in the current code: a format change must change the tag
  input so old cursors fail as invalid.

## Configuration knobs (`.env.example`)

| Variable | Default | Effect |
|---|---|---|
| `LOOKUP_KEY_SECRET` | random per process | key of the cursor and limiter hashes |
| `LOOKUP_RETENTION_DAYS` | 30 | window an order stays findable |
| `LOOKUP_FLOOR_MS` | 250 | minimum answer time; slower answers log `lookup_floor_exceeded` |
| `CLIENT_ADDRESS_HEADER` | empty | proxy header read for the client address; empty is the socket peer |
| `TRUSTED_PROXY_HOPS` | 1 | entries counted from the right that belong to trusted proxies |

Page size, page cap and the three hourly budgets are fixed in `LookupPolicy.Default`; tests change
them through the policy value, not the environment.
