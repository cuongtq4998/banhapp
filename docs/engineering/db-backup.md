# Database backup before a migration

Version 1.0 [v1.0 | 2026-11-02]. Owner rule: every database change is a numbered, forward-only migration file in `backend/db/migrations/`, and a backup is taken first. Rollback is a restore of that backup; there are no down scripts. Related: data-model/05 section 15 (policy), data-model/06 (migrations 0008 and 0009).

## 1. Take the dump

Use the migration role's URL (`DATABASE_MIGRATION_URL`, see `.env.example`). Stop the old backend first when the migration is not additive (0008 and 0009 are not), so no write lands after the dump.

```
pg_dump "$DATABASE_MIGRATION_URL" --format=custom \
  --file="<database>_<YYYY-MM-DD>_<last applied migration>.dump"
```

Example name: `banh_2026-11-02_0007.dump`. The last applied migration number is in the name so a restore shows which file to apply next. Custom format is compressed and lets `pg_restore` pick objects; plain SQL is not used.

## 2. Where the dump is kept

- Outside the repository, never committed (a dump holds customer phone numbers and addresses).
- Encrypted at rest, on storage the operator controls (an encrypted volume or an encrypted bucket); access limited to the operator.
- Kept at least until the migrated release has run one full business day without a rollback, then removed on the retention schedule of BR-12.
- Do not copy a dump to a laptop, chat or ticket. For local rehearsal use a dump of fake data only.

## 3. Restore into an empty database

Always into a new, empty database, never over the live one.

```
createdb <restore database>
pg_restore --dbname="<URL of the restore database>" --no-owner --exit-on-error \
  <database>_<YYYY-MM-DD>_<last applied migration>.dump
```

`--no-owner` lets a role of the target server own the objects; `--exit-on-error` stops at the first problem instead of leaving a half restore. A real rollback is this restore followed by pointing the backend at the restored database (or renaming databases), then deploying the previous release.

## 4. A dump counts only after a test restore

A file that was never restored is not a backup. Before the migration is applied:

1. Restore the fresh dump into an empty database (section 3).
2. Compare the row count of every table with the source. Run this on both databases and diff the output:

```
psql "<URL>" -Atc "select relname || '=' || (xpath('/row/c/text()',
  query_to_xml('select count(*) c from ' || quote_ident(relname), false, true, '')))[1]
  from pg_class where relkind = 'r' and relnamespace = 'public'::regnamespace
  order by relname"
```

3. Drop the test database. Only then apply the migration (`migrate` command, or the deploy job once it checks for the dump).

## 5. Rehearsal record

Run on a throwaway PostgreSQL 16 on a local port, 2026-11-02, fake data:

| Step | Result |
| ---- | ------ |
| Database with migrations 0001 to 0007, rows in `shop`, `district`, `delivery_slot`, `customer_order` (3) and `order_event` (1) | built |
| `pg_dump --format=custom` | file of about 58 KB |
| `pg_restore --no-owner --exit-on-error` into an empty database | no error |
| Row counts of the 16 tables, source against restore | identical (`diff` empty) |
| Triggers in the restored database | 9 |

Repeat the rehearsal on a copy of production data (fake-masked) before the first real migration that is not additive.
