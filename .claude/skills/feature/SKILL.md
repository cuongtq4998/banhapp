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

## 1. Run a stage

For each stage, delegate to the named subagent using the Agent tool (subagent types: `scribe-requirements`, `canvas-ui`, `atlas-architect`, `forge-dev`, `probe-qa`). Subagents start with empty context: your prompt must name the slug, the input files to read and the output files to write. Before delegating, check the Ready gate of the previous document. Afterwards, verify the output files exist and follow the header block. Update `run.md` and commit with a message starting with the agent name (`git add` only the files that stage produced).

If custom agent types are not available in this session, run the stage with a general-purpose agent and tell it to adopt the instructions in `.claude/agents/<name>.md`.

## 2. Questions and queries

Agents return reports containing questions and queries. Never ask the owner piecemeal.

- **Technical question for another agent:** route it to that agent and pass the answer back; or let the asking agent research. No owner involvement.
- **Escalate to the owner only** if the matter (1) costs money, (2) affects security or customer data, (3) is hard to reverse, or (4) changes visible business behavior depending on the option, or if it is a business question. Gather everything from the stage into a single `AskUserQuestion` batch with a recommended option and the reasoning. Record the answers in the document through the owning agent.

## 3. Stages and gates

1. `scribe-requirements` writes `docs/product/<slug>.md`. Resolve questions, then **GATE: the owner approves the requirements** (summarize FRs, ACs and assumptions; ask to approve). Set Status `Approved` through the agent.
2. `canvas-ui` writes the UI specification.
3. `atlas-architect` writes system documents and ADRs. Proposed ADRs that meet an escalation condition go to the owner in one batch.
4. `forge-dev` implements and tests.
5. `probe-qa` verifies. Defect routing:
   - `dev` defects: back to `forge-dev`, then `probe-qa` again. **Maximum 3 rounds**; if still failing, ask the owner.
   - `requirements` defects: ask `scribe-requirements` to clarify; business questions go to the owner. Changed requirements go through the stages again from the affected one.

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
