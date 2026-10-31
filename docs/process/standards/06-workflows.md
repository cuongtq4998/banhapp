# Standard 06: Workflows and Lifecycles (`docs/system/<workflow>.md`, e.g. `order-lifecycle.md`)

Owner: `atlas-architect`. Readers: `forge-dev`, `probe-qa`.

Purpose: describe a business process end to end and the states of the thing it moves (for example an order), with the rules for every transition.

Update trigger: a flow, state or transition changes. Edit in place with labels.

## Required sections

| # | Section | Content |
| - | ------- | ------- |
| 1 | Header block | |
| 2 | Purpose & Scope | The process covered |
| 3 | Actors | Who acts: customer, staff, owner, system |
| 4 | Main Flow | Mermaid `sequenceDiagram` plus numbered steps |
| 5 | Alternate & Error Flows | Each failure with its handling |
| 6 | State Machine | Mermaid `stateDiagram-v2` and a transition table: from, to, trigger, actor, guard, side effects |
| 7 | Business Rules Applied | Links to `BR-n` in the PRD and how they are enforced |
| 8 | Concurrency & Idempotency | What happens when two actors act at once or a request repeats |
| 9 | Events & Audit | What is recorded on each transition |
| 10 | Open Questions / Change log | |

## Rules

1. Every state is reachable and every non-final state has an exit. Final states are marked.
2. The server rejects any transition not in the table, even when called directly.
3. Each transition names its side effects (stock released, notification sent).
4. Each step traces to an FR or BR.

## Ready gate (before `forge-dev`)

All transitions have guards and side effects; concurrency behavior is stated.

## Quality checklist

A tester enumerates every valid and invalid transition from the table.
