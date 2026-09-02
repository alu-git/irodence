# IRODENCE_PALETTE.md

Color palette and visual hierarchy for 铁证 / Irodence.
Applies to every screen. Where this file and older docs disagree, this file wins.

Metaphor: a forge. Dark charcoal surfaces, one warm accent, hairline metal borders,
stamped industrial numerals. Not a fitness app palette. No blue, no teal, no
gradients, no glow, no shadows.

---

## 1. Palette

### Surfaces

| Token | Hex | Use |
|---|---|---|
| `surface.base` | `#0F1012` | App background, unfilled rows (Cast iron) |
| `surface.raised` | `#181A1D` | Cards, sheets, the one row that should stand out (Forged plate) |
| `surface.sunken` | `#0B0C0E` | Video wells, empty containers |
| `surface.pressed` | `#22262B` | Pressed state on raised surfaces |

Three levels only. If a screen needs a fourth, the layout is too nested.

### Borders

| Token | Hex | Use |
|---|---|---|
| `border.hairline` | `#1F2227` | Dividers inside a card |
| `border.metal` | `#2C3037` | Card edges, outlined controls, inactive chips |
| `border.certified` | `#EF9F27` | Certified proofs only, at 2pt |

All borders 1pt except the certified 2pt. Never thicker.

### Text

| Token | Hex | Use |
|---|---|---|
| `text.primary` | `#F1F3F5` | Titles, stat numerals (Brushed steel) |
| `text.secondary` | `#9CA3AF` | Body, secondary button labels (Neutral plate) |
| `text.muted` | `#64748B` | Labels, timestamps, metadata, disabled (Slag slate) |
| `text.onEmber` | `#1A0D00` | Text on ember fills. High-contrast deep black-amber |

### Accent and state

| Token | Hex | Use |
|---|---|---|
| `ember` | `#EF9F27` | The accent. Certification, 力量分 gains, one primary action per screen |
| `ember.pressed` | `#BA7517` | Pressed state on ember fills |
| `rust` | `#C25E4C` | Icon glyphs on decay states only. Never text, never fills |
| `danger` | `#E24B4A` | Errors and destructive actions only |
| `verified` | `#639922` | Confirmed lifts, met targets. Rare by design |

Deliberately cooled from a brighter red so it separates from ember by both hue and
lightness. Roughly one in twelve men has red-green colorblindness and this user base
skews male, so warm colors must never be the only thing distinguishing two states.

### Tier ladder

A cold-steel ramp climbing in lightness. Not six different hues.

| Tier | Hex |
|---|---|
| 生铁 | `#3B4048` |
| 熟铁 | `#525964` |
| 铸钢 | `#6E7684` |
| 精钢 | `#949DAA` |
| 重锻 | `#C0C7D2` |
| 百炼 | `#E8EEF5` + ember rim |

Only 百炼 gets the ember rim. 生铁 must read as dark iron, dignified, never as a
failure state. Beginners see it most and it is not a punishment.

---

## 2. Hierarchy rules

These are the rules that decide where color goes. They matter more than the hex values.

### Ember scarcity

Ember is the scarcest resource in the design. Per screen region, exactly one ember
element. Per screen, at most one large filled ember area (usually the primary button).
Everything else that needs ember uses it as an outline, a rim, a small stamp, or a
numeral.

If two things on a screen are ember, one of them is wrong. When ember appears
everywhere, the 已认证 stamp stops signalling anything, and the stamp is the product's
entire moat.

Large amber fills also read as commercial promo banners in Chinese UI convention.
Keep ember small and it reads as forged; make it a big pill and it reads as a sale.

### Weight by meaning, not by decoration

Size and weight follow importance, always. The largest numeral on any screen is the
most important number on that screen. If member session counts are bigger than the
group's weekly heat total, the hierarchy is inverted.

| Rank | Treatment |
|---|---|
| Hero number | 34pt medium, `text.primary`, tabular figures |
| Screen title | 22pt medium, `text.primary` |
| Section title | 17pt medium, `text.primary` |
| Card title | 14pt medium, `text.primary` |
| Body | 13.5pt regular, `text.secondary` |
| Label, metadata | 11.5pt regular, `text.muted` |
| Stamp | 11pt medium, `text.onEmber` on ember |

Two weights only: regular 400 and medium 500. Never bold. The forge feel comes from
contrast in size and color, not from heavy type.

### Elevation carries emphasis, not color

To make one row stand out among peers, raise it to `surface.raised` while its
siblings stay `surface.base` with a border. Do not tint it. Color is reserved for
meaning, elevation for attention.

### State is expressed by texture, not hue

The lapsed 生锈 state is `text.muted` plus 0.6 opacity on the row plus a small
rust-tinted icon. It is not red text. This is both colorblind-safe and truer to the
metaphor: rust dulls metal, it does not make it glow.

Same principle throughout. Any state a user must distinguish should be legible with
color removed entirely.

### Certification is the only stamp

The 已认证 treatment (ember fill, `text.onEmber`, 4pt radius, 11pt medium) is used for
one thing and never borrowed for badges, tags, counts, or promotional labels. It is
the single most valuable visual asset in the app and it dilutes on contact with
anything else.

### Iconography

Tools and materials, never hearts or flames-as-emoji. Witnessing is a hammer.
Challenges are crossed swords. Crews are a furnace. Every icon is an SF Symbol tinted
with a token. No emoji anywhere in the UI, including tab bars.

---

## 3. Instructions for the agent

Read this file before touching any view.

1. Audit first, edit second. Produce a report of every hardcoded color, font size,
   radius, and spacing value in the codebase, grouped by file, mapped to the token
   that should replace it. Flag anything that has no clean token mapping. Wait for
   approval before editing.
2. Then migrate to tokens file by file, one commit per view. No layout changes in
   the same commit as a token migration.
3. Then, separately, report every screen that violates a hierarchy rule in section 2,
   with the specific rule cited. Propose fixes. Do not apply them without approval.
4. Never inline a value. If a needed token does not exist, stop and propose it.
5. Tokens belong in an asset catalog with light-mode pairs stubbed, since a light
   "polished steel" theme ships later.
6. You cannot build or visually verify this app. Never claim a screen looks correct.
   End every task with a list of what must be checked in Xcode.
