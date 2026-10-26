# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

Git repo. One app:

- `BanhApp/`, `BanhAppTests/`, `BanhAppUITests/`, `BanhApp.xcodeproj` — a multiplatform SwiftUI app (iOS, iPadOS, macOS, tvOS, visionOS; deployment targets iOS 15.0 / tvOS 15.0 / macOS 12.0 / visionOS 1.0, Swift 5.0). Currently the Xcode template stub (`BanhApp.swift` → `ContentView`), with XCTest unit/UI test targets.

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

## ddagent (external tool)

Simulator/DerivedData orchestration is not part of this repo. It lives in https://github.com/cuongtq4998/ddagent (private) and is installed globally:

```
npm i -g github:cuongtq4998/ddagent     # also use this to update; make sure $(npm prefix -g)/bin is on PATH
ddagent init                            # in a repo: installs the ddagent-lane / ddagent-debug skills and permissions
ddagent doctor | run | prewarm | status | dashboard | lane acquire|release|list
```

Add `--mock` or `DDAGENT_MOCK=1` to run without Xcode. ddagent only drives iOS/iPadOS simulators; the iOS 15.5 and 16.0 runtimes are unusable on this host, so use 17.5+ (e.g. `--target "iPhone 16"`). Real runs need `DEVELOPER_DIR` pointing at a full Xcode. See `.claude/skills/ddagent-lane`; bugs and design live in the ddagent repo.

## Agent pipeline (`/feature`)

Features are built by a pipeline of subagents orchestrated from this session. Read `docs/process/README.md` before working on it; document standards are in `docs/process/standards/`.

- Agents: `scribe-requirements` (PRD), `canvas-ui` (UI spec), `atlas-architect` (system docs, ADRs), `forge-dev` (code), `probe-qa` (tests). Definitions are in `.claude/agents/`; the entry point is `/feature <business description>`.
- The product owner provides business intent only. Agents decide technical matters, research them and record sources. Ask the owner only for money, security or customer data, hard-to-reverse choices, or differing business behavior; ask everything in one batch.
- After each completed step, commit and push `feature/<slug>` (scan the unpushed diff for sensitive data first; the repo is public).
- The owner approves exactly two points: the requirements and the final pull request. Agents never merge.
- The repository is **public**: never write secrets, tokens, real hostnames, account IDs or real personal data into code, docs, commits or pull requests. Use placeholders and fake data; configuration through variable names in `.env.example`.
- Documents are in English, edited in place with version labels `[vX.Y | YYYY-MM-DD]` on changed lines.
- Each subagent works in its own git worktree (`.claude/worktrees/<slug>/<n>-<agent>`, branch `stage/<slug>/<n>-<agent>`, created from `feature/<slug>`) and writes only its allowed paths; only the orchestrator runs git and merges. A `PreToolUse` hook (`.claude/hooks/worktree_guard.py`, declared in each agent file) blocks writes outside the agent's registered worktree and paths; the orchestrator registers each worktree in `.claude/worktrees/.guard/<agent>.roots` before delegating. See `docs/process/README.md` "Worktrees".
