# Deployment and Operations

| Field        | Value |
| ------------ | ----- |
| Version      | 1.10 [v1.10 | 2026-10-31] |
| Last updated | 2026-10-31 |
| Status       | Draft |
| Owner        | atlas-architect (design), forge-dev (keeps it true) |
| Based on     | architecture.md v1.0; product/place-order.md v1.2; product/admin-orders.md v1.2 [v1.10 | 2026-10-31] |
| Related      | ADR-0001 to ADR-0005; ADR-0021 to ADR-0027; auth.md; data-model.md |

Provider names in the body are the free trial setup of ADR-0003 (Accepted for the trial; no spend). The repository holds only variable names; no hostnames, accounts or keys.

This file is the index of the deployment document. The body lives in the folder `deployment/`, split by topic so that no file passes 200 lines (CLAUDE.md "Project rule: file size"). Section numbers are unchanged: "deployment.md section 3.1" still means the same text, found through the map below. [v1.9 | 2026-10-27]

## Section map [v1.9 | 2026-10-27]

| Section | Subject | File |
| ------- | ------- | ---- |
| 1, 2 | Environments, roles | [deployment/01-environments-and-configuration.md](deployment/01-environments-and-configuration.md) |
| 3, 3.1 | Configuration variables, client address behind the host proxy | [deployment/01-environments-and-configuration.md](deployment/01-environments-and-configuration.md) |
| 4 | Build and release, CI, store submission, launch checklist | [deployment/02-build-release-infrastructure.md](deployment/02-build-release-infrastructure.md) |
| 5 | Infrastructure | [deployment/02-build-release-infrastructure.md](deployment/02-build-release-infrastructure.md) |
| 6 | Backup and restore | [deployment/03-operations-and-cost.md](deployment/03-operations-and-cost.md) |
| 7 | Observability and alerts | [deployment/03-operations-and-cost.md](deployment/03-operations-and-cost.md) |
| 8 | Rollback | [deployment/03-operations-and-cost.md](deployment/03-operations-and-cost.md) |
| 9 | Cost notes | [deployment/03-operations-and-cost.md](deployment/03-operations-and-cost.md) |
| 11 to 17 | Admin configuration, environments, build and release, infrastructure (mail, push, images), backup addition, alerts, cost and launch checklist [v1.10 \| 2026-10-31] | [deployment/04-admin-delivery-config.md](deployment/04-admin-delivery-config.md) |
| 10 | Open questions and change log | this file |

## 10. Open Questions / Change log

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |
| DP-Q1 | Owner approval of costs in section 9 and hosting choice (ADR-0003) | Money, customer data | No | business | Closed for the trial (free plans, 2026-10-25); paid path needs approval later | Owner |
| DP-Q2 | Operator name and alert email | Alerts need an owner | Yes for launch | business | Open (owner) | |
| DP-Q3 | Is a staging environment wanted before launch | Free on the trial plans; paid later | No | business | Resolved for the trial: yes, free | Architect |
| DP-Q4 | Owner approval of the domain, mail provider account, paid hosting and store accounts for the admin apps (ADR-0003 v1.4, ADR-0023, ADR-0026) | Money | Yes for go-live | business | Open (owner) | Recommendation: approve all four before the admin launch [v1.10 \| 2026-10-31] |

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | First version. |
| 1.1 | 2026-10-25 | Swift/Vapor image build in CI, GHCR and deploy hook, free trial hosting (Render, Neon), shallow and deep health checks, GitHub backup repository, costs restructured. |
| 1.2 | 2026-10-26 | After slice 0: CI files and runners, which health endpoint each consumer uses, `DATABASE_URL` optional locally, variables read only from later slices, sample-row warning moved to slice 4. |
| 1.3 | 2026-10-26 | CI: release binary smoke test, database tests in the `AppTests` target (throwaway database only), Android platform 37 and explicit licence step. |
| 1.4 | 2026-10-26 | After backend round 2: `migrate` needs only `APP_ENV` and `DATABASE_MIGRATION_URL`; iOS runner corrected to `macos-26`; Android platform `android-37.0`; deploy job concurrency, smoke retry, QA package in CI; deploy hook parameter checked against Render docs (`imgURL`, not `imgRef`). |
| 1.5 | 2026-10-26 | D-12: image visibility and pull credentials, CI login before migrations, owner action to make the package public. |
| 1.6 | 2026-10-26 | DOC-1, DOC-3: `PUBLIC_ASSET_BASE_URL` rule, shared read budget wording, asset folder. |
| 1.7 | 2026-10-26 | DOC-12: proxy-count assumption and client address rule (section 3.1), `TRUST_PROXY` needed from slice 1, `SHOP_ID` from slice 1 confirmed. |
| 1.8 | 2026-10-27 | Section 3.1: one-proxy assumption contradicted by the host's articles; pointer to ADR-0019. |
| 1.10 | 2026-10-31 | admin-orders: new file 04 (variables for auth, mail, push, images; admin CI and release; store notes; mail, push and image infrastructure; backup and restore addition; alerts; cost and launch checklist). Paid hosting is a go-live prerequisite for real use (ADR-0003 v1.4). Question DP-Q4 added. |
| 1.9 | 2026-10-27 | Split into the folder `deployment/` (file size rule, 200 lines); this file became the index with a section map. No content change. |
