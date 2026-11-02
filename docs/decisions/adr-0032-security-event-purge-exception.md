# ADR-0032: Allow the purge of old security events in the append-only trigger

| Field    | Value |
| -------- | ----- |
| ADR      | 0032 |
| Version  | 1.1 [v1.1 | 2026-11-02] |
| Status   | Accepted (owner approved option 1; archive and dump added 2026-11-02; no money) |
| Date     | 2026-11-02 |
| Decider  | owner (option chosen), atlas-architect (write-up) |
| Based on | data-model 3.15, 14 and 15.1 (database change policy); migration `0002_admin_auth.sql`; ADR-0027 (same pattern for `order_event`, migration `0006`) |

## Context

The maintenance task deletes `security_event` rows older than 180 days. Verified on PostgreSQL 16.15 (2026-11-02): trigger `security_event_append_only()` refuses every UPDATE and DELETE, so the purge fails. The table is the audit log of access, so recent rows must stay tamper-proof.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| 1. Replace the trigger function: UPDATE refused; DELETE allowed only when `at` is older than 180 days; other DELETE raises the same append-only error (chosen) | Recent events cannot be erased by any code path; no new moving part | The 180 days live in SQL and in `MaintenancePolicy.securityEventAge` |
| 2. Session flag `app.maintenance` that allows DELETE | One place for the age | Any code that can set the flag can erase the audit log, including recent events |
| 4. Copy rows into an archive table in the same statement as the delete (added with option 1, owner decision 2026-11-02) | A delete never happens without a copy; the audit trail survives the purge | A second table; the archive keeps events past 180 days |
| 3. Drop the trigger, rely on grants | Simple | Weakest guarantee |

## Decision

Option 1 with the archive of option 4 [v1.1 | 2026-11-02], as migration `0007_security_event_purge.sql` (forward-only; being built by forge-dev). The owner decided on 2026-11-02 that both an archive table and a mandatory `pg_dump` before applying migrations are wanted. `0007` also creates `security_event_archive`: same columns as `security_event` plus `archived_at timestamptz not null default now()`, with its own append-only trigger (UPDATE and DELETE refused). The purge is one statement, `WITH moved AS (DELETE FROM security_event WHERE at < now() - interval '180 days' RETURNING *) INSERT INTO security_event_archive SELECT ... FROM moved`, so the rows are copied in the same statement that removes them and a delete cannot happen without a copy. The `pg_dump` rule is the database change policy, data-model section 15.1 ([data-model/05](../system/data-model/05-admin-orders-cakes-settings.md)). A test keeps the SQL age and `MaintenancePolicy.securityEventAge` equal. The go-live gate in data-model section 14 stays open until the database tests pass.

## Consequences

- Positive: the purge works while events younger than 180 days stay append-only.
- Negative: changing the retention needs a new migration and a code change together.
- The archive keeps events past 180 days. OPEN POINT: forge-dev is checking that `security_event` holds no personal data (the design says it has none: no e-mail, no code, only ids, type and platform). If it does hold personal data, the archive design must change (retention or erasure of the archive) before go-live; this ADR is then revised.
- Rejected alternative kept: the session flag `app.maintenance` (option 2) stays rejected, because any code that can set it can erase recent events.

## Sources

- PostgreSQL 16 documentation, "CREATE TRIGGER" and "Trigger Functions" (`TG_OP`, `OLD`, raising an exception from a row-level BEFORE trigger): https://www.postgresql.org/docs/16/sql-createtrigger.html and https://www.postgresql.org/docs/16/plpgsql-trigger.html (read as general reference; the behavior was verified by running it on 16.15).
