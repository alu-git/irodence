# IRODENCE_DESIGN.md

Design system and agent working spec for 铁证 / Irodence.
Commit this at repo root. Reference it by path in every agent prompt.

---

## 0. Rules for the agent

Read before doing anything.

1. Do not refactor files outside the ones named in the prompt.
2. Produce a plan and wait for approval before editing. No end-to-end runs.
3. Never hardcode a color, font size, spacing value, or corner radius in a view. Everything comes from `Theme`. If a token is missing, propose adding it rather than inlining a value.
4. You cannot build or visually verify this app. Do not claim a screen "works" or "looks correct." State what you changed and what needs checking in Xcode.
5. All user-facing copy is Simplified Chinese. Do not write English strings into views.
6. Existing user data must survive every schema change. Migrations only, never destructive rewrites.

---

## 1. Product identity

Irodence is a barbell strength tracker for the Chinese market. The core loop is not logging. It is **proof**: turning a lift into verifiable, ranked, social evidence of strength.

Positioning against the field: 训记 and DayOne are logging utilities. 练就 and 练练健身 are content-and-plans apps. Keep is mass-market gamification. Irodence is the only one where your strength is an identity with social standing attached.

Three concepts drive every design decision:

**力量分** — a DOTS-derived score, bodyweight and sex adjusted. The single number behind all ranking.

**Tiers (段)** — 力量分 mapped onto forged-metal tiers. The tier is a material, not a badge. It shows up in surface treatment and stamping, never as a cartoon medal.

**Certification (认证)** — lifts are either self-logged or video-witnessed by the community. Certified lifts get a visible stamp and are the only ones eligible for ranked leaderboards. This is the moat. The app is named 铁证 (ironclad proof) and nothing else in the market owns this.

Anti-goals: do not build a Hevy clone (white, rounded, blue, friendly). Do not add course content or video libraries. Do not build an infinite feed of routine workout logs.

---

## 2. Visual language

Forge, not fitness app. Dark charcoal surfaces, one ember accent, hairline metal borders, industrial stamped numerals.

### Color tokens

| Token | Hex | Use |
|---|---|---|
| `surface.base` | `#0F1012` | App background (Cast iron) |
| `surface.raised` | `#181A1D` | Cards, sheets (Forged plate) |
| `surface.sunken` | `#0B0C0E` | Video wells, empty states |
| `border.hairline` | `#1F2227` | Dividers (Gunmetal hairline) |
| `border.metal` | `#2C3037` | Card edges, inactive controls (Machined steel rim) |
| `text.primary` | `#F1F3F5` | Headings, numerals (Brushed steel) |
| `text.secondary` | `#9CA3AF` | Body (Neutral plate) |
| `text.muted` | `#64748B` | Labels, timestamps (Slag slate) |
| `ember` | `#EF9F27` | THE accent. Certification stamps, 力量分 deltas, primary actions |
| `ember.deep` | `#1A0D00` | Text on ember fills (High-contrast deep black-amber) |
| `rust` | `#C25E4C` | Decay and lapse states only. Never for errors |
| `danger` | `#E24B4A` | Destructive actions, real errors |

Ember is scarce by design. One ember element per screen region. If two things are ember, one of them is wrong.

A light "polished steel" theme ships later. Build tokens so it is a swap, not a rewrite.

### Type

System font (PingFang SC on device). Two weights only: regular 400, medium 500. Never bold.

| Role | Size | Weight |
|---|---|---|
| Stat numeral | 34 | 500 |
| Screen title | 17 | 500 |
| Card title | 14 | 500 |
| Body | 13.5 | 400 |
| Label | 11.5 | 400 |

Stat numerals are the visual centerpiece. Tabular figures, generous tracking, treated like markings stamped into plate.

### Shape and space

Corner radius 12 on cards, 8 on controls, 4 on stamps and pills. Borders are 1px hairline, never thicker except the 2px ember border on a certified item. No shadows, no gradients, no glow. Spacing scale: 4, 8, 12, 14, 16, 24.

### Iconography

Tools and materials, not hearts and flames. Witnessing uses a hammer, never a like. Challenges use crossed swords. Crews use a furnace. The interaction vocabulary reinforces forging at every tap.

### Tier ladder

生铁 → 熟铁 → 重锻 → 精钢 → 百炼 → 极意

*(玄铁, 铸钢, and 陨铁 are superseded by this sequence.)*

Each tier owns a surface treatment: rougher and darker at the bottom, more refined and reflective at the top. 生铁 must look deliberate and dignified, not like a failure state. Beginners see this tier most.

#### Tier promotion modal copy (段位晋升弹窗)
1. **生铁（新手入门）**
   - 主标题：初具雏形！
   - 副标题：你已褪去废铁之名，正式踏入熔炉。记住，真正的锻造，现在才开始！
   - 按钮：继续添柴
2. **熟铁（进阶打卡）**
   - 主标题：烈火淬炼！
   - 副标题：汗水洗去了杂质，你的底盘已经稳固。保持这个炉温，别让自己冷下来！
   - 按钮：稳住火候
