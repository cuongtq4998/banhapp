# Standard 08: Deployment and Operations (`docs/system/deployment.md`)

Owner: `atlas-architect` (design), `forge-dev` (keeps it true). Readers: everyone who releases or operates.

Purpose: how the system is built, configured, released, monitored and restored.

Update trigger: environment, pipeline or infrastructure changes. Edit in place with labels.

## Required sections

| # | Section | Content |
| - | ------- | ------- |
| 1 | Header block | |
| 2 | Environments | Table: local, staging, production: purpose, data, who deploys |
| 3 | Configuration | Table of variable **names**, meaning, required, where set. Never values |
| 4 | Build & Release | Pipeline steps, versioning of apps and backend, store submission notes |
| 5 | Infrastructure | Components and hosting choices (link to ADRs) |
| 6 | Backup & Restore | Frequency, retention, tested restore, recovery targets |
| 7 | Observability | Logs, metrics, alerts: what, threshold, who is told |
| 8 | Rollback | Step by step |
| 9 | Cost Notes | Estimates, marked as estimates, with source |
| 10 | Open Questions / Change log | |

## Rules

1. No secrets, real hosts or account identifiers. Placeholders only.
2. Every alert has an owner and an action.
3. A backup counts only if a restore has been tested.
4. Paid services are flagged for owner approval.

## Quality checklist

A new maintainer can release and roll back using only this file.
