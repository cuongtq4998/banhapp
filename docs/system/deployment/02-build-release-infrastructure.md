# Deployment and Operations: Build and release, infrastructure

Part of [deployment.md](../deployment.md) (index, version, change log), sections 4, 5. Moved from deployment.md v1.8 with the wording unchanged unless a line carries a newer label [v1.9 | 2026-10-27].

## 4. Build & Release

Pipeline (GitHub Actions, free for public repositories; macOS runner minutes for public repositories are free, unverified). The Swift backend is built only in CI, never on the host: a release build is slow and memory-heavy (ADR-0001). [v1.1 | 2026-10-25]

CI files [v1.2 | 2026-10-26]: `.github/workflows/backend.yml` (job `test` on `ubuntu-latest` in a `swift:6.2-noble` container with a `postgres:16` service: build, tests, `migrate --yes`, sample seed applied twice; job `image`: image build on pull requests, push to GHCR on main; job `deploy-staging`), `.github/workflows/ios.yml` and `.github/workflows/android.yml`; each is path-filtered to its component. `ubuntu-latest` is Ubuntu 24.04. The workflows do not yet include SwiftLint, a nightly backup or a production job; those arrive with their slices.

Backend CI checks [v1.3 | 2026-10-26]: the `test` job runs `swift test` with `DATABASE_MIGRATION_URL` pointing at the service container, so the database tests of the same `AppTests` target run (without the variable they skip). That variable must never point at staging, production or any database holding data: the tests apply migrations and roll back each test, but a throwaway database is the rule. After the tests the job builds the release binary, starts it with `APP_ENV=local` against the service container and checks the shallow `GET /healthz` (`"status":"ok"`) and the deep `GET /healthz?deep=1` (needs the database), then stops it. A broken release build, startup or database wiring fails the pull request before the image job.

Android CI [v1.3 | 2026-10-26]: `android.yml` installs no packages through the setup action (its licence step exits 1 on the preview-SDK prompt); a step accepts licences with `sdkmanager --licenses` and installs `platforms;android-37.0` and `build-tools;36.0.0` [v1.4 | 2026-10-26] (compileSdk 37 for Compose 1.12, ADR-0007).

iOS runner [v1.4 | 2026-10-26]: `ios.yml` runs on the hosted label `macos-26` (macOS 26, Xcode 26.x; GitHub offers no hosted Xcode 27 image, so the earlier `xcode-27` label was wrong). A step selects the newest installed Xcode. The project file format stays 77 (opens in Xcode 16.3 and newer); do not commit an upgrade to the newer format, which hosted Xcode 26.x cannot open.

