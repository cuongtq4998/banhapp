# ADR-0003: Hosting and running cost

| Field    | Value |
| -------- | ----- |
| ADR      | 0003 |
| Version  | 1.3 |
| Status   | Accepted for the trial phase, free plans only (owner direction: no spend during the new-project phase). Becomes Proposed again if any step asks for a payment card or a recurring cost [v1.1 | 2026-10-25] |
| Date     | 2026-10-25 (v1.1 2026-10-25) |
| Decider  | Product owner (direction); atlas-architect (choice within it) |
| Based on | PRD Q-T5 and non-functional "Cost"; ADR-0001, ADR-0002 |

## Context

The owner wants a free option to run a trial first; no spend during the new-project phase [v1.1 | 2026-10-25]. The stack is a Swift (Vapor) Docker container and PostgreSQL (ADR-0001, ADR-0002). The order must answer within 10 seconds (PRD section 8), which free plans that sleep can break on the first request after idle. Customers are in Vietnam; Singapore is the nearest region.

## Decision Drivers

- Zero cost and no payment card.
- Runs a prebuilt Docker image (Swift builds are too slow and heavy for a free builder, ADR-0001).
- A database that does not expire.
- Reversible: only an image and `DATABASE_URL` tie the system to a host.

## Options Considered (all researched 2026-10-25; limits change, re-check before use)

| Option | Cost, card | Limits | Verdict |
| ------ | ---------- | ------ | ------- |
| A. Render free web service (Docker image) + Neon free Postgres | USD 0. Render: no card stated on its free page and per a comparison article (medium). Neon: card requirement not confirmed from official page (unverified) | Render: 750 instance-hours per workspace per month, 512 MB, spins down after 15 minutes without traffic, wake about 1 minute, ephemeral disk, one instance, 5 GB bandwidth, outbound SMTP blocked. Public GHCR images can be deployed (linux/amd64), no auto-deploy on push: use the deploy hook. Singapore is a Render region; free availability there not stated (unverified). Neon: 1 GB storage, 100 CU-hours per month (about 400 hours of the 0.25 CU compute), suspend after 5 minutes idle (about 0.5 s to a few seconds to resume), 6-hour restore window, no stated expiry, Singapore (`aws-ap-southeast-1`) available | **Recommended** |
| B. Render free Postgres | USD 0 | Expires 30 days after creation, 14 days grace then deleted, no backups | Rejected (expiry) |
| C. Koyeb free | Card required since February 2026 ($29 pre-authorisation hold) per a comparison article (medium) | Web service Frankfurt or Washington only; database 5 compute-hours per month | Rejected (card, region) |
| D. Fly.io, Google Cloud Run, Oracle Cloud, Azure Container Apps | Card required (comparison article, medium) | | Rejected (card) |
| E. Railway | $5 trial then $1 per month credit, shared with Postgres | Pauses when credit ends | Rejected (not sustainable) |
| F. SnapDeploy / Back4App | Free containers | 100 hours per month; database paid; 60-minute runs | Rejected |
| G. Paid always-on (upgrade path) | About USD 7 per month for Render Starter (estimate); Neon paid plan with auto-suspend off, about USD 15 to 20 more (estimate) | None of the sleep problems | Later, owner approval |

## Decision [v1.1 | 2026-10-25]

Trial setup, zero cost: **Render free web service running the backend image** (built in GitHub Actions, published as a public image on GHCR, deployed by calling the Render deploy hook) and **Neon free Postgres project in Singapore**. The repository is public and contains no secrets, so a public image is acceptable; the image must contain no data or credentials. Secrets are set only in the host dashboards. Status is Accepted because both services are free and, per the sources above, create accounts without a card. **Stop condition:** if creating either account asks for a payment card, or a free limit changes into a charge, the status returns to Proposed and the owner decides.

Trade-offs the owner accepts, and how the system copes:

