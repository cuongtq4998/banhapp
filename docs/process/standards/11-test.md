# Standard 11: Test Plan and Report (`docs/test/<feature>-tests.md`)

Owner: `probe-qa`. Readers: product owner, `forge-dev`, `scribe-requirements`.

Purpose: prove the feature meets its requirements and record what was found.

Input: PRD acceptance criteria, UI states, workflow transitions, API errors, the code.

Update trigger: the feature or its requirements change, or a test round runs. Edit in place with labels.

## Required sections

| # | Section | Content |
| - | ------- | ------- |
| 1 | Header block | Includes `Based on` (PRD and design versions tested) |
| 2 | Scope & Environment | What was tested, where, with which build |
| 3 | Traceability Matrix | `AC-n` to `TC-n` (every AC covered) |
| 4 | Test Cases | `TC-n`: type (acceptance / negative / edge / regression / extra), preconditions, steps, expected result, result (Pass / Fail / Blocked) |
| 5 | Additional Cases | Cases the tester added beyond the ACs, each marked `extra` with the reason |
| 6 | Rounds | Table per round: date, build, pass count, fail count |
| 7 | Defects | `D-n`: severity, description, steps, expected vs actual, route (`dev` or `requirements`), status |
| 8 | Verdict | Pass or Fail with justification |
| 9 | Open Questions / Change log | |

## Rules

1. Every acceptance criterion has at least one case. The tester also thinks of negative, boundary, concurrency, permission and repeat-request cases.
2. A defect is routed `dev` when the code is wrong and `requirements` when the behavior contradicts or is missing from the approved requirements; `requirements` defects go back to `scribe-requirements` through the orchestrator.
3. Each case is repeatable by someone else. Data is fake.
4. The verdict is Pass only when all Must ACs pass and no open defect has high severity.
5. Maximum three test-and-fix rounds before the orchestrator asks the product owner.
6. Early mode: the plan exists before the code. Mark results `Not run`; record which documents (and versions) the plan is based on, and update the plan when they change.
7. Execute mode: every result and defect names the commit it was observed on. Executable QA tests live in a `qa/` folder per component; developer unit tests stay in the component's own test target.
