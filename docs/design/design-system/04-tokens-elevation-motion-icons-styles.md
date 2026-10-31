# Design System, part 4: Elevation, motion, iconography, component styles (sections 2.5 to 2.8)

[v1.3 | 2026-10-27] Part of the split design system; index: [design-system.md](../design-system.md). Content unchanged from v1.2; section numbers are the original ones. Code comments cite this part as "design-system.md sections 2.5 and 2.6" (Duration constants: 2.6).

### 2.5 Elevation and material

| Token | Purpose | iOS value | Android value |
| ----- | ------- | --------- | ------------- |
| `elevation.card` | Glass cards, bars, back button | Liquid Glass regular. Board glass: fill `color.surface.glass`, backdrop blur 24 with saturation 180%, stroke `color.surface.stroke`, shadow 0 / 8 / blur 32 rgba(30,70,45,0.12), inner highlight [v1.2 | 2026-10-26] | Translucent tonal fill. Board glass: fill `color.surface.glass`, backdrop blur 28 with saturation 170%, stroke, shadow 0 / 8 / blur 28 rgba(20,60,35,0.10), inner highlight; real blur on API 31+ only, see fallbacks [v1.2 | 2026-10-26] |
| `elevation.primaryButton` [v1.2 | 2026-10-26] | Shadow under a filled primary button | Hero card: 0 / 10 / blur 24 rgba(47,107,63,0.35); bar button: 0 / 6 / blur 16 same colour; both with inner top highlight White at 45% | Hero card: 0 / 14 / blur 32 rgba(29,107,58,0.35) with inner highlight White at 30%; bar button: inner highlight White at 30%, no outer shadow |
| `elevation.bar` | Floating bottom action bar | Liquid Glass regular, floats 28 pt above the bottom edge [v1.2 | 2026-10-26] | Floating toolbar or `fx` glass bar, floats 20 dp above the bottom edge [v1.2 | 2026-10-26] |
| `elevation.logo` [v1.2 | 2026-10-26] | Android logo blob | not used (glass logo) | 0 / 12 / blur 40 rgba(20,60,35,0.15) (launch), 0 / 12 / blur 32 (success mark), inner highlight White at 80% |
| `elevation.sheet` | Sheets, pickers | System sheet material | Modal bottom sheet, tonal level 1 |
| `material.fallback` | Glass fallback [v1.1 | 2026-10-25] (iOS 17 to 25; Android 8.0 to 11 and any version with reduced transparency) | `Material` (ultra thin) over `color.surface.solid`, hairline `color.surface.stroke` | `color.surface.solid` at 94% without blur (opaque card) |

### 2.6 Motion

| Token | Purpose | iOS value | Android value |
| ----- | ------- | --------- | ------------- |
| `motion.duration.short` | Taps, toggles | 150 ms | 150 ms |
| `motion.duration.medium` | Appear, error message | 250 ms | 250 ms |
| `motion.duration.long` | Screen transitions, launch exit | 400 ms | 400 ms |
| `motion.spring.standard` | Default movement | Spring, response 0.4, damping 0.85 | Expressive spatial spring, medium stiffness, damping ratio about 0.8 (unverified) |
| `motion.spring.bouncy` | Confirmation emphasis | Spring, response 0.5, damping 0.65 | Expressive spatial spring, low stiffness, damping ratio about 0.6 (unverified) |
| `motion.reduced` | When Reduce Motion or "remove animations" is on | Cross-fade 150 ms, no blobs drift | Cross-fade 150 ms, no blobs drift |

The board is static (no animation values); motion tokens are unchanged.

### 2.7 Iconography [v1.2 | 2026-10-26]

The board draws every icon as an inline line icon on a 24 x 24 grid: stroke only, no fill, round caps and joins, stroke width 2.0 to 2.4. The set is small. Map each to the native symbol set with the same meaning and weight (SF Symbols medium weight; Material Symbols Rounded, weight 400 to 500, optical size 24); do not draw bitmap icons.

