# ADR-0001: Backend language and framework

| Field    | Value |
| -------- | ----- |
| ADR      | 0001 |
| Status   | Proposed (pending owner choice; escalated: hard to reverse) |
| Date     | 2026-10-25 |
| Decider  | Product owner (recommendation by atlas-architect) |
| Based on | product/place-order.md v1.2; Q-T1, Q-T5 |

## Context

The slice needs a small HTTP JSON backend: read shop data, compute date availability, accept an order inside one database transaction. Expected load is tiny (see architecture.md section 9). Later slices add staff login (one-time code), order handling and owner configuration. The repository already uses Node.js for developer tooling (`tools/ddagent`).

## Decision Drivers

- Low running cost and low operations effort for a small shop.
- Strong typing and schema validation of request bodies.
- Wide hosting choice (any container host), so the hosting decision (ADR-0003) stays reversible.
- One person can maintain it; large ecosystem for later needs (SMS one-time code, push notifications).

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. TypeScript on Node.js (Fastify, zod, `pg`) | Largest hosting support; small container; schema validation with the same types; same runtime already present in the repo tooling; rich libraries for later slices | Two ecosystems unrelated to the mobile languages; runtime type safety depends on validation at the edge |
| B. Kotlin with Ktor | Same language as the Android app; strong types | Heavier runtime (JVM memory, 512 MB hosts are tight); fewer cheap hosts; slower cold starts |
| C. Swift with Vapor | Same language as the iOS app | Smallest ecosystem and hosting support; fewer maintainers; Linux tooling friction |
| D. Go (net/http, pgx) | Tiny memory, single binary | A third language for the shop; fewer ready libraries for later slices |
| E. Serverless on Cloudflare Workers (TypeScript) with D1 | Lowest idle cost | Different runtime and SQLite database (see ADR-0002); weaker transaction model; ties code to one vendor |

## Decision (recommended: option A)

Node.js (current Active LTS at build time; Node 24 or newer, verify) with TypeScript in strict mode, Fastify as the HTTP framework, zod for request validation and the `pg` driver with plain SQL. Reasons: the lowest-risk path to a cheap container host, a single typed language for contract fixtures and tests, and room for the later slices without a rewrite. Plain SQL (no heavy ORM) keeps the atomic capacity statement in ADR-0008 visible and testable.

## Consequences

- Positive: any container host works; small image; fast local development.
- Negative: dependency hygiene (npm audit) must be part of CI.
- Follow-up: repository path `backend/` (ADR-0004); test runner is the built-in `node:test` or Vitest (forge-dev picks one and records it in the dev guide).
- If the owner chooses another option, architecture.md, deployment.md and the repo paths are rewritten; the data model and API do not change.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Cloudflare Workers paid plan has a USD 5 monthly minimum; D1 free tier caps writes at 100,000 rows per day | https://developers.cloudflare.com/d1/platform/pricing/ | 2026-10-25 | Medium (search summary of official page) |
| Render Starter web service is about USD 7 per month, always on | https://render.com/articles/how-much-does-cloud-application-hosting-cost-for-small-businesses | 2026-10-25 | Medium |
| JVM and Swift server memory and hosting claims in the table | Not researched | 2026-10-25 | Unverified |
| Node.js release schedule (LTS line in October 2026) | Not fetched | 2026-10-25 | Unverified |

## Links

Supersedes: none. Related: ADR-0002, ADR-0003, ADR-0004.
