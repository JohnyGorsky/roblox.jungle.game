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
| `iconBar(entries)` | **one** shared entry bar — scale-based, safe-area aware, icon + label. Replaces the 4 ad-hoc open buttons | lobby entry |
| `confirm(item, cost)` | §6.6 — CANCEL (red) / BUY (green) before any Gold is spent | SkillShop, ModulesShop |

### Found by looking at the running game (2026-07-30, Play screenshot)

The intake was written from the code; a Play screenshot showed three things the file list didn't:

1. **An on-screen entry stack already exists.** Every panel script builds its *own* open button —
   `RobuxShop` at `(0,14),(1,-224)`, `RetentionClient` at `(1,-154)`, `ModulesShop` at `(1,-14)`,
   `AdminClient` bottom-right. They are **hardcoded pixel offsets manually stacked**, so entry is
   *both* kiosk-driven and screen-button-driven. **This invalidated the premise of intake decision #8**
   (which assumed kiosk-only).
   → Those absolute offsets are also a **live mobile defect**: on a small screen they overlap or run
   off. §6.10 requires scale-based positioning.
   → **RE-DECIDED (user, 2026-07-30): decision #8 is superseded.** Build **one shared icon bar** owned
   by `Components` — scale-based, safe-area aware, icon + label — replacing all four ad-hoc buttons.
   Kiosks remain the second route in. This removes four duplicated implementations and fixes the
   mobile defect in one place.
2. **Two GUI surfaces were missing from scope** (now added — 10 surfaces, not 8):
   - **Rank nameplate** — a `BillboardGui` built by `RankServer.server.luau` showing tier + name +
     River Score over the player's head. Currently white/grey, off-palette.
   - **Hint banner** — top-centre, built by `LobbyClient.local.luau` ("Step on a LAUNCH PAD…").
3. **`AdminClient`'s open button is magenta** — not a colour in §4. Tokens-only still applies, but the
   magenta goes.

**Reading well already:** the Gold chip (top-right) is close to the §6.3 chip spec and is a good
baseline for the token set.

### Full mockup audit — every `GUI_PATTERN.png` element vs what's actually in the game

Swept both the code and the live place (26 world GUIs found: 8 `BillboardGui` + 18 `SurfaceGui`).

**The headline finding: the world-space GUI is already on-spec; the drift is entirely screen-side.**
Every station sign, pad label, leaderboard and signpost already uses **Builder Sans / Oswald / Special
Elite** per §5. Only the 8 `ScreenGui` scripts use Gotham. World signage needs *icons*, not a restyle.

