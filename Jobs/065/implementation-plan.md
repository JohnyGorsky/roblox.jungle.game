# Implementation Plan — Job #065

**Project**: `roblox.jungle`
**Created**: 2026-07-30
**Status**: Planning (awaiting go-ahead)

## Analysis

**The problem, measured.** 8 lobby screens, 1,266 lines, built at runtime in code. Between them: **60
distinct `Color3.fromRGB` values** and **75 uses of `Enum.Font.Gotham*`** — a font `STYLEGUIDE.md`
never mentions. No shared theme or component module exists anywhere in `ReplicatedStorage`, so each
screen drifted on its own. `StarterGui` is empty; nothing is editor-authored.

**Approach.** Build the design system **first**, prove it on the two most dissimilar screens, then roll
it out. Every screen is finished in one pass — style, icons and sound together — so nothing is revisited.

Three new modules under `lobby/sync/ReplicatedStorage/UI/`:

| Module | Responsibility |
|---|---|
| `Theme.luau` | **Tokens only, no instances.** Colours, fonts, spacing, radii, stroke, tween presets, icon-ID map, sound-ID map. The one place a hex value is written down. |
| `Components.luau` | **Builders that consume `Theme`.** Panel, title bar, button, chip, row, progress bar, toast, icon. Returns instances; owns no game logic. |
| `UISound.luau` | Thin event→sound layer (`UISound.play("open")`). Absorbs the one-off click handling in `UIClick`. |

**Why tokens are separate from components:** the failure this job exists to fix is 60 hardcoded
colours across 8 files. If components own their colours, we've rebuilt the same problem one layer up.

**Non-negotiable:** this is a **visual layer**. Server contracts, remote signatures, purchase/claim
flows and party logic do not change. Anything behavioural becomes an explicit, called-out decision.

### Design-system source of truth

- **Visuals** — Jungle's `STYLEGUIDE.md` §4 (palette) / §5 (type) / §6 (UI) + the `jungle-style` skill.
- **Construction discipline** — game-agnostic rules: `Color3.fromRGB()` for every colour · `UICorner`
  on non-rectangular elements · `UIStroke` on bordered elements · `BorderSizePixel = 0` · **set
  `Parent` last** · never hardcode player data, drive from attributes/remotes.
- ⚠️ **Do not import Defender's design values.** `/roblox-gui` is Defender's system — SourceSans and
  pure-white text are the wrong game. Jungle is Builder Sans + cream `#F3E6C2`, never pure white.

### `Theme.luau` token set

```
Theme.color   -- §4 verbatim
  jungleDark #1B341C · jungleMain #31552B · palmLeaf #47713A
  panel #24352D · panelAlt #243542 · wood #806142 · woodDark #4C3725
  gold #D69B22 · green #4B7A2B · blue #356B9A · red #A84B3C · yellow #D5A12B
  cream #F3E6C2 · metal #4E5246 · metalDark #353A35

Theme.font    -- all built-in, zero uploads
  display/heading BuilderSansExtraBold · button BuilderSansBold · body BuilderSansMedium
  sign SpecialElite (decision #1) · mono RobotoMono (optional readouts)
  -- GOTCHA: Font.fromName("Special Elite") FAILS (no space in the family name).
  --         Use Font.fromEnum(Enum.Font.SpecialElite) / Font.fromName("SpecialElite").

Theme.text    -- §5 scale, cap/min: display 48-64/28 · h1 28-32/20 · h2 22-24/18
              -- button 20-24/16 · body 16-18/14 · caption 13-14/12
              -- always TextScaled + UITextSizeConstraint
Theme.space   -- 4 / 8 / 12 / 16 / 24 / 32
Theme.radius  -- panel 12 · control 8 · pill 999
Theme.stroke  -- wood border, thickness 2-3 (§6.1)
Theme.tween   -- fast .12 · normal .2 · slow .35 Sine InOut; toast Quad Out
Theme.icon    -- name -> rbxassetid, all 23 (registry images.md)
Theme.sound   -- event -> rbxassetid, all 11 (registry audio.md)
```

**Rule:** a screen may reference `Theme.*` and nothing else. A raw `Color3.fromRGB` or `Enum.Font` left
in a screen file after this job is a bug.

### `Components.luau` inventory

