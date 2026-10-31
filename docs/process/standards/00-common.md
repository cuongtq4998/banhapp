# Common Documentation Standard

Applies to every file under `docs/`. Each document standard (`01-` to `12-`) adds to this one.

## Language and style

- Write in English. User-facing app text (Vietnamese) appears only inside "Content & Copy" tables.
- Short sentences, active voice. Requirements use "shall". No vague words ("fast", "friendly") without a number or condition.
- Link to another document instead of copying its content.
- Diagrams are Mermaid text, never images, so agents can read and edit them.

## Header block (top of every document)

```md
# <Title>

| Field        | Value                                  |
| ------------ | -------------------------------------- |
| Version      | 1.0                                    |
| Last updated | YYYY-MM-DD                             |
| Status       | Draft / In review / Approved           |
| Owner        | <agent name>                           |
| Based on     | <upstream document and its version>    |
| Related      | <other documents>                      |
```

`Based on` is required when the document derives from another (UI from PRD, architecture from UI and PRD).

## Versioning and change labels

- First version is `1.0`. Each approved change adds `0.1` (`1.1`, `1.2`). A change in scope or meaning bumps the major number.
- Every line or paragraph added or changed after `1.0` ends with a label: `[v1.2 | 2026-11-03]`. Unchanged lines carry no label.
- Removed content is not deleted silently. Record it in the Change log ("Removed in v1.2: ...").
- Every document ends with a Change log table: Version, Date, Change.
- Edit the same file in place. Never create a second copy of a document for a new version.

## Identifiers

IDs are stable and never reused or renumbered: `FR-n`, `BR-n`, `AC-n`, `S-n` (screens), `TC-n`, `Q-n`, `ADR-NNNN`. A removed item keeps its ID and is marked "Removed in vX.Y".

## Open questions (all documents)

| ID | Question | Why it matters | Blocking | Class | Status | Answer |
| -- | -------- | -------------- | -------- | ----- | ------ | ------ |

- `Class` is `business` or `technical`. `Blocking` is Yes or No.
- Ask everything at once. Collect every question in one batch; never ask piecemeal.
- A document cannot be `Approved` while a blocking question is open.

## Research and sources

When a statement depends on outside facts (platform APIs, library behavior, prices, standards), research it and cite it:

| Claim | Source (URL) | Read on | Confidence |
| ----- | ------------ | ------- | ---------- |

Mark anything not verified as "unverified". Do not state unverified facts as settled.

## Sensitive information (the repository is public)

Never write into docs, commits or pull requests: API keys, passwords, tokens, connection strings, real hostnames or IP addresses, account or team IDs, real phone numbers, names or addresses of customers. Use placeholders (`<API_KEY>`, `<DB_URL>`, `<PHONE_NUMBER>`) and obviously fake sample data. Real values live only in environment variables or a secret manager.

## Traceability

Downstream documents trace upstream items: acceptance criteria to FRs, screens to FRs, endpoints and test cases to FRs and ACs. An item without a trace is removed or justified.
