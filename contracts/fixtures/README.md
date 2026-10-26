# Contract fixtures

JSON samples of API requests and responses (docs/system/api.md). The backend,
iOS and Android test suites all read these files; a change here is a contract
change and needs the owner of `docs/system/api.md` to agree first.

Fake data only. This repository is public.

| File | Endpoint | Meaning |
| ---- | -------- | ------- |
| `healthz-ok.json` | `GET /healthz` | 200, process (and database when `?deep=1`) healthy |
| `healthz-degraded.json` | `GET /healthz?deep=1` | 503, database query failed or timed out |
