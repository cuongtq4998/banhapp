# Standard 09: Architecture Decision Record (`docs/decisions/adr-NNNN-<slug>.md`)

Owner: `atlas-architect` (any agent may propose). One file per decision.

Purpose: record one significant technical decision with its reasons, so nobody has to guess later.

## When to write one

A choice that is costly to reverse or that shapes the system: language or framework, database, hosting, authentication method, minimum OS version, build tooling, adopting a paid service.

## Required sections

| # | Section | Content |
| - | ------- | ------- |
| 1 | Header | ADR number, title, Status (Proposed, Accepted, Superseded), date, decider |
| 2 | Context | The situation and forces |
| 3 | Decision Drivers | What matters (cost, risk, effort, user impact) |
| 4 | Options Considered | Table: option, pros, cons |
| 5 | Decision | The choice and why, one paragraph |
| 6 | Consequences | Positive, negative, follow-up work |
| 7 | Sources | Research citations (format in `00-common.md`) |
| 8 | Links | Supersedes / superseded by |

## Rules

1. One decision per ADR. Number sequentially (`adr-0001-...`). Numbers are never reused.
2. Research before deciding. Cite sources; mark unverified claims.
3. An `Accepted` ADR is not rewritten. A change of mind creates a new ADR that supersedes it (small clarifications may be added with a version label).
4. Escalate to the product owner (status stays `Proposed`) when the decision costs money, affects security or customer data, is hard to reverse, or changes visible business behavior.
5. The Decision Index in `architecture.md` links every ADR.