| Mockup element | In game? | Where / what's missing |
|---|---|---|
| **Top HUD bar** (avatar·name·level·XP·chips) | ⚠️ partial | Only the Gold chip exists. Bar built in phase 2 with **rank in place of XP** (decision #6). |
| **Currency chips ×3** | ✅ correct as-is | One chip, Gold. The other two are mockup-only — the game has no other lobby wallet. |
| **Main menu** (PLAY·BOAT UPGRADES·SKILLS·PARTY·INVENTORY) | ❌ / n/a | Deliberate: PLAY and PARTY are **physical** (launch pads), INVENTORY doesn't exist in the lobby. Do not build. |
| **Bottom bar** (5 icon buttons) | ❌ | Replaced in reality by the ad-hoc left button stack — see the entry-model re-decision. |
| **Notification toast** ("BOAT UPGRADED!") | ❌ **missing** | Nothing anywhere emits a toast. `Components.toast` + wire to upgrade/claim. |
| **Shop/upgrade panel** (art · stat deltas · before→after) | ⚠️ partial | Rows show name/blurb/cost/buy. **No item art, no `+%` stat deltas, no before→after.** Deltas are cheap (`SkillDefs.per`/`unit` already exist); art waits on §1.9b. |
| **Buy popup / CONFIRM PURCHASE** | ❌ **missing for Gold** | Robux uses Roblox's own prompt. **Gold spends (skills, modules) buy instantly on click — no confirm.** That's a mockup gap *and* a real UX/mis-tap risk. |
| **Button styles ×4** (primary/secondary/gold/danger) | ❌ | Ad-hoc colours per screen. Becomes `Components.button(variant)`. |
| **Progress bar** | ⚠️ partial | One exists — `RetentionClient` objective bar. Skills show `Lv n / 10` as **text only**. Unify via `Components.progressBar`. |
| **Checkbox · toggle · slider** | ❌ / n/a | No settings panel exists in the lobby → **out of scope**; build when one does. |
| **Party pads** (coloured + group icon) | ⚠️ partial | 4 `BillboardGui`s ("Blue PAD"…) in Builder Sans Bold. **No `user_group` icon** — wire it (one colour, decision #3). |
| **Shop signs w/ icons** (star·gear·wrench) | ⚠️ partial | All 4 stations have Special Elite entry signs + billboards. **No icons** — wire `star`/`wrench`/`shop`/`target_bounty`. |
| **Upgrade item art** (engine·hull·fuel·storage·turret) | ❌ | The 7 renders, §1.9b. Not blocking. |
| **Leaderboards** | ✅ done | 2 `SurfaceGui`s, Builder Sans + Oswald, live Top-10 + #1 gold glow. |
| **Welcome sign · signpost** | ✅ done | Special Elite, on-spec. |

**Net new work this audit surfaced:** a toast component, a Gold confirm-purchase popup, `+%` stat
deltas in the shops, icons on the 8 world billboards, and unifying the one existing progress bar.

### Mockup review vs GAME.md + STYLEGUIDE §12/§14 + `roblox-ui` (2026-07-30)

**Holds up:** palette is §4 verbatim · panels/buttons match §6.1/§6.2 (rounded, thick wood border, no
glass/gradients) · party pads match §6.9 · the shop buildings pass the §12 world test · item art is in
the §4 military/metal range. The mockup is a **good style target**. The gaps are about *states,
platform and coverage*, not looks.

| # | Gap | Source rule |
|---|---|---|
| A | **No mobile layout.** The sheet is desktop 16:9 throughout — a top bar with avatar+XP+3 chips, a 5-button main menu *and* a 5-icon bottom bar. That's heavy chrome for a phone. | GAME.md "mobile-first (hard requirement)"; `roblox-ui` scale/safe-area/thumb-zone |
| B | **Only the happy path is drawn.** No disabled button, no insufficient-funds/error visual, no empty state, no loading state. We have the `failed_or_not_allowed` **sound** with nothing visual to pair it with. | §6.2 requires a disabled state |
| C | **No collapsed state.** Heavy panels must be collapsible and default collapsed during play. Lobby is calmer than in-run, but the pattern is defined here and the game place inherits it. | §6.11, §12 "Never … heavy panel left expanded during active play" |
| D | **UI VFX missing — including from my own plan.** The juice rule is *every meaningful action has a sound **and** matching VFX*. The plan wired 11 sounds and zero effects. `ASSETS.md §1.10` already lists "Purchase-confirm burst — ▫ queued". **Added to phase 3c.** | `jungle-style` juice rule (hard); §12 |
| E | **Naming inconsistency, player-visible.** The building sign says **BOUNTIES**, the screen button says **WEEKLY**, the panel title says **WEEKLY OBJECTIVES** — one feature, three names. (`LobbyStations` maps `Bounties → weekly`.) | §11 naming; plain UX |
| F | **Two skill shops in the mockup, one in the game.** The map shows *GOLD SKILL SHOP* (major, gold) and *SMALL SKILL SHOP* (smaller) as separate buildings, and §7's vocabulary splits Star = major/gold skill vs Wrench = utility/small skill. The code has **one** `SkillTrainer` station and one panel grouped **Boat / Crew** — not major/small. | §7 vs `SkillDefs` |
| G | **No settings panel exists** anywhere, though the mockup's bottom bar has a settings icon. Mobile players expect volume at minimum. | mockup vs code |
| H | **Not in the mockup but live and fine:** loading screen, teleport/launch screen, party-countdown billboard. The sheet isn't exhaustive — absence there is not a spec to delete them. | — |
| I | **`INVENTORY` in the mockup's main menu** — GAME.md treats inventory as *in-run carried items*; there is no lobby inventory. Almost certainly game-place only. | GAME.md §Inventory |
| J | **The `+` beside the currency chip** is a good, fair-monetization affordance (tap → RobuxShop) and is cheap. **Recommended — added to phase 2.** | §6.3; GAME.md "convenience, not power" |

**Resolved (user, 2026-07-30):**

- **E → `BOUNTIES` everywhere.** Building sign, entry button and panel title all become BOUNTIES; the
  internal `weekly` OpenPanel id and `RetentionDefs` stay as they are (no data change, player-facing
  strings only). Fits the fiction and the building already standing in the lobby.
- **F → one skill shop, `Boat` / `Crew` groups.** The code is the truth; the two buildings were a
  mockup idea. Group headers use the `motorboat` and `navy_crew` icons. **No second station, no
  `SkillDefs` change.** The star/wrench major-vs-small split is *not* built here — §7's icon vocabulary
  keeps `star` for gold-tier meaning and `wrench` for utility meaning without implying two shops.
- **G → settings panel is out of scope.** New functionality with its own persistence questions; goes to
  `Planned/` rather than into a restyle.
- **A → I derive the phone layout** per `roblox-ui` (scale, safe-area, thumb zones) and send **Device
  Emulator screenshots at every phase gate** for approval. No portrait mockup needed up front.
- **I** — `INVENTORY` confirmed game-place only; not built in the lobby.

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

**Phase 3b · The two other screen surfaces + world GUI** *(added by the audit)*

10. `LobbyClient` hint banner — tokens + §6.7 styling.
11. `RankServer` rank nameplate (`BillboardGui`) — tier colour + cream name, on-palette.
12. **World billboard icons** — wire icons onto the 8 station/pad billboards that already exist and are
    already on-spec for type: `star` → SkillTrainer · `wrench` → BoatUpgrades · `shop` → RobuxShop ·
    `target_bounty` → Bounties · `user_group` → all 4 pads. *Icons only — the type stays as it is.*

**Phase 3c · The gaps the audit found** *(new behaviour — called out, not silent)*

13. **Gold confirm popup — APPROVED (user, 2026-07-30), all Gold spends.** Skills and modules currently
    spend Gold **instantly on click with no confirmation**. Add `Components.confirm(item, cost)` →
    CANCEL (red) / BUY (green) per §6.6, shown before any Gold is deducted.
    ⚠️ *This is the one deliberate behaviour change in the job* — it inserts a step into the buy flow.
    The server contract is untouched; the popup gates the client call. Play-test both paths (confirm
    → purchase completes; cancel → nothing spent).
14. **`+%` stat deltas** in SkillShop rows (§6.5) — `SkillDefs.per`/`.unit` already carry the numbers.
15. **Toast** on upgrade bought / objective claimed, via `Components.toast`.
16. **UI VFX — the juice rule (gap D).** Every meaningful action needs sound **and** effect, so sounds
    alone don't satisfy §12. Add pooled, palette-tinted, budget-capped bursts:
    **purchase-confirm burst** (gold motes on the chip + the bought row — `ASSETS.md §1.10` already has
    it queued) · **upgrade-applied flash** on the row · **claim burst** on a completed objective ·
    **gold-chip pulse** when the balance changes. Tween-driven `Frame`s and one small `ParticleEmitter`
    template — no new assets required.
17. **Failure state (gap B).** Pair `failed_or_not_allowed` with something visible: a red shake on the
    cost row + a short inline reason ("Not enough Gold"). Currently the sound would play against a
    silent screen.
18. **Disabled + empty states (gap B).** `Components.button` gets its §6.2 disabled variant
    (desaturated, raised transparency); lists get an empty-state line rather than rendering nothing.

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
- [ ] **Device Emulator (phone) screenshots at every phase gate**, sent for approval (decision A) —
      safe-area, thumb-reachable targets, readable text. Sized by scale + aspect ratio, **not** a
      hardcoded "minimum px" (`roblox-ui`: no official tap-target size exists — test on device).
- [ ] `GuiButton.Activated` for every action (fires for mouse **and** touch) — no mouse-only events.
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
- [ ] All **10 screen surfaces** restyled to §4/§5/§6 (8 UI scripts + hint banner + rank nameplate)
- [ ] **One shared icon bar** replaces the 4 ad-hoc open buttons; no fixed-pixel positioning left
- [ ] Icons wired onto the **8 world billboards** (4 stations + 4 pads)
- [ ] **Gold confirm popup** on every Gold spend; cancel spends nothing
- [ ] Toast fires on upgrade bought / objective claimed; `+%` stat deltas shown in SkillShop
- [ ] 23 UI icons + 7 monetization icons wired
- [ ] 11 SFX wired and audible in Play
- [ ] Analyzer clean on every edited file
- [ ] Device Emulator pass on every screen
- [ ] Purchase, claim and party flows verified unchanged
- [ ] `ASSETS.md` + registry updated if anything moves; `final-summary.md` + `changelog.md` written