| Component | Spec | Used by |
|---|---|---|
| `panel(title)` | §6.1 — dark fill, wood `UIStroke`, `UICorner`, title strip, `X` (icon `close`), **tap-outside-to-close** | 4 panels |
| `button(variant)` | §6.2 — primary/secondary/gold/danger + hover/pressed/disabled | everywhere |
| `chip(icon, value)` | §6.3 — dark rounded chip, icon + tabular value | Gold chip |
| `row(icon, name, blurb, action)` | §6.5 — the shop/skill/objective row | 3 shops + weekly |
| `progressBar(fill)` | §6.8 — dark track, green fill, rounded, optional label | skills, rank bar |
| `toast(icon, title, subtitle)` | §6.7 — slide in/out, **auto-dismiss, never blocks input** | upgrades, claims |
| `icon(name, size)` | `ImageLabel` from `Theme.icon`, seated on a dark chip (decision #5) | everywhere |

## Implementation steps

**Phase 1 · Foundation**

1. `Theme.luau` + `Components.luau` + `UISound.luau`.
2. `RankDefs` gains `nextTierFor(score)` — **mirrored byte-identically into `sync/`** (data only, no
   behaviour change). Falls back to `legendStars` at *River Legend*, where there is no next tier.

**Phase 2 · Validate the tokens on the two most dissimilar screens**

3. `GoldHud` → the §6.3 top bar: avatar · name · **rank tier** · **River Score → next tier** · Gold chip.
4. `RobuxShop` → panel + rows using the 7 live product/pass icons + buy/confirm popup (§6.5/§6.6).

> **Gate:** if the token set can't express both without additions, fix `Theme` *before* phase 3. This is
> also where the two deferred questions get answered by eye — rank-tier colour (ladder colour vs cream +
> accent dot), and whether any of the 6 loud icons need desaturating.

**Phase 3 · Rollout**

5. `SkillShop` — icon per skill, `Lv n / 10` + progress bar (**not** per-level art; `MAX_LEVEL = 10`).
6. `ModulesShop` — icon per module, OWNED state; art slots left for the 7 renders (§1.9b).
7. `RetentionClient` — weekly objectives, claim states, toast.
8. `TeleportGui` — full-screen launch; logo + `teleport_woosh`.
9. `AdminClient` — tokens only, no redesign.

**Phase 4 · Sound + mobile**

10. Wire all 11 SFX through `UISound`:

| Sound | Trigger | Where |
|---|---|---|
| `open_close` | panel open **and** close | all 4 panels |
| `prompt` | prompt shown / hold complete | `LobbyStations` |
| `purchase_success` | purchase confirmed | 3 shops |
| `failed_or_not_allowed` | insufficient gold · cancel · not allowed | 3 shops |
| `upgrade_applied` | skill level or module unlocked | SkillShop, ModulesShop |
| `rank_completed_or_mission_completed` | weekly objective claimed | RetentionClient |
| `joined_pad` | step on / off a pad | `LobbyServer` |
| `leader_assigned` | first player on an empty pad | `LobbyServer` |
| `teleport_woosh` | party launches | TeleportGui / `LobbyServer` |
| `footsteps_wood` · `running_on_sand` | material-aware footsteps | character script |
| `ui_mouse_click` | any button (already wired) | `UISound` |

> UI sounds are 2D; pad and prompt sounds stay **positional** on their world part, matching how
> `LobbySoundscape` already works.

11. Device Emulator pass on every screen — §6.10 is a requirement, not a final polish step.

## What I need from you

- [ ] **Go-ahead on this plan** (or edits).
- [ ] **Rojo-sync + save the place** after each phase so I can verify in Play — `LobbyServer` /
      `LobbyStations` / `LobbySoundscape` from #064 are still unsynced.
- [ ] **The 7 upgrade renders** (`ASSETS.md §1.9b`) whenever convenient — not blocking; ModulesShop
      ships with icon + text and takes the art later.
- [ ] Nothing else — all 41 asset IDs are sourced and verified.

## Verification

No runtime test harness, so the gates are:

- [ ] **`tools/luau-analyze.sh <file>` on every edited `.luau`**, findings resolved before moving on
      (sourcemap stays enabled or every `require`/`WaitForChild` false-positives).
- [ ] **Play test per phase** — panels open/close, purchases complete, claims grant, party flow and
      countdown work. *Behaviour identical to before; only pixels change.*
- [ ] **Device Emulator (phone)** on every screen — safe-area, ~44×44 tap targets, readable text.
- [ ] **Screenshots** per screen, checked against `GUI_PATTERN.png` for look and §4/§6 for the rules.

### Risks

| Risk | Mitigation |
|---|---|
| Restyle silently breaks a purchase/claim path | Visual layer only; server contracts untouched; play-test each buy path per phase |
| `Theme` designed around one screen, fights the rest | Phase 2 gate on the two most dissimilar screens |
| `RankDefs` copies drift | Change both trees together; byte-identical by convention |
| Loud icons fight the muted palette | Dark-chip seating; desaturate only if phase 2 shows it's needed |
| Scope creep into the game place | 15 game screens out of scope; `Theme` gets its `sync/` copy only when that restyle starts (decision #7) |

## Definition of done

- [ ] `Theme` / `Components` / `UISound` exist; **no raw colour or font literal left in any lobby screen**
- [ ] All 8 screens restyled to §4/§5/§6
- [ ] 23 UI icons + 7 monetization icons wired
- [ ] 11 SFX wired and audible in Play
- [ ] Analyzer clean on every edited file
- [ ] Device Emulator pass on every screen
- [ ] Purchase, claim and party flows verified unchanged
- [ ] `ASSETS.md` + registry updated if anything moves; `final-summary.md` + `changelog.md` written
