# Job #065: Lobby GUI: design system + restyle to STYLEGUIDE (icons + SFX wired)

**Project**: `roblox.jungle`
**Created**: 2026-07-30
**Status**: Requirements Gathering (intake)

## Requirements / goal

Give the lobby a single, coherent GUI that looks like the game it belongs to.

Today every lobby screen is built at runtime in code with its own hardcoded style: **60 distinct
`Color3.fromRGB` values** across the UI scripts and **75 uses of `Enum.Font.Gotham*`** — a font the
styleguide doesn't mention. There is no shared theme or component module anywhere in
`ReplicatedStorage`, so each screen has drifted independently. The result works but reads as generic
Roblox UI, not as *Last River*.

This job builds the missing **design system** (a `Theme` + component module) and applies it to all 8
lobby screens, wiring the icon set and SFX that Job #064 sourced and verified but never connected.

**Reference:** `assets/Images/GUI_PATTERN.png` (the art-style sheet) is the visual target —
**as direction, not as literal spec** (see *Reading the mockup* below).

## Why now

- **The assets are ready and idle.** #064 delivered and Studio-verified 23 UI icons, 7 monetization
  icons and 11 SFX. None are wired. They only become value when the screens use them.
- **Cheapest moment to fix the foundation.** 8 screens is a tractable restyle; the game place has 15
  more that will inherit whatever system we build here. Building the theme *after* 23 screens exist
  costs far more.
- **First-session impression.** The lobby is where every player starts and where the party forms —
  the last thing they see before the run and the first thing they judge.

## Scope

**In — the 8 lobby screens** (`lobby/sync/StarterPlayer/StarterPlayerScripts/UI/`):

| Screen | What it needs |
|---|---|
| `GoldHud` | currency chip → the top-HUD bar (§6.3) |
| `RobuxShop` | panel, rows with the 7 live product/pass icons, buy/confirm popup (§6.5/§6.6) |
| `SkillShop` | panel, per-skill icons, `Lv n / 10` + progress bar |
| `ModulesShop` | panel, per-module icons, OWNED state |
| `RetentionClient` | weekly objectives panel, claim states, toast (§6.7) |
| `TeleportGui` | full-screen launch/teleport screen |
| `AdminClient` | minimal — theme tokens only, no redesign |
| `UIClick` | extend from click-only into the shared SFX layer |

Plus the **shared module** both trees will use, and the **11 SFX** wired per interaction.

**Out of scope — deliberately:**

- The **15 game-place screens** (`sync/.../UI/`). The theme module is written so they can adopt it
  later, but this job does not touch the game place. (Rule: never edit scripts across places —
  GAME `/sync/` vs LOBBY `/lobby/sync/`.)
- **New currencies, new systems, new screens.** Restyle and wire only.
- **The 7 upgrade-item renders** (`ASSETS.md §1.9b`) — not yet generated. The Boat-Upgrades panel and
  buy popup ship with icon + text and get the art dropped in later; nothing else waits on them.
- Editor-authored GUI. `StarterGui` is empty and stays empty — all lobby GUI is runtime-built.

## Decisions locked (user, 2026-07-30)

| # | Decision |
|---|---|
| 1 | **Sign font = Special Elite.** STYLEGUIDE §5 stays authoritative; the mockup's stencil signage is illustration. |
| 2 | **Gold is the only lobby currency** — one chip. Confirmed against the data model, not the mockup (below). |
| 3 | **Party pads keep one icon colour** on all four. The pads already carry colour via ring, glow column, edge lights and label; `user_group` is full-colour and can't be tinted. |
| 4 | **SFX wiring is part of this job**, not a separate one — sound and visuals land together per screen, so each screen is finished once. |
| 5 | **Ship the icon set as-is** and judge it in context. Six of the 23 are loud (`check`, `star`, `winner_trophy`, `shield`, `coin`, `fuel-station` measure 69–95% saturation); the rest are muted or effectively mono. Seat them on dark chips; re-export desaturated later only if they fight the ground. |
| 6 | **Top HUD bar = §6.3's shape, with rank in place of XP.** Avatar · name · **rank tier** · **River Score progress to the next tier** · Gold chip. No level system is invented — the bar is driven by the rank ladder that already exists. |
| 7 | **Theme module ships to the lobby tree only.** The byte-identical `sync/` copy is added when the game place is actually restyled, so an unused file can't drift out of sync first. |
| 8 | **Entry stays kiosk-driven — no bottom bar.** Panels open from the world stations built in #064. Keeps §6.11 minimalism and makes the physical lobby the interface instead of duplicating it in UI. |

### Consequences of decision #6 (found while checking `RankDefs`)

- **`RankDefs` has no "next tier" helper.** It exposes `tierFor(score)`, `legendStars(score)` and
  `shortScore(score)` — the progress bar needs the *next* tier's `min` to compute a fill. Either add a
  small `nextTierFor(score)` helper or derive it client-side from `RankDefs.Tiers`.
- **`RankDefs` is a shared module with a byte-identical copy in both trees.** If a helper is added, both
  copies must change together — this is the one place this job legitimately touches a file that also
  exists in the game tree (data only, no behaviour change).
- **Top-tier edge case:** at *River Legend* (220,000) there is no next tier. The bar should switch to
  prestige stars (`legendStars`, one per `LEGEND_STAR_STEP` = 100,000) rather than showing a full or
  broken bar.
