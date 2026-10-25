# ADR-0004: Repository layout

| Field    | Value |
| -------- | ----- |
| ADR      | 0004 |
| Version  | 1.1 |
| Status   | Accepted (owner approved `docs/`, `backend/`, `ios/`, `android/`; `contracts/` added for shared fixtures and the Swift contracts package) [v1.1 | 2026-10-25] |
| Date     | 2026-10-25 |
| Decider  | Product owner (recommendation by atlas-architect) |
| Based on | CLAUDE.md (current layout); ADR-0001, ADR-0006 |

## Context

The repository has an Xcode project at the root (`BanhApp/`, `BanhAppTests/`, `BanhAppUITests/`, `BanhApp.xcodeproj`) and `tools/ddagent/`. The slice adds an Android app and a backend. The agent pipeline uses worktrees and path-scoped rules (`.claude/rules/swift.md` matches `BanhApp/**`). The repository is public and has few commits, so moving files now is cheap.

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

Monorepo with `ios/`, `android/`, `backend/`, `contracts/` (sample request and response fixtures used by all three test suites), `docs/`, `tools/`. Documents already use these paths. A git move preserves history. `contracts/` holds `fixtures/` (JSON) and `swift/` (the `BanhContracts` SwiftPM package, ADR-0001) [v1.1 | 2026-10-25]. Update of CLAUDE.md and rules is a task for the orchestrator after the owner decides (atlas cannot edit them).

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
