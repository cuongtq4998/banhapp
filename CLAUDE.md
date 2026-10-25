# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

Git repo (no commits yet). Two unrelated parts:

- `BanhApp/`, `BanhAppTests/`, `BanhAppUITests/`, `BanhApp.xcodeproj` — a multiplatform SwiftUI app (iOS, iPadOS, macOS, tvOS, visionOS; deployment targets iOS 15.0 / tvOS 15.0 / macOS 12.0 / visionOS 1.0, Swift 5.0). Currently the Xcode template stub (`BanhApp.swift` → `ContentView`), with XCTest unit/UI test targets.
- `tools/ddagent/` — a dependency-free Node.js (CommonJS) daemon + web dashboard that manages a pool of Xcode DerivedData slots across many iOS simulators. It is developer tooling, not part of the app target.

## Swift app

`xcodebuild` needs full Xcode; the active developer dir is currently Command Line Tools, so either run `sudo xcode-select -s /Applications/Xcode-27.1.0-Release.Candidate.app` once, or prefix commands with `DEVELOPER_DIR=/Applications/Xcode-27.1.0-Release.Candidate.app/Contents/Developer` (no sudo; verified to build).

```
xcodebuild -project BanhApp.xcodeproj -scheme BanhApp build
xcodebuild -project BanhApp.xcodeproj -scheme BanhApp test -only-testing:BanhAppTests/BanhAppTests/testExample
```

Build every platform (append `CODE_SIGNING_ALLOWED=NO`; all verified to build):

```
for d in "generic/platform=iOS Simulator" "generic/platform=iOS" "generic/platform=macOS" \
         "generic/platform=tvOS Simulator" "generic/platform=visionOS Simulator"; do
  xcodebuild -project BanhApp.xcodeproj -scheme BanhApp -destination "$d" build
done
```

Platforms and targets live in `SUPPORTED_PLATFORMS`, `TARGETED_DEVICE_FAMILY` (1,2,3,7 = iPhone, iPad, tvOS, visionOS) and the `*_DEPLOYMENT_TARGET` settings in `project.pbxproj`. Code must stay compatible with iOS 15 / macOS 12 (guard newer APIs with `#available`).

## ddagent (`tools/ddagent`)

```
node --test test/ddagent.test.js                   # all tests (npm test); `node --test test/` fails on Node 26
node --test --test-name-pattern="<name>" test/ddagent.test.js    # single test
bin/ddagent doctor | run | prewarm | status | dashboard
node server.js                                     # run daemon directly (npm start)
```

Add `--mock` or `DDAGENT_MOCK=1` to run without Xcode (use this for development and tests). `.claude/settings.json` sets `DDAGENT_MOCK=1` by default, so `unset DDAGENT_MOCK` for real runs. ddagent only drives iOS/iPadOS simulators (its backend hardcodes `generic/platform=iOS Simulator`); the iOS 15.5 and 16.0 runtimes are unusable on this host, so use 17.5+ (e.g. `--target "iPhone 16"`). State lives in `~/.ddagent` (override `DDAGENT_HOME`). Env: `DDAGENT_PORT` (7777), `DDAGENT_MAX_LANES` (4), `DDAGENT_MAX_SLOTS` (= max lanes), `DDAGENT_MIN_FREE_GB` (5; below it no new slot is created and the job fails fast), `DDAGENT_NO_OPEN` (skip auto-opening the dashboard; the first `run`/`lane acquire` opens it once, later ones see it already open), `DDAGENT_MOCK_SPEED`.

### Architecture

`bin/ddagent` is a CLI client; `server.js` is the HTTP daemon (REST under `/api/*`, SSE at `/events`, token auth via `~/.ddagent/token`) serving `dashboard/index.html`. It wires together four `lib/` pieces:

- `runner.js` — a job = allocate slot → build (if needed) → per target: boot → install → launch. Uses `Semaphore`/`KeyedLock` (from `util.js`) to bound cold-build and boot parallelism.
- `pool.js` — the DerivedData slots. Two distinct concepts: a *build lease* (held only while `xcodebuild` runs) and *bindings* (which simulator targets have a slot's product installed; persisted). Enforces max slots and min free disk.
- `fingerprint.js` — computes the cache key from build context (project, scheme, config, sdk, arch, Xcode build/SDK) plus content hashes of all build-relevant files (not just `.swift`; skips `tools`, `Pods`, `DerivedData`, etc.). Key match + existing product ⇒ `cache-hit` (build skipped); same context with changed sources ⇒ `incremental`; empty slot ⇒ `cold`. If you add a file type that affects builds, add it to `EXT` there.
- `backend.js` — `realBackend` (xcodebuild/xcrun, with retry on transient CoreSimulator errors) and `mockBackend` share one interface; new backend operations must be implemented in both.
- `lanes.js` — per-agent exclusive hold on one *existing* simulator (never created). At most `DDAGENT_MAX_LANES` (4) lanes; further `lane acquire` calls block FIFO until a release or idle expiry (`DDAGENT_LANE_TTL_MIN`, never while a job runs). `run --lane` resolves to the lane's simulator, and `pool.js` prefers the slot already bound to that simulator, so one agent keeps reusing the same DerivedData. See `.claude/skills/ddagent-lane`.
- `store.js` — single-writer JSON state (`state.json`, schema-versioned, atomic debounced writes); only the daemon touches it.

## Agent pipeline (`/feature`)

Features are built by a pipeline of subagents orchestrated from this session. Read `docs/process/README.md` before working on it; document standards are in `docs/process/standards/`.

- Agents: `scribe-requirements` (PRD), `canvas-ui` (UI spec), `atlas-architect` (system docs, ADRs), `forge-dev` (code), `probe-qa` (tests). Definitions are in `.claude/agents/`; the entry point is `/feature <business description>`.
- The product owner provides business intent only. Agents decide technical matters, research them and record sources. Ask the owner only for money, security or customer data, hard-to-reverse choices, or differing business behavior; ask everything in one batch.
- The owner approves exactly two points: the requirements and the final pull request. Agents never merge.
- The repository is **public**: never write secrets, tokens, real hostnames, account IDs or real personal data into code, docs, commits or pull requests. Use placeholders and fake data; configuration through variable names in `.env.example`.
- Documents are in English, edited in place with version labels `[vX.Y | YYYY-MM-DD]` on changed lines.
- Each subagent works in its own git worktree (`.claude/worktrees/<slug>/<n>-<agent>`, branch `stage/<slug>/<n>-<agent>`, created from `feature/<slug>`) and writes only its allowed paths; only the orchestrator runs git and merges. See `docs/process/README.md` "Worktrees".
