# ADR-0004: Repository layout

| Field    | Value |
| -------- | ----- |
| ADR      | 0004 |
| Version  | 1.3 |
| Status   | Accepted (owner approved `docs/`, `backend/`, `ios/`, `android/`; `contracts/` added for shared fixtures and the Swift contracts package) [v1.1 | 2026-10-25] |
| Date     | 2026-10-25 |
| Decider  | Product owner (recommendation by atlas-architect) |
| Based on | CLAUDE.md (current layout); ADR-0001, ADR-0006 |

## Context

The repository has an Xcode project at the root (`BanhApp/`, `BanhAppTests/`, `BanhAppUITests/`, `BanhApp.xcodeproj`) and `tools/ddagent/` (when this ADR was written; the folder no longer exists, see the v1.3 note). The slice adds an Android app and a backend. The agent pipeline uses worktrees and path-scoped rules (`.claude/rules/swift.md` matches `BanhApp/**`). The repository is public and has few commits, so moving files now is cheap.

## Decision Drivers

- One place for the contract, fixtures and docs; one pull request per feature across clients and server.
- Clear folder per component (standard 03 rule 2).
- Least disruption to existing tooling and rules.

## Options Considered

| Option | Pros | Cons |
| ------ | ---- | ---- |
| A. Monorepo, apps in sibling folders: move the Xcode project into `ios/`, add `android/`, `backend/`, `contracts/`; keep `docs/`, `tools/` | Symmetric and clear; one PR per feature; shared fixtures | One-time move of the Xcode project; update CLAUDE.md, `.claude/rules/swift.md` paths and ddagent project path |
| B. Monorepo, leave the Xcode project at the root, add `android/`, `backend/` beside it | No move | Root mixes iOS files with other components; the iOS app has no folder of its own |
| C. Separate repositories per component | Independent releases and access | Contract drift; cross-repo PRs; docs split; harder for the agent pipeline |

## Decision (option A, accepted) [v1.1 | 2026-10-25]

Monorepo with `ios/`, `android/`, `backend/`, `contracts/` (sample request and response fixtures used by all three test suites), `docs/`. Documents already use these paths. A git move preserves history. `contracts/` holds `fixtures/` (JSON) and `swift/` (the `BanhContracts` SwiftPM package, ADR-0001) [v1.1 | 2026-10-25]. The `BanhContracts` package declares platforms iOS 17 and macOS 14 (the iOS app minimum, ADR-0005, and the backend's macOS 14 for native Vapor builds; ADR-0001) [v1.2 | 2026-10-26]. CI paths are per component in `.github/workflows/{backend,ios,android}.yml`; the backend workflow also triggers on `contracts/**` [v1.2 | 2026-10-26]. Update of CLAUDE.md and rules is a task for the orchestrator after the owner decides (atlas cannot edit them).

Amendment [v1.3 | 2026-10-27]:

- `tools/` does not exist and is not part of the layout. `ddagent` (simulator and DerivedData orchestration) is an **external** tool kept in its own private repository and installed globally; this repository holds only its skills and permissions under `.claude/` and the instructions in CLAUDE.md. Nothing in the monorepo depends on it for a build.
- iOS project file format: `objectVersion 77` stays. The hosted CI runner has Xcode 26.x only, so a project upgraded to a newer format by a newer Xcode must not be committed (CLAUDE.md). The scheme name `BanhApp` is fixed (CI and tooling refer to it).
- CI is **path-filtered per component**: `backend.yml` runs on `backend/**`, `contracts/**` and its own file; `ios.yml` on `ios/**` and its own file; `android.yml` on its component. A change that touches only documents runs none of them. A contract change (`contracts/**`) triggers the backend workflow only, so an iOS or Android break caused by a fixture change is found on the next client change, not in the same run (accepted; the client workflows should add `contracts/**` to their paths when the client fixture tests are the contract guard: follow-up for forge-dev).
- Module layout inside each component: ADR-0018.

## Consequences

- Positive: each component has exactly one path; fixtures keep clients and server in step.
- Negative: path updates in CLAUDE.md, `.claude/rules/swift.md` (`ios/BanhApp/**`, `ios/BanhAppTests/**`, `ios/BanhAppUITests/**`), and the `ddagent` project path argument.
- If option B is chosen: replace `ios/` by the repo root in every repo path in architecture.md.

## Sources

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |
| Current layout and rules paths | CLAUDE.md, `.claude/rules/swift.md` in this repository | 2026-10-25 | High |
| Monorepo versus multi-repo trade-offs | Architect experience; not researched | 2026-10-25 | Unverified |

## Links

Related: ADR-0001, ADR-0006.

## Change log

| Version | Date | Change |
| ------- | ---- | ------ |
| 1.0 | 2026-10-25 | Proposed. |
| 1.1 | 2026-10-25 | Accepted by the owner. |
| 1.2 | 2026-10-26 | Contracts platforms and CI workflow paths recorded after slice 0 (clarification). |
| 1.3 | 2026-10-27 | `tools/` removed from the layout; ddagent recorded as external; project format 77 and scheme name; per-component path-filtered CI (clarification). |