Deploy hook rule [v1.4 | 2026-10-26]: Render's documentation says a deploy hook is triggered by a plain `GET` or `POST`, and that a specific image tag or digest is chosen by appending the `imgURL` query parameter (URL-encoded, for example `docker.io%2Flibrary%2Fnginx%401.26`); every part of the URL except the tag or digest must equal the service's configured image URL, otherwise Render rejects the request (source: https://render.com/docs/deploy-hooks and https://render.com/docs/deploy-an-image, read 2026-10-26). The workflow currently sends `imgRef`, which is not a documented parameter: Render would ignore it or reject it, so the staging service would redeploy its configured tag rather than the new commit (dev query: use `imgURL`, and confirm the image tag form against a real hook; unverified until run against the staging service).

Backend deploy job [v1.4 | 2026-10-26]: `deploy-staging` has its own concurrency group with `cancel-in-progress: false`, so a newer push never cancels a deploy after migrations ran but before the hook was called; the build and test jobs keep `cancel-in-progress: true`. The smoke check after the hook retries the shallow and the deep health check, because the free host needs about a minute to wake and swap. The QA package under `backend/Tests/qa` (edge cases and database tests) also runs in the `test` job.

Image visibility rule [v1.5 | 2026-10-26] (ADR-0003 v1.3): the image holds no secret or customer data (checked against `backend/Dockerfile` and `backend/Dockerfile.dockerignore`). A new GHCR package is private; the owner makes it public once in GitHub (package settings, Danger Zone, Change visibility; free, irreversible), after the first push to main. `deploy-staging` logs in to GHCR with `GITHUB_TOKEN` (`packages: read`) so migrations run either way. Render pulls without credentials only when the package is public; a private package would need a registry credential in Render (a read-only token held by the host), which we avoid.

1. Pull request: backend `swift build` and `swift test` on Linux (XCTVapor) against a PostgreSQL service container (including the parallel-order test of AC-22), with the SwiftPM `.build` cache; SwiftLint [v1.1 | 2026-10-25]; Android build and unit tests; iOS build and unit tests (macOS runner); contract fixture checks; lint.
2. Merge to main: build the multi-stage image for `linux/amd64` (Swift toolchain image to build with `--static-swift-stdlib`, slim Ubuntu to run, non-root user), push it to GHCR tagged with the commit (the package starts private; the target state is public, see the image rule below [v1.5 | 2026-10-26]), run migrations (`DATABASE_MIGRATION_URL`) first, then call the staging service's Render deploy hook with the image reference in the `imgURL` query parameter, URL-encoded (Render does not redeploy on push; see the hook rule below [v1.4 | 2026-10-26]; migrations are forward-compatible, data-model.md section 8). [v1.1 | 2026-10-25]
3. Release tag `backend-vX.Y.Z`: operator approves, the same image digest is deployed to production through its deploy hook [v1.1 | 2026-10-25]. The image holds no secrets or data; all configuration comes from environment variables.
4. Mobile: tags `ios-vX.Y.Z` and `android-vX.Y.Z`; signed builds are produced locally or by CI with signing secrets (not in the repository); upload to TestFlight and Play internal testing.

Versioning: backend `MAJOR.MINOR.PATCH`; API version in the path (api.md section 6); mobile marketing version `MAJOR.MINOR.PATCH`, build number increases on each upload.

Changing shop data before the owner slice exists: the operator applies a reviewed SQL change (prices, limit, districts, slots, contacts) in a pull request that touches `backend/db/seed/` or a migration, then runs it with the migration role; setting `is_sample = false` marks real values (ADR-0013).

Store submission notes (unverified until the accounts exist):

| Item | Apple App Store | Google Play |
| ---- | --------------- | ----------- |
| Privacy policy URL | Required; use `https://<API_HOST>/privacy` | Required to complete the Data safety form (support.google.com answer 10787469) |
| Data declared | Contact information: name, phone number, physical address; used for app functionality; linked to the order; not used for tracking | Personal info: name, phone number, address; collected; not shared with third parties; encrypted in transit; no in-app account, so no account deletion flow; deletion on request to the shop |
| Sign-in | None (matches Apple guidance cited in PRD S-2) | None |
| Build requirement | Xcode 26 SDK or later for uploads from 2026-04-28 | Current target API level requirement (check at submission) |
| Review hints | State that payment is outside the app | Same |

The Data safety form must also cover data collected through third-party libraries; the apps use none that collect data (ADR-0007), so the answer stays "none beyond the order".

Launch checklist: real shop data loaded and no `is_sample = true` rows; privacy page text final including data location and retention (BR-12, owner); Zalo and phone tested on devices with and without Zalo; backup restore tested once; uptime monitor and alerts active; store listings approved.

## 5. Infrastructure

| Component | Choice (recommendation) | Reference |
| --------- | ----------------------- | --------- |
| API runtime | One always-on container instance (0.5 vCPU, 512 MB) in a Singapore region, deployed from the repository | ADR-0003 |
| Database | Neon free Postgres, Singapore (`aws-ap-southeast-1`): 1 GB, 100 CU-hours per month, suspend after 5 idle minutes, no expiry stated [v1.1 | 2026-10-25] | ADR-0002, ADR-0003 |
| TLS and domain | TLS by the host. `<API_HOST>` is the host-provided name during the trial; a custom domain is a launch cost to be decided before store release because the name is compiled into the apps (R-8) [v1.1 | 2026-10-25] | Owner approval |
| Backups | Encrypted dumps committed to a private GitHub repository `<BACKUP_REPO>` (free, no card) [v1.1 | 2026-10-25] | Section 6 |
| CI | GitHub Actions | |

Single instance, no autoscaling: expected peak is about 5 requests per second (architecture.md section 8). The free plan is for the trial only; real customers need the paid path (section 9).
