# Standard 10: Developer Guide (`docs/engineering/dev-guide.md`)

Owner: `forge-dev`. Readers: any developer or agent entering the codebase.

Purpose: how to set up, run, test and change the code.

Update trigger: setup, structure, commands or conventions change. Edit in place with labels.

## Required sections

| # | Section | Content |
| - | ------- | ------- |
| 1 | Header block | |
| 2 | Prerequisites | Tools and versions |
| 3 | Repository Layout | Folder to responsibility table (matches `architecture.md` repo paths) |
| 4 | Setup & Run | Exact commands per component (backend, iOS, Android) |
| 5 | Coding Conventions | Naming, structure, error handling; link to `.claude/rules/` |
| 6 | Testing | How to run unit, integration and UI tests; where tests live |
| 7 | Branching & Commits | Branch names (`feature/<slug>`), commit message style, pull request content |
| 8 | Troubleshooting | Known problems and fixes |
| 9 | Change log | |

## Rules

1. Every command is copy-paste runnable and was run by the author. No secrets; use `.env.example` names.
2. Layout and paths match `architecture.md`. If code moves, both files change in the same commit.
3. Documentation changes ship in the same pull request as the code that causes them.
