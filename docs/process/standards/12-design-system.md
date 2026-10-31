# Standard 12: Design System (`docs/design/design-system.md`)

Owner: `canvas-ui`. Readers: `forge-dev`, `canvas-ui`.

Purpose: the shared visual vocabulary. Feature UI documents use names; this file holds the values.

Update trigger: tokens or shared components change. Edit in place with labels.

## Required sections

| # | Section | Content |
| - | ------- | ------- |
| 1 | Header block | |
| 2 | Principles | Native feel first; iOS follows Liquid Glass, Android follows Material 3 Expressive; sources cited |
| 3 | Tokens | Table: token name, purpose, iOS value, Android value (colors, type, spacing, radius, elevation, motion) |
| 4 | Components | Shared components: purpose, variants, states, platform mapping |
| 5 | Motion & Haptics | Standard transitions and feedback |
| 6 | Accessibility | Defaults from `02-ui.md` and component specifics |
| 7 | Open Questions / Change log | |

## Rules

1. Tokens carry semantic names (`color.primary`), never appearance names (`green`).
2. Feature documents use token names only.
3. A new component appears here before it appears in a feature document.
4. Respect the minimum OS versions fixed by ADRs; document fallbacks for older systems.