3. **重锻（突破瓶颈）**
   - 主标题：百折不挠！
   - 副标题：经历了无数次力竭与重组，你扛住了重锤！现在的你，比生铁坚韧百倍！
   - 按钮：迎接重锤
4. **精钢（高手分水岭）**
   - 主标题：百炼成钢！
   - 副标题：杂质尽除，锋芒初露！你已经是这片铁匠铺里的中流砥柱，无数新铁正仰望你！
   - 按钮：锋芒出鞘
5. **百炼（顶尖老炮）**
   - 主标题：登峰造极！
   - 副标题：千万次锻打铸就了这副钢铁之躯！你的每一次试举，都是这座熔炉的教科书！
   - 按钮：铸就传奇
6. **极意（天花板级别）**
   - 主标题：人铁合一！
   - 副标题：无需再借外力，你本身就是最硬的铁证！向这座城市的极限，致敬！
   - 按钮：镇炉之宝

### Register rules

Enforce these strictly across all product copy:

- **App Name Only**: **铁证** is the app name only. Never a button label, verb, or state.
- **Forge Voice**: Applies to empty states, loading, primary training actions, achievement notifications, leaderboard, challenges.
- **Plain Functional Language (No Metaphor)**: Strictly enforced for all error messages, reports (举报), review outcomes (复核), account/privacy/payment, and anything involving another user's alleged misconduct. An error must clearly name what failed and what the user can do about it.
- **First-Encounter Clarity**: Every metaphor term used in the UI must be understandable on first encounter or paired with a plain-language subtitle (e.g. 炉温 needs its unit visible; 锤击 needs "次训练" nearby the first time).

---

## 3. Social architecture

### Verification (见证)

Verification turns a PR lift into certified evidence. Self-logged lifts are fully functional and assign a tier. Video proofs can be submitted for verification (**上铁证**). Community members verify lifts through **验杠**.

Certification rules, enforced server-side:
- A lift needs 3 independent witnesses (验杠) to certify.
- A witness must be at or above the lifter's tier.
- A user cannot witness the same lifter more than once per 30 days. This blocks friend rubber-stamping.
- Any witness can flag instead of confirm. Two flags send it to review (复核) and freeze the score change.
- Certification changes ranked standing only. Self-logged 力量分 is never revoked.

### Crews (熔炉)

Small groups, 4 to 20 members (铁匠). Requires 4 members to activate, since a two-person room is a dead room.

- **炉温 (heat)**: a weekly group total that all members contribute training to (添柴).
- **淬火 (quenching)**: hitting the weekly heat target unlocks a group reward. This is what reframes deload and rest as part of the process rather than a broken streak.
- **锤击 (strikes)**: individual session contributions, shown per member (次训练).
- **生锈 (rust)**: visible after 5 days of inactivity (已生锈). Cosmetic decay only. Never demote a tier for inactivity. Crewmates get a one-tap **加炭** nudge.

### Challenges (约战 / 应战)

Head-to-head 力量分 gains over a fixed window, single lift or total. Accept (应战) or decline from the feed.

### Leaderboards (锻造榜)

Default scope is crew and weight class, never global. Global is opt-in and buried. The primary comparison surface everywhere is the user's own past self, not other people.

---

## 4. Onboarding stance

Certification is opt-in and never blocks anything. A user logs a lift, gets a tier, and sees value on day one without filming anything. Roughly nine in ten users will never submit a video, and the product must be complete for them.

Never gate: logging, 力量分, tier, personal history, crew membership.
Only gate behind certification: ranked leaderboard placement on the 锻造榜 and the 已认证 stamp.

---

## 5. Build order

Complete and verify each phase in Xcode before starting the next.

**Phase 1 — Theme layer.** Create `Theme.swift` with every token in section 2 as a namespaced enum. Then migrate existing views to it, one view per commit. No behavior or layout changes in this phase.

**Phase 2 — Schema.** Supabase migrations for `proofs`, `witnesses`, `crews`, `crew_members`, `crew_heat`, `challenges`. RLS policies enforcing every rule in section 3. Server-side certification logic in edge functions, never client-side. This phase is where agent assistance is most reliable, since it is testable outside iOS.

**Phase 3 — Feed screen (见证).** Highest risk UI, build it first. Proof card, witness action (验杠), challenge invite row (约战).

**Phase 4 — Crew screen (熔炉).** Heat meter, member strike rows, rust state, nudge.

**Phase 5 — Profile.** Tier surface treatment, per-lift alloy breakdown, ghost comparison against past self.

**Phase 6 — Moderation.** Report flow, review queue, admin web panel. Do not ship social without this.

---

## 6. Prompt template

```
Read IRODENCE_DESIGN.md.

Task: <one specific thing>
Files you may modify: <explicit list>
Files you may read but not modify: <list>

Produce a plan first. Do not edit until I approve it.
Do not touch any other file. Do not inline any color or size value.
```
