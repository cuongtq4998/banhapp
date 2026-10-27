# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

Git monorepo (ADR-0004), three components plus shared contracts:

- `ios/` — SwiftUI app, iPhone only, iOS 17 (`BanhApp/`, `BanhAppTests/`, `BanhAppUITests/`, `BanhApp.xcodeproj`).
- `android/` — Kotlin and Jetpack Compose app, minSdk 26 (Gradle).
- `backend/` — Swift 6 and Vapor 4 API (SwiftPM), PostgreSQL migrations in `backend/db/`.
- `contracts/` — shared JSON fixtures and the `BanhContracts` SwiftPM package.
- `docs/` — product, design, system, decisions, engineering, test, pipeline. Developer commands live in `docs/engineering/dev-guide.md`.

## Swift app

`xcodebuild` needs full Xcode. The active developer dir may be Command Line Tools, so prefix commands with `DEVELOPER_DIR=<path to a full Xcode>` (no sudo). The project file format is 77, which Xcode 26.x and 27 both open; Xcode 27 may offer to upgrade it to format 110 (do not accept or commit that: the hosted CI runner only has Xcode 26.x). Check the installed names with `ls /Applications | grep Xcode`.

```
cd ios
xcodebuild -project BanhApp.xcodeproj -scheme BanhApp -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
xcodebuild -project BanhApp.xcodeproj -scheme BanhApp -destination "platform=iOS Simulator,id=<simulator id>" -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

`-parallel-testing-enabled NO` is needed, otherwise the test run fails with "No matching device ... XCTestDevices". Platforms live in `SUPPORTED_PLATFORMS`, `TARGETED_DEVICE_FAMILY` (1 = iPhone) and `IPHONEOS_DEPLOYMENT_TARGET` (17.0) in `ios/BanhApp.xcodeproj/project.pbxproj`. iOS 17 APIs (`@Observable`) are available without `#available`; guard iOS 18 and later APIs.

## Backend and Android

Commands, prerequisites and troubleshooting: `docs/engineering/dev-guide.md` and `backend/README.md`. The backend builds and tests natively with Swift 6.2 (`cd backend && swift test`); the Docker image and PostgreSQL behaviour are verified in CI. The Android Gradle wrapper is generated with `gradle wrapper --gradle-version 9.6.0` (needs JDK 17 and the Android SDK).

## ddagent (external tool)

Simulator/DerivedData orchestration is not part of this repo. It lives in https://github.com/cuongtq4998/ddagent (private) and is installed globally:

```
npm i -g github:cuongtq4998/ddagent     # also use this to update; make sure $(npm prefix -g)/bin is on PATH
ddagent init                            # in a repo: installs the ddagent-lane / ddagent-debug skills and permissions
ddagent doctor | run | prewarm | status | dashboard | lane acquire|release|list
```

Pass the iOS project path `ios/BanhApp.xcodeproj` to it. Add `--mock` or `DDAGENT_MOCK=1` to run without Xcode. ddagent drives iOS/iPadOS simulators and, with pull request cuongtq4998/ddagent#3 (Android lanes, existing AVDs: `ddagent doctor --platform android`, `lane acquire --platform android`), Android emulators; the iOS 15.5 and 16.0 runtimes are unusable on this host, so use 17.5+ (e.g. `--target "iPhone 16"`). Real runs need `DEVELOPER_DIR` pointing at a full Xcode. See `.claude/skills/ddagent-lane`; bugs and design live in the ddagent repo.

## Project rule: file size

Every hand-written file has at most **200 lines**: source, tests and documents. Split by responsibility (one type, one test topic, one document subject) before a file passes the limit; do not trim comments or blank lines to fit. Generated or machine-owned files (the Xcode project file, lock files, JSON fixtures, font and image files) are exempt. A file already over the limit is split when it is next edited. Every agent brief (forge-dev, probe-qa, canvas-ui, atlas-architect, scribe-requirements) repeats this rule, and the orchestrator checks line counts before merging a stage.

## Agent pipeline (`/feature`)

Features are built by a pipeline of subagents orchestrated from this session. Read `docs/process/README.md` before working on it; document standards are in `docs/process/standards/`.

- Agents: `scribe-requirements` (PRD), `canvas-ui` (UI spec), `atlas-architect` (system docs, ADRs), `forge-dev` (code), `probe-qa` (tests). Definitions are in `.claude/agents/`; the entry point is `/feature <business description>`.
- The product owner provides business intent only. Agents decide technical matters, research them and record sources. Ask the owner only for money, security or customer data, hard-to-reverse choices, or differing business behavior; ask everything in one batch.
- After each completed step, commit and push `feature/<slug>` (scan the unpushed diff for sensitive data first; the repo is public).
- The owner approves exactly two points: the requirements and the final pull request. Agents never merge.
- The repository is **public**: never write secrets, tokens, real hostnames, account IDs or real personal data into code, docs, commits or pull requests. Use placeholders and fake data; configuration through variable names in `.env.example`.
- Documents are in English, edited in place with version labels `[vX.Y | YYYY-MM-DD]` on changed lines.
- Each subagent works in its own git worktree (`.claude/worktrees/<slug>/<n>-<agent>`, branch `stage/<slug>/<n>-<agent>`, created from `feature/<slug>`) and writes only its allowed paths; only the orchestrator runs git and merges. A `PreToolUse` hook (`.claude/hooks/worktree_guard.py`, declared in each agent file) blocks writes outside the agent's registered worktree and paths; the orchestrator registers each worktree in `.claude/worktrees/.guard/<agent>.roots` before delegating. See `docs/process/README.md` "Worktrees".
