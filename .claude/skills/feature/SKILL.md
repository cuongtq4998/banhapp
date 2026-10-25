---
name: feature
description: Run the multi-agent feature pipeline (requirements, UI, architecture, development, QA) from a plain-language business request and end with a pull request. Invoke manually with /feature.
argument-hint: <business description> | continue <slug>
disable-model-invocation: true
---

You are the orchestrator of the feature pipeline. Read `docs/process/README.md` and `docs/process/standards/00-common.md` first. The product owner provides business intent only; agents decide technical matters.

Argument: `$ARGUMENTS`. Either a plain description of a feature or product (new feature, change, or whole new project), or `continue <slug>` to resume from `docs/pipeline/<slug>/run.md`.

## 0. Start

1. Derive a short kebab-case `<slug>`. Make sure the working tree is clean (`git status`); if not, stop and ask the owner what to do. Create branch `feature/<slug>` from the current branch.
2. Write `docs/pipeline/<slug>/00-request.md` with: Type (`new-project` or `change`), Title, Description (the owner's words, verbatim), Who benefits, Constraints, Existing docs. Do not invent facts; leave unknowns empty.
3. Create `docs/pipeline/<slug>/run.md`: current stage, round counter, approvals, pending question batch, log.

## 1. Run a stage (always in its own worktree)

Every stage runs in a separate git worktree and branch; see "Worktrees" in `docs/process/README.md`. For stage `<n>` and agent `<agent>`:

1. Make sure `feature/<slug>` has everything from earlier stages committed (`git status` clean on the feature branch). Never start a stage from uncommitted files.
2. Create the worktree from the feature branch tip:
   `git worktree add -b stage/<slug>/<n>-<agent> .claude/worktrees/<slug>/<n>-<agent> feature/<slug>`
2b. **Register the worktree for the guard hook** (without this the agent cannot write): `mkdir -p .claude/worktrees/.guard && echo "<absolute worktree path>" >> .claude/worktrees/.guard/<agent>.roots`.
3. Delegate to the subagent with the Agent tool (types: `scribe-requirements`, `canvas-ui`, `atlas-architect`, `forge-dev`, `probe-qa`). Do **not** use the Agent tool's built-in `isolation` option: it starts from the default branch and would not contain earlier documents. Subagents start with empty context, so the prompt names: the slug, the **absolute worktree path** (all work must stay inside it), the input files to read, the output files to write, and the Ready gate you checked.
4. Verify in the worktree: output files exist and follow the header block; `git -C <worktree> status --short` lists only files inside the agent's allowed paths (see README "Write ownership"); the main checkout is unchanged. Reject the stage (keep the worktree for inspection) otherwise.
5. Commit in the worktree with `git -C <worktree> add` (only the stage's files) and a message starting with the agent name. Agents never run git.
6. Merge into the feature branch from the main checkout: `git merge --no-ff stage/<slug>/<n>-<agent>`. Then `git worktree remove .claude/worktrees/<slug>/<n>-<agent>`, `git branch -d stage/<slug>/<n>-<agent>`, and delete that worktree's line from `.claude/worktrees/.guard/<agent>.roots`. On a merge conflict, stop and report; it means write ownership was violated.
7. Update `docs/pipeline/<slug>/run.md` on the feature branch and commit it.

Stage 4 may fan out into parallel `forge-dev` instances (one worktree per component) as described in the README. Fix rounds create new worktrees from the current tip.

If custom agent types are not available in this session, run the stage with a general-purpose agent and tell it to adopt the instructions in `.claude/agents/<name>.md`.

## 2. Questions and queries

Agents return reports containing questions and queries. Never ask the owner piecemeal.

- **Technical question for another agent:** route it to that agent and pass the answer back; or let the asking agent research. No owner involvement.
- **Escalate to the owner only** if the matter (1) costs money, (2) affects security or customer data, (3) is hard to reverse, or (4) changes visible business behavior depending on the option, or if it is a business question. Gather everything from the stage into a single `AskUserQuestion` batch with a recommended option and the reasoning. Record the answers in the document through the owning agent.

## 3. Phases and gates

**Phase A: requirements.** `scribe-requirements` writes `docs/product/<slug>.md`. Resolve questions, then **GATE: the owner approves the requirements** (summarize FRs, ACs and assumptions; ask to approve). Set Status `Approved` through the agent.

**Phase B: concurrent start** (right after the gate; separate worktree per agent, all registered with the guard):
- `canvas-ui`: UI specification.
- `atlas-architect`: system documents and ADRs. Proposed ADRs meeting an escalation condition go to the owner in one batch.
- `probe-qa` (early mode): test plan from the PRD and drafts, plus a review of all documents for contradictions and untestable items.
- `forge-dev` (early mode): feasibility review, slice plan, migration steps; no code.
Merge each stage when it finishes and passes the scope check. Merge order does not matter (write ownership is disjoint).

**Phase C: question routing and sync.** Collect the questions and queries from every report. Route each to the owning agent (see README "Question routing"), run that agent in a new worktree to update its document in place, merge it, then resync every still-running or later consumer: `git -C <consumer worktree> merge feature/<slug>` and tell it which labelled lines changed. A question that bounced more than twice, or that meets an escalation condition, goes to the owner in one batch. Repeat until no blocking question remains.

**Phase D: implementation and verification.** Start only when the Ready gates hold (PRD Approved; UI without blocking questions; data model, API and workflows complete; ADRs for the technology involved Accepted). `forge-dev` implements slice by slice (parallel instances per component allowed); `probe-qa` converts its plan to executable tests and runs them on a fixed commit. Defect routing:
- `dev` defects: back to `forge-dev`, then `probe-qa` retests on the new commit. **Maximum 3 rounds**; if still failing, ask the owner.
- `requirements` defects: ask `scribe-requirements` to clarify; business questions go to the owner. Changed requirements flow through Phase C again.
- Document gaps found by either agent: Phase C.

Between the two gates (requirements approval and final PR) proceed without asking the owner unless an escalation condition applies.

## 4. Finish

1. Run the secret check: search the diff for keys, tokens, passwords, connection strings, real hostnames and personal data; fix any hit.
2. Verify the build and tests report real results (run the commands in `CLAUDE.md`).
3. Push the branch and open a pull request with `gh pr create`: summary of the feature, links to the PRD and test report, test results, assumptions and open risks. Public repository: no sensitive data in the title or body.
4. Stop. Never merge. Tell the owner the PR link and what needs their attention.

## Rules

- Everything the agents need is in files, not in your memory.
- Report real results; never claim a check passed without running it.
- One commit per completed stage. Do not force push or rewrite history.
- At the start of `continue`, run `git worktree list` and `git worktree prune`; resume or remove leftover stage worktrees deliberately.