| Icon | Used for | Board size iOS / Android | Board stroke | SF Symbol (indicative) | Material Symbol (indicative) |
| ---- | -------- | ------------------------ | ------------ | ---------------------- | ---------------------------- |
| Chevron right | Home action cards, list row end, settings row | 26 pt (home), 20 pt (list), 18 pt (settings) / 26 dp, 20 dp | 2.2 (iOS), 2.4 (Android) | `chevron.right` | `chevron_right` |
| Chevron left | Back button (iOS) | 20 pt | 2.2 | `chevron.left` | n/a |
| Arrow left | Back button (Android) | 24 dp | 2.2 | n/a | `arrow_back` |
| Chat bubble | Zalo button (generic icon, ADR-0015) | 18 pt / 20 dp | 2 | `message` | `chat_bubble` |
| Phone | Phone button | 18 pt / 20 dp (16 pt in the admin "call customer" button) | 2 to 2.2 | `phone` | `call` |
| Check | Success mark | 46 pt in a 96 pt glass circle / 58 dp in a 120 dp blob | 2.2 / 2.4 | `checkmark` | `check` |
| Minus and plus | Stepper | text glyphs "−" and "+", 20 pt / 22 dp | n/a | `minus`, `plus` | `remove`, `add` |
| List and gear | Admin tab bar (later slices) | 22 pt | 2 | `list.bullet`, `gearshape` | `list`, `settings` |

Icon colour follows the text colour of its container (`color.text.primary`, `color.onPrimary` on primary, `color.text.secondary` for list chevrons). Logo mark: the board draws one mark for the launch screen, home and admin sign-in: a rounded log (rectangle 48 x 20, corner radius 10) rotated -20 degrees with three slanted tie lines, stroke 3 on a 64 x 64 grid, in `color.primary`. Treat it as the placeholder artwork until the owner confirms (BQ-1 in `place-order-ui.md`).

### 2.8 Component styles taken from the board [v1.2 | 2026-10-26]

| Style | iOS | Android |
| ----- | --- | ------- |
| Glass card | `color.surface.glass` fill, blur, stroke, highlight, `elevation.card` shadow (section 2.5) | Same pattern with Android values |
| Primary button | 180 degree gradient `color.primary.top` to `color.primary`, white label, `elevation.primaryButton` | Flat `color.primary`, white label, inner highlight |
| Secondary (glass) button | Glass fill, `color.text.primary` label | Glass fill (contact pills) or `color.surface.chip` |
| Disabled button | `color.disabledFill`, `color.text.secondary` label, no shadow | Same |
| Selected chip (day, slot, tab) | Fill `color.primary`, border `color.primary`, white label, shadow 0 / 4 / blur 12 rgba(47,107,63,0.30) with inner highlight White at 40% | Fill `color.primary`, border `color.primary`, white label, no shadow |
| Unselected chip | `color.surface.chip` with border | Same |
| Stepper | Glass capsule with a 2 pt padding; both buttons transparent, `color.text.primary` glyph | Capsule filled rgba(20,32,26,0.06); minus button transparent; plus button filled `color.primary` with a white glyph |
| Step indicator | Glass capsule: three 22 x 5 segments (filled `color.primary`, rest `color.progress.inactive`) and the label "Bước n/3" | Glass capsule 48 dp high beside the back button: segments share the width (8 dp high) and the label "n/3" |
| Text field | 46 pt high capsule, 16 pt horizontal padding, fill `color.surface.chip` with border, label above in `type.caption` | 48 dp high capsule, 18 dp horizontal padding, same fill |
| Info chip (detail) | Neutral `color.surface.chip`, 8 / 14 pt padding | `color.primaryContainer` and `color.tertiaryContainer` fills, 40 dp high |
| Success mark | 96 pt glass circle with check | 120 dp blob (`color.primaryContainer`) with check |
| Tab bar (admin, later slices) | Floating glass pill 40 pt from the sides, two tabs 56 pt high, selected tab filled with the primary gradient | Not extracted |
