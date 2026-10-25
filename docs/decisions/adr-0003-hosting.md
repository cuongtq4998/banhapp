# ADR-0003: Hosting and running cost

| Field    | Value |
| -------- | ----- |
| ADR      | 0003 |
| Status   | Proposed (pending owner choice; escalated: costs money, holds customer data) |
| Date     | 2026-10-25 |
| Decider  | Product owner (recommendation by atlas-architect) |
| Based on | PRD Q-T5 and non-functional "Cost"; ADR-0001, ADR-0002 |

## Context

The shop wants low cost and simple operation. The backend must answer an order within 10 seconds (PRD section 8) and hold personal data of customers in Vietnam. No cost ceiling was given (Q-T5). Customers and the shop are in Vietnam, so a nearby region (Singapore) lowers latency.

## Decision Drivers

- Monthly cost, and no hidden idle shutdowns that break the 10-second target.
- Little operations work (no server patching).
- Managed backups or an easy way to make them.
- Region close to Vietnam; data kept to one provider region.

## Options Considered

Cost figures are estimates from public pages (see Sources) and must be re-checked at purchase.

| Option | Estimated cost | Pros | Cons |
| ------ | -------------- | ---- | ---- |
| A. Container PaaS always-on instance (Render Starter, Singapore region) plus managed Postgres on Neon free plan | About USD 7 per month | Simple Git-based deploys; always-on API; free database with scale-to-zero; TLS included | Database cold start after 5 idle minutes; free database limits (0.5 GB) and plan terms may change; two vendors |
| B. Same as A but Neon Launch plan with idle suspend disabled | About USD 7 plus about USD 15 to 20 per month (pay-as-you-go compute, estimate) | No database cold start | Higher cost |
| C. Supabase Pro (Postgres and hosting of the API as functions or separate host) | USD 25 per month plus API host | Single vendor for database and auth (useful for later staff login) | Highest cost; free plan pauses after a week idle, so unusable for production |
| D. One small VPS (about USD 5 per month) running API and Postgres | About USD 5 per month | Cheapest, one bill | The shop operates the OS, patches and backups; single point of failure |
| E. Cloudflare Workers plus D1 | About USD 5 per month or free | Cheapest managed | Conflicts with ADR-0001 option A and ADR-0002 option A |
| F. Free web service tier of a PaaS | USD 0 | Free | Spins down after 15 idle minutes with about one minute restart: breaks the 10-second target; rejected |

## Decision (recommended: option A)

API on a container PaaS instance (always on) in a Singapore region, database on managed Postgres free plan in the same region, scheduled encrypted dumps to separate object storage (deployment.md section 6). Move to option B if cold starts hurt (alert in deployment.md section 7). Estimated total about USD 7 per month plus store fees (deployment.md section 9). Provider names are the recommendation; the repository documents only variable names, so a provider change is a configuration change.

## Consequences

- Positive: cost is predictable and low; no server maintenance.
- Negative: free database terms are not a contract; plan changes may force a paid plan.
- Follow-up: owner approves the monthly cost and creates the accounts (owner task); privacy policy states the data location (Singapore region, unverified until the account is created); retention period (BR-12) is still owed by the owner.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Render Starter about USD 7 per month, 0.5 vCPU, 512 MB; free web services idle after 15 minutes and restart takes about a minute | https://render.com/articles/how-much-does-cloud-application-hosting-cost-for-small-businesses | 2026-10-25 | Medium |
| Neon free plan and Launch plan idle suspend after 5 minutes (Launch can disable); Launch compute about USD 0.106 per CU-hour | https://neon.com/pricing | 2026-10-25 | Medium |
| Supabase Pro USD 25 per month; free plan pauses after 1 week | https://supabase.com/pricing.md | 2026-10-25 | Medium |
| Workers Paid plan USD 5 per month minimum | https://developers.cloudflare.com/workers/platform/pricing/ | 2026-10-25 | Medium |
| Singapore regions offered by Render and Neon | Not fetched | 2026-10-25 | Unverified |
| VPS price of about USD 5 per month | Not researched | 2026-10-25 | Unverified |

## Links

Related: ADR-0001, ADR-0002, ADR-0004.