| Trade-off | Effect | Coping |
| --------- | ------ | ------ |
| Render sleeps after 15 idle minutes, wake about 1 minute | First request after idle can take about 60 s, beyond the 10 s order timeout | The apps request the catalog at launch (S-1, FR-1), which wakes the server while the customer browses; reads have a 15 s timeout, and the app retries the catalog once automatically and shows the cached copy meanwhile (ADR-0011); an order sent on a cold server shows `ERR_TIMEOUT` and the same-key retry returns the stored result or creates the order once (AC-19). A real customer rarely orders in under 15 idle minutes after opening the app |
| Neon suspends after 5 idle minutes | First query after idle adds about 0.5 s to a few seconds | Covered by the order timeout; `/healthz` does not touch the database (so monitors never keep the database awake and never burn CU-hours) |
| 100 Neon CU-hours per month | A 24/7 awake database would need about 186 CU-hours | No keep-alive on the database; sized for a trial |
| 750 Render hours per workspace | One always-awake service fits (744 hours); two always-awake services do not | Staging service sleeps; optional keep-warm pings only for the production service and only in business hours (Render's terms on pings not verified; off by default) |
| No backups on Render; Neon 6-hour restore window only | Data loss risk | Nightly encrypted dump to a private GitHub repository (free, deployment.md section 6) |
| Free terms are not a contract | Plan may change | Alerts; the upgrade path below |
| Default hostname on the host's domain | The API base URL is compiled into the apps | For the trial use the host-provided name; before store release the owner should decide a custom domain (launch cost) so the host can change without an app update |

Upgrade path to paid always-on (owner approval needed): (1) Render Starter instance (about USD 7 per month, estimate) for the API, no code change; (2) Neon paid plan with auto-suspend disabled (about USD 15 to 20 more, estimate) or any managed Postgres: change `DATABASE_URL`, restore from a dump; (3) optionally a custom domain. Trigger: alert on order p95 over 8 s, storage over 80%, CU-hours over 80%, or launch with real customers.

Launch costs, listed and not decided here: Apple Developer Program (about USD 99 per year, unverified), Google Play registration (about USD 25 once, unverified), custom domain (about USD 10 to 15 per year, unverified), paid hosting from the upgrade path.

## Image visibility and pull credentials [v1.3 | 2026-10-26]

Technical decision (QA defect D-12), no cost and no data exposed.

- Check: `backend/Dockerfile` copies only the compiled binary, `ca-certificates`, `tzdata` and `backend/db` (SQL migrations and sample seed, which are already in the public repository). `backend/Dockerfile.dockerignore` excludes `.git`, `.env`, `.build` and `.swiftpm`. All configuration comes from environment variables set in the host and CI secret stores. The image therefore holds no secret and no customer data, and publishing it exposes nothing the public repository does not.
- A package first pushed to GHCR is private (GitHub docs). Making it public is a one-time owner action in the GitHub web UI (package page, Package settings, Danger Zone, Change visibility, Public, type the package name). It is free, and it cannot be undone. Nothing in `GITHUB_TOKEN` or the workflow can do it. The package exists only after the first successful push to main.
- Until the owner has done that: CI does not depend on it. `deploy-staging` logs in to `ghcr.io` with `GITHUB_TOKEN` (job permission `packages: read`) before `docker run ... migrate --yes`, so migrations work with the package private or public.
- Render: a service that pulls a private image needs a registry credential in the workspace (for GHCR a GitHub personal access token with `read:packages`). A public image needs none. Decision: keep the target state **public package, no credential in Render**, because a long-lived personal token held by the host is a standing secret we avoid. Until the owner makes the package public, the first Render deploy from the hook fails to pull; this does not block migrations or the build, and the staging deploy simply stays on its previous image. If the owner prefers a private package, the fallback is a credential with a fine-scoped read-only token created by the owner; whether the free instance type accepts a registry credential is **unverified** (the Render image documentation lists no plan restriction, the credentials page could not be read), so that fallback needs a check at the time.
- Optional hardening for the developer: add the label `org.opencontainers.image.source` (the repository URL) so GitHub links the package to the repository (unverified effect on visibility: linking does not by itself make it public).
- Owner TODO (not blocking): make the backend package public once, after the first push to main.

## Consequences

- Positive: USD 0 for the trial; no accounts with a card.
- Negative: slow first request after idle; free limits can change; a real-customer launch should move to the paid path.
- Follow-up: the owner creates the accounts (owner task); privacy policy states the data location (Singapore, unverified until created); retention period (BR-12) is still owed.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Render free web service: 750 hours, spin down after 15 minutes, about 1 minute wake, ephemeral disk, one instance; free Postgres 1 GB, expires after 30 days, 14 days grace, no backups | https://render.com/docs/free | 2026-10-25 | High |
| Render regions include Singapore (free availability not stated) | https://render.com/docs/regions | 2026-10-25 | Medium |
| Render deploys public images from any registry (GHCR), linux/amd64, deploy hook, no auto-deploy on push | https://render.com/docs/deploy-an-image | 2026-10-25 | High |
| Render deploy hook: plain GET or POST; a specific image is chosen with the `imgURL` query parameter (URL-encoded), other URL parts must match the service's image URL [v1.2 \| 2026-10-26] | https://render.com/docs/deploy-hooks ; https://render.com/docs/deploy-an-image | 2026-10-26 | High |
| A new GHCR package is private; making it public is done in package settings and cannot be reversed [v1.3 \| 2026-10-26] | https://docs.github.com/en/packages/learn-github-packages/configuring-a-packages-access-control-and-visibility | 2026-10-26 | High |
| Render private images need a registry credential (GHCR: personal access token with `read:packages`); no free-plan statement on that page [v1.3 \| 2026-10-26] | https://render.com/docs/deploy-an-image | 2026-10-26 | High for the credential, unverified for the free instance type |
| Neon free plan: 1 GB per project, 100 CU-hours, suspend after 5 minutes, 6-hour restore | https://neon.com/docs/introduction/plans | 2026-10-25 | High |
| Neon Singapore region `aws-ap-southeast-1` | https://neon.com/docs/introduction/regions | 2026-10-25 | High |
| Neon resume time 500 ms to a few seconds | Search result of Neon connection latency docs (https://neon.com/docs/connect/connection-latency) | 2026-10-25 | Medium |
| No card for Render; card for Koyeb (since February 2026), Cloud Run, Oracle, Azure, Fly.io after trial; Railway $1 monthly credit; Render bandwidth 5 GB | https://snapdeploy.dev/blog/free-cloud-deployment-platforms-2026-comparison (secondary, vendor of a competing service) | 2026-10-25 | Medium |
| Koyeb pricing page shows no free web plan, free Postgres 5 hours | https://www.koyeb.com/pricing | 2026-10-25 | Medium |
| Neon needs no card for the free plan | Not confirmed from an official page | 2026-10-25 | Unverified |
| Render Starter about USD 7 per month | https://render.com/articles/how-much-does-cloud-application-hosting-cost-for-small-businesses | 2026-10-25 | Medium |
| Store and domain fees | Not researched | 2026-10-25 | Unverified |

## Links

Related: ADR-0001, ADR-0002, ADR-0004.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | Proposed, paid always-on recommended (about USD 7 per month). |
| 1.1 | 2026-10-25 | Owner asked for a free trial: free Render plus Neon recommended and Accepted for the trial; coping measures, stop condition and upgrade path. |
| 1.2 | 2026-10-26 | Source added for deploy hook usage (`imgURL`); decision unchanged. |
| 1.3 | 2026-10-26 | Image visibility and pull credentials decided (D-12): public package by owner action, CI logs in meanwhile, Render credential only if private; image content checked for secrets. |
