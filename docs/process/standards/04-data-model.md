# Standard 04: Data Model (`docs/system/data-model.md`)

Owner: `atlas-architect`. Readers: `forge-dev`, `probe-qa`.

Purpose: the single description of what is stored, how entities relate and which rules the data enforces.

Update trigger: any change to stored data. Edit in place with labels.

## Required sections

| # | Section | Content |
| - | ------- | ------- |
| 1 | Header block | |
| 2 | Overview | Storage technology (link to ADR), conventions |
| 3 | Entity Relationship Diagram | Mermaid `erDiagram` |
| 4 | Entities | One subsection per entity: purpose, then a column table (name, type, nullable, default, constraints, notes) |
| 5 | Enumerations | Every fixed value set and its meanings |
| 6 | Indexes & Constraints | Uniqueness, foreign keys, check rules, indexes with the reason for each |
| 7 | Data Rules | Money, time, identifiers, deletion and retention |
| 8 | Sensitive Data | Table: field, classification (personal / operational), who may read it, retention |
| 9 | Migrations | Policy: versioned, ordered, reversible where possible |
| 10 | Open Questions / Change log | |

## Rules

1. Names are consistent (one naming style). Every column has a stated meaning.
2. Money is stored as an integer in the smallest currency unit. Timestamps are stored in UTC.
3. Prices and fees that affect a past order are snapshotted on that order.
4. Rules that must never be violated are enforced by the database (constraints), not only by application code.
5. Personal data is listed in Sensitive Data with retention. Examples contain fake data.
6. Link each entity to the FR or BR it supports.

## Ready gate (before `forge-dev`)

All entities and constraints the feature needs are defined; migration impact is stated; sensitive fields are classified.

## Quality checklist

A developer writes the schema from this file alone; a tester derives data-level cases from constraints.
