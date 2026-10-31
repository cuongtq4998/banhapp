# Standard 03: System Architecture (`docs/system/architecture.md`)

Owner: `atlas-architect`. Readers: `forge-dev`, `probe-qa`, product owner.

Purpose: a map of the whole system: components, responsibilities, how they talk, external dependencies. A newcomer can redraw the system after ten minutes.

Update trigger: a new component, external integration or main flow. Edit in place with labels.

## Required sections

| # | Section | Content |
| - | ------- | ------- |
| 1 | Header block | |
| 2 | Purpose & Scope | What this covers and what it does not |
| 3 | System Context | Who and what interacts with the system (Mermaid `flowchart`) |
| 4 | Components | Table: name, one-sentence responsibility, technology, **repo path**, talks to |
| 5 | Key Flows | 2-4 central flows (Mermaid `sequenceDiagram`); detailed flows live in workflow documents |
| 6 | Data & Storage Overview | Where data lives; link to `data-model.md` |
| 7 | External Integrations | Table: service, purpose, auth mechanism (name only), **failure behavior** |
| 8 | Cross-cutting Concerns | Security, observability, error handling, configuration, localization |
| 9 | Quality Attributes | Measurable targets (latency, availability, expected load) |
| 10 | Constraints & Assumptions | |
| 11 | Decision Index | Links to ADRs |
| 12 | Risks & Open Questions / Change log | |

## Rules

1. One level of abstraction: components only. Tables, endpoints and state machines live in their own documents; link, do not copy.
2. Each component has one main responsibility and one repo path.
3. Every external integration states what happens when it fails.
4. Reasons for technology choices live in ADRs; here only the result and a link.
5. No sensitive values (hostnames, IPs, account IDs). Use placeholders.
6. Every arrow in a diagram appears in the Components or Integrations table, and the reverse.

## Ready gate (before `forge-dev`)

- Every component the feature touches has a row with a repo path.
- Every integration the feature needs states failure behavior.
- Quality targets relevant to the feature are stated or marked not applicable.
- Every new technology choice has an `Accepted` ADR.

## Quality checklist

- Someone outside the project can redraw the system.
- You know which folder to open to change a component.
- No target is qualitative only ("fast").
