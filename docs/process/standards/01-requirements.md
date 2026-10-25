# Standard 01: Feature Requirements (`docs/product/<feature>.md`)

Owner: `scribe-requirements`. Readers: product owner (approves), `canvas-ui`, `atlas-architect`, `probe-qa`.

Purpose: say what to build, for whom, and how to know it is done. It never says how to build it.

Update trigger: the product owner describes a change to the feature. Edit in place, bump the version, label changed lines.

## Required sections

| # | Section | Content |
| - | ------- | ------- |
| 1 | Header block | See `00-common.md` |
| 2 | Summary | 1-3 sentences |
| 3 | Background & Problem | Current problem, who has it |
| 4 | Goals / Non-goals | Measurable goals. Non-goals are things that could be goals but are deliberately excluded (not negated goals) |
| 5 | Users & Scenarios | Affected roles, 1-3 main scenarios |
| 6 | Functional Requirements | `FR-n`, "The system shall ...", priority Must / Should / Could |
| 7 | Business Rules | `BR-n`: rules, formulas, limits |
| 8 | Acceptance Criteria | `AC-n`: Given / When / Then; names the FR it checks |
| 9 | Non-functional | Performance, security, accessibility, language. Only if relevant |
| 10 | Impact & Dependencies | Other features and systems affected |
| 11 | Assumptions | Assumptions used |
| 12 | Open Questions | Format in `00-common.md` |
| 13 | Change log | |

## Rules

1. No solution detail: no tables, endpoints, frameworks, screen layouts.
2. Every `FR` is testable and has at least one `AC`. Every `AC` states input and an observable result.
3. Ask all business questions in one batch. Questions that research can answer (market practice, platform rules) are researched first, not asked.
4. Business questions go to the product owner. Technical matters are not requirements; leave them to `atlas-architect`.
5. Sample data is fake.

## Ready gate (before `canvas-ui` and `atlas-architect` start)

- Status `Approved` by the product owner.
- No blocking open question.
- Every `Must` FR has at least one `AC`.

## Quality checklist

- A newcomer understands the problem and scope in two minutes.
- Each requirement can be judged pass or fail without asking anyone.
- No vague wording. Out-of-scope items are stated.