- **Tier colours sit outside §4.** The ladder uses teal, blue, purple and magenta — colours the jungle
  palette doesn't contain. Decide at plan time whether the tier name takes its ladder colour (readable,
  familiar, off-palette) or cream with the ladder colour used only as a small accent dot.

## Reading the mockup (STANDING RULE: direction, not spec)

`GUI_PATTERN.png` is an **idea sheet — colours, type feel, spacing and component styling.** It is not a
feature list. **Nothing gets built because the mockup shows it.** Take the look from the mockup; take
*what exists* from the code (`GAME.md`, the `*Defs.luau` modules, the profile schema). Where they
disagree, **the code wins** and the divergence is written down here.

Two places where following it literally would have put wrong things in the game — both checked against
the code, not assumed:

- **Currencies.** The mockup HUD shows three chips (gold / cash / gems). The real model is
  **Gold** (persistent, spendable — `leaderstats` + the `Gold` attribute, the cost of every skill and
  module), **River Score** (persisted but a *rank accumulator*, not a wallet — belongs to the rank and
  leaderboard display, where `RankServer` already puts it) and **Salvage** (**in-run only** — does not
  exist in the lobby). → **One chip. Gold.** We do not invent currencies.
- **Upgrade levels.** The mockup shows `LEVEL 1 → 2 → 3` art per upgrade. In the actual model
  **modules are one-time unlocks** (`ModuleDefs` — buy once → OWNED, no tiers) and **skills go to
  level 10** (`SkillDefs.MAX_LEVEL = 10`), so per-level art is impossible either way. → Skills show
  icon + `Lv n / 10` + progress bar; modules show one render each.

## Design principles this job is held to

From `jungle-style` / STYLEGUIDE and the `game-design` + `roblox-ui` skills:

- **HUD minimalism (§6.11) is a hard rule.** Only mandatory at-a-glance info persists; everything else
  opens on demand, has a visible `X` *and* tap-outside-to-close, and never covers core info. One
  primary panel open at a time. Toasts are transient and never block input.
- **Mobile-first is not a pass at the end (§6.10).** `UDim2` scale, `UIScale`/`UIAspectRatioConstraint`/
  `UISizeConstraint`, safe-area aware, ~44×44 tap targets, `TextScaled` capped by
  `UITextSizeConstraint`. Tested in the Device Emulator before any screen is called done.
- **Accents mean something (§4).** Gold = major progression, green = confirm/positive, blue = utility,
  red = cancel/destructive. An accent used decoratively is a bug.
- **Text is cream `#F3E6C2` with a dark stroke — never pure white** (§5).
- **The UI matches the physical world** — military equipment, crates, metal plates, wood signs. No
  futuristic glass, no heavy gradients (§6).
- **Never sell power.** The shop's job is to be readable and honest, not to pressure. Buy flows state
  exactly what is bought and what it costs, with a real cancel.
- **The party flow is the co-play surface** — the thing Roblox's discovery actually rewards. Pad
  state, party membership and countdown must be legible at a glance on a phone.

## Assets — status going in

| Asset | Count | State |
|---|---|---|
| UI icon set | 23 | ✅ uploaded + Studio-verified (`ASSETS.md §1.9`, registry `images.md`) |
| Monetization icons | 7 | ✅ live on Creator Hub + usable in-game (`ASSETS.md §5.1`) |
| Lobby SFX | 11 | ✅ uploaded + Studio-verified, **unwired** (registry `audio.md`) |
| Loading art, logo | 2 | ✅ already wired |
| Fonts | — | ✅ all built-in, zero uploads (`BuilderSans*`, `Oswald`, `SpecialElite`, `PermanentMarker`, `RobotoMono`) |
| Upgrade-item renders | 7 | ▫ **not generated** — `ASSETS.md §1.9b`. Does not block this job. |

**Font gotcha:** `Font.fromName("Special Elite")` fails — the family name has no space. Use
`Font.fromEnum(Enum.Font.SpecialElite)` or `Font.fromName("SpecialElite")`.

## Constraints & risks

- **Two trees, one experience.** Shared modules exist as byte-identical copies in `sync/` and
  `lobby/sync/`. A theme module placed in `ReplicatedStorage` must follow that convention or drift.
- **Rojo sync + Play test is a user action** — every change needs a sync before it can be seen.
- **No runtime test harness.** The verification gate is the luau-lsp analyzer on every edited `.luau`,
  plus in-Play checks and Device Emulator screenshots.
- **Risk: restyle-by-rewrite.** These screens carry working purchase, claim and party logic. The
  restyle must not touch the server contracts or the purchase/claim flow — visual layer only. Any
  behavioural change is a separate, called-out decision.
- **Risk: theme churn.** If the theme module is designed against one screen it will fight the other
  seven. Validate the token set against the two most different screens (`GoldHud`, `RobuxShop`) before
  rolling it out.

## Open questions

_All intake questions resolved 2026-07-30 → decisions 1–8 above._ Two items are deliberately deferred to
the implementation plan, where they're cheaper to answer with a screen in front of us:

| # | Deferred to plan |
|---|---|
| 1 | Rank tier colour on the top bar — ladder colour vs cream + accent dot (see decision #6 consequences). |
| 2 | Whether any of the 6 loud icons need desaturating, judged on the first restyled panel (decision #5). |

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created — **awaiting go-ahead**
- [ ] Implementation completed
- [ ] Final summary + changelog written
