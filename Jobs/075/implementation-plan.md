# Implementation Plan — Job #075

**Project**: `roblox.jungle`
**Created**: 2026-08-02
**Status**: Planning (awaiting go-ahead)

---

## Analysis

### The problem, measured

The game place has **15 ScreenGuis across 2,743 lines** of runtime-built client GUI. Between them:
**60 distinct `Color3` literals** and **34 uses of `Enum.Font.Gotham*`** — a font `STYLEGUIDE.md` never
mentions, and pure white (`Color3.new(1,1,1)`) text, which §4 explicitly forbids.

That is the *same* measurement Job #065 took of the lobby before restyling it (60 colours, 75 Gothams).
The lobby was fixed; the game place was not. The two places currently look like different games.

### What already exists (so we are not building it twice)

**The design system is already in the game tree.** Job #074 ported it for the Robux shop:

| File | Lines | Status |
|---|---|---|
| `sync/ReplicatedStorage/UI/Theme.luau` | 227 | ✅ tokens: 15 colours, 8 fonts, 6 text scales, 23 icon IDs, 14 sound IDs |
| `sync/ReplicatedStorage/UI/Components.luau` | 1011 | ✅ `panel` `button` `chip` `row` `progressBar` `toast` `icon` `iconButton` `confirm` `burst` `iconBar` `screen` `applyText` |
| `sync/ReplicatedStorage/UI/UISound.luau` | 112 | ✅ `UISound.play("open")`, cached + debounced |
| `sync/ReplicatedStorage/UI/UIBus.luau` | 33 | ✅ local panel-open bus |

**Exactly one game-place screen consumes it** — `RobuxShop.local.luau`. The other 14 are greybox.

> ### ⛔ Hard constraint — the `UI/` folder is byte-identical by contract
> `lobby/sync/ReplicatedStorage/UI/` and `sync/ReplicatedStorage/UI/` must stay byte-identical
> (`diff -r` silent) — same deal as `MonetizationDefs` / `BoatParts` / `BoatPaint`. So **this job does
> not add run-only modules into `UI/`.** New game-only UI code goes in a **new sibling folder
> `sync/ReplicatedStorage/RunUI/`**, which the lobby never gets.
>
> Token *additions* to `Theme.luau` (new icon and sound IDs) are fine and **must be copied to both
> trees in the same commit.**

### Approach

Build the **state controller first**, then a small set of run-only components, then convert every
screen in one pass — style, icons and sound together — so nothing is revisited. Same shape as #065.

**Non-negotiable:** this is a **presentation layer**. Server contracts, remote signatures, damage,
economy and role logic do not change. The one behavioural addition is the touch drive controls, and
those map onto the *existing* `VehicleSeat` Throttle/Steer actions — no new remote.

---

## Part 1 — The three states

### 1.1 What the states are

Confirmed with the wizard: the third state is **ashore at a dock**, not the results screen.

| | State | Condition | The player is… |
|---|---|---|---|
| **A** | `CRASHSITE` | `Workspace.RunStarted ~= true` | awake at the wreck, regrouping, boarding |
| **B** | `ABOARD` | `RunStarted` **and** standing/seated on the Boat | riding the river |
| **C** | `ASHORE` | `RunStarted` **and** not on the Boat | tied up, on foot in the jungle basin |

`RESULTS` is **not** a fourth state — it is a full-screen overlay on top of whichever state was live
(`RunEnded`), same as `DOWNED`. Overlays dim and suppress the states; they do not replace them.

### 1.2 How the client decides

`StagingServer.server.luau:234-240` already has the correct on-boat predicate and explains why the
obvious one is wrong:

> *"A bounding box overlaps the pier when the boat is docked ~2 studs off it, wrongly counting
> pier-standers."*

It **raycasts 8 studs down with an Include filter on the Boat model** — but only publishes
`OnBoatCount` `while not started`, i.e. it stops the moment the run begins, exactly when states B/C
need it.

**Decision: the client runs the same predicate itself, at 5 Hz.** This is a presentational choice with
nothing to exploit — a cheater who lies to their own HUD has achieved nothing — so it needs no server
round-trip. It must stay a *copy of the same rule* (down-raycast, Include-filter on `Boat`), so the
client and `StagingServer` never disagree about who is aboard. Seated players are covered too:
`humanoid.SeatPart` being a descendant of `Boat` short-circuits to `ABOARD` (a driver's raycast can
miss between hull parts).

Debounce: a state must hold for **0.4 s** before it is broadcast. Without it, jumping on deck or
walking the gangplank strobes the whole HUD.

### 1.3 `RunUI/HudState.luau` — the controller

One module, the single source of truth. Same BindableEvent shape as `UIBus` (which #065 proved out):

```
HudState.current() -> "CRASHSITE" | "ABOARD" | "ASHORE"
HudState.onChange(fn)            -- fires with (new, old)
HudState.bind(guiObject, states) -- convenience: show only in these states
HudState.isDriver() / .isGunner() / .station() -- sub-flags, own signals
```

Every screen **subscribes** rather than each re-deriving "is the run on". Today six separate scripts
each poll `Workspace:GetAttribute("RunStarted")` on `RenderStepped`; they collapse into one 5 Hz
`Heartbeat` loop here. Net win: **6 per-frame loops → 1 five-hertz loop.**

---

## Part 2 — Layouts

Everything below is `UDim2` **scale**, `TextScaled` + `UITextSizeConstraint`, safe-area aware
(§6.10). Offsets only for hairlines and padding.

### 2.0 Persistent core HUD (all three states — never covered by a panel, §6.11)

| Where | What | Built from |
|---|---|---|
| Top-right | **Gold chip**, **Salvage chip** — `[icon] 1,250` | `Components.chip` — identical to the lobby's |
| Bottom-left | **Player health bar** — themed, replaces the Roblox core bar | new `RunUI` gauge |
| Bottom-left | **Loadout hotbar** — 4 slots (6 with the pass) | restyled `InventoryHud` |
| Anywhere | **Toasts** — auto-dismiss, never block input | `Components.toast` |

No avatar, no PLAYERNAME, no LEVEL, no XP bar. Per the wizard answer and §6.11 — that block in
`GUI_PATTERN.png` is the **lobby's** top bar, and the lobby already has it (`TopBar.local.luau`).

### 2.1 State A — CRASH SITE

```
┌──────────────────────────────────────────────────────────┐
│                                    [🪙 250] [⚙ 0]        │  chips
│                                                          │
│            ╔══════════════════════════════╗              │
│            ║  BOARD THE BOAT & UNTIE      ║              │  panel, wood stroke
│            ║  ▓▓▓▓▓▓▓▓░░░░  3/4 ON BOAT   ║              │  Components.progressBar
│            ╚══════════════════════════════╝              │
│                                                          │
│                    [ ⛽ 100% ] [ 🛡 100% ]                │  boat gauges, muted
│  ❤ ▓▓▓▓▓▓▓▓▓▓                 ┌──────────────┐          │
│  [🗡][  ][  ][  ]              │ PULL & START │          │  primary green
└──────────────────────────────────────────────────────────┘
```

- The crew counter becomes a **real progress bar** (green at N=M) instead of a text line — you read
  "are we all aboard?" at a glance without parsing digits.
- `PULL & START` is `Components.button("primary")`, shown only to a driver-seated player. It keeps
  the existing `RequestUntie` remote untouched.
- Boat gauges are present but at reduced emphasis — you want to see your starting tank, but it is not
  yet the thing at stake.
- No objectives, no river bar, no touch controls (the run has not started).

### 2.2 State B — ABOARD

```
┌──────────────────────────────────────────────────────────┐
│  ⛽12 ⚙8 🔫40      ▓▓▓▓●───┬────────⚑        [🪙][⚙]     │  cargo · river bar · chips
│  cargo chips        HEADWATERS   ▲dock  END   OBJ 1/3 ▾  │  objectives COLLAPSED
│                                                          │
│  ┌────────────┐                                          │
│  │🎡 DRIVER   │                                          │  role chip (station bonus live)
│  │ +HANDLING  │                                          │
│  └────────────┘                                          │
│                          ⛽ ▓▓▓▓▓▓░░░░  62%              │  fuel gauge
│  ❤ ▓▓▓▓▓▓▓▓             🛡 ▓▓▓▓▓▓▓▓▓░  88%              │  hull gauge
│  [🗡][🔫][💊][  ]      ◀ ▶                    ▲ ▼        │  hotbar · steer · throttle
└──────────────────────────────────────────────────────────┘
```

- **River progress bar** (top-centre) replaces the bare `NEXT FUEL 1234 studs` text. A track with: a
  boat marker at `BoatDistance / RiverEndDistance`, tick segments per zone with the current zone named
  beneath, a pin for the next fuel landing, an END flag. **When a full tank cannot reach the next
  landing the pin turns red** — that is the existing "conserve or be stranded" signal from
  `HudClient:185`, kept, but now spatial instead of a number.
- **Cargo chips** (top-left) replace the one-line
  `"CARGO Gas %d Metal %d Ammo %d (+%d rds)"` string with three icon chips. Same data, readable at a
  glance while steering.
- **Role chip** (left) — new. `RoleServer` has computed station bonuses since Job #034 and **nothing
  has ever told the player they are getting one.** Shows the station icon + name + the live bonus.
  Appears only while a station is manned; fades out when you step away.
- **Fuel + hull gauges** (bottom-centre) — icon + bar + %, above the touch controls. Low-fuel and
  low-hull thresholds tint the fill and fire a one-shot warning sound (§2.6).
- **Objectives collapse to a tab** `OBJ 1/3 ▾` by default and expand on tap — §6.11 requires heavy
  panels to default collapsed during play. Today the panel is permanently open in the top-right.
- **Touch drive controls** — only on touch input, only while driver-seated (§3).

### 2.3 State C — ASHORE

```
┌──────────────────────────────────────────────────────────┐
│  ┌──────────────┐                              [🪙][⚙]   │
│  │🚤 BOAT  180m │                              OBJ 1/3 ▾ │  boat status card
│  │🛡 ▓▓▓▓▓▓░ 71%│                                        │
│  │⚠ UNDER ATTACK│                                        │  flashes red when hull drops
│  └──────────────┘                                        │
│                                                          │
│                                              [ TRADING   │
│                                                POST ]    │  prompt-opened panel
│                                                          │
│  ❤ ▓▓▓▓▓▓▓▓▓░           🔫 40 / 120     💊 2            │  health · ammo · bandages
│  [🗡][🔫][💊][🛢]                                        │
└──────────────────────────────────────────────────────────┘
```

- The bottom-centre gauges **swap from the boat's vitals to yours**: equipped-gun ammo and bandage
  count. That is the actual answer to "what do I need to know while raiding a camp".
- **Boat status card** (top-left) — new, and the reason this state earns its own layout. GAME.md's
  core tension is *"the boat sits exposed at the dock while you're inland"*, and today **nothing tells
  you it is being chewed on.** Card shows hull %, distance back to it, and flashes a warning when hull
  drops while you are ashore.
- River bar and cargo chips hide — you are not moving and not at the deck.
- The **dock shop** (`DockShopClient`) becomes a real `Components.panel` + `Components.row` list, same
  as the lobby's three shops, opened by the existing `OpenShop` remote.

### 2.4 Overlays (any state)

| Overlay | Change |
|---|---|
| `DownedHud` | Already half-themed (Job #067 hand-copied five colours in). Swap those constants for real `Theme`/`Components` — the header comment literally asks for this. |
| `RunGui` results | Rebuild on `Components.panel`; win = `trophy` icon + gold, loss = `skull` + red. Keep the return button + auto-return countdown exactly as-is. |
| `ZoneBanner` | Builder Sans display scale, cream + dark stroke, zone colour from `Theme`. |
| `RobuxShop` | ✅ already correct — untouched. |
| `AdminPanel` | Restyled, but stays deliberately plain (it is a dev tool). |
| `GunGui` / `WeaponGui` | Reticles get `Theme.color.cream` + a dark stroke so they read against bright water; gunner gets an ammo readout by the reticle. |
| `EnemyHealthBars` | Billboard bars on `Theme` colours; red at low HP. |
| `GameLoading` / `TeleportScreen` | Fonts + palette onto `Theme`. Both already use the right *idea* (dark jungle-night + LAST RIVER); they just hardcode it. |

### 2.5 Player health bar (replaces the Roblox core bar)

`SetCoreGuiEnabled(Health, false)` becomes permanent during a run, and a themed bar sits bottom-left
above the hotbar: dark track, green fill, cream value, **red pulse + soft screen vignette under 30%**.

⚠️ `IntroHudGate.local.luau:40-45` currently toggles the core Health GUI **back on** when the intro
ends. That line changes to leave it off and gate the new bar instead — otherwise both bars show.

### 2.6 Sound & VFX pairing (§12 juice — the hard rule)

Every state change and threshold gets a cue, via `UISound`:

| Trigger | Cue | VFX |
|---|---|---|
| Fuel crosses 20% ↓ | `lowFuel` (new) | gauge fill → red, slow pulse |
| Hull crosses 30% ↓ | `lowHull` (new) | gauge pulse + brief screen edge flash |
| Objective completed | `rank` ✅ existing | `Components.burst` on the row |
| Zone entered | `zoneEnter` (reuse candidate) | banner tween |
| Station manned | `upgrade` ✅ existing | role chip pops in (`Theme.tween.pop`) |
| Slot equipped | `click` ✅ existing | slot scale-pop |
| Loot picked up | `pickup` (reuse candidate) | chip value counts up + burst |
| You go down | `downed` (new) | existing red vignette |
| Revived | `revived` (new) | vignette clears + burst |
| Run won / lost | `runWin` (reuse) / `runLose` (new) | panel pop |

---

## Part 3 — Mobile touch drive controls

Currently P1's default `VehicleSeat` touch controls. Replaced with purpose-built ones.

**Answering the open question in `Planned/mobile-boat-controls.md` ("buttons vs joystick"):**
**two-thumb button clusters, not a joystick.** A joystick needs a fixed thumb origin, and the driver
is also watching the river; buttons can be large, fixed, and hit without looking. A boat has no
analogue steering feel to preserve — `VehicleSeat.Steer` is `-1 | 0 | 1` anyway, so a joystick would
quantise to the same three values while being harder to hit.

- **Left thumb:** `◀` `▶` steer pair — large, translucent, slide-between supported (drag from one to
  the other without lifting).
- **Right thumb:** `▲` `▼` throttle / reverse pair.
- Wired through **`ContextActionService`** to the same actions the keyboard uses, so PC keys keep
  working untouched and there is one code path.
- Visible only when `UserInputService.TouchEnabled` **and** `HudState.isDriver()`. They vanish the
  instant you leave the seat — no dead buttons on screen.
- Safe-area aware; sized by `UIScale` against viewport height so they are thumb-sized on a phone and
  not comical on a tablet.
- The gunner keeps mouse/touch aim as-is (Job #014) — not in scope.

---

## Part 4 — File plan

### New — `sync/ReplicatedStorage/RunUI/` (game-only, **never** copied to the lobby)

| File | Purpose |
|---|---|
| `HudState.luau` | State machine + sub-flags + `onChange` / `bind` (§1.3) |
| `RunComponents.luau` | Run-only builders on top of `Components`: `gauge` (icon + bar + value), `riverBar` (track + zone ticks + dock pin + END flag), `roleChip`, `slotButton`, `touchPad`, `banner` |

### New — client

| File | Purpose |
|---|---|
| `UI/HealthHud.local.luau` | Themed player health bar + low-HP vignette |
| `UI/RiverProgress.local.luau` | River progress bar (state B) |
| `UI/RoleChip.local.luau` | Station/role indicator (state B) |
| `UI/BoatStatusCard.local.luau` | Boat hull + distance + under-attack warning (state C) |
| `Boat/TouchControls.local.luau` | Steer + throttle touch clusters |

### Rewritten onto the design system

`HudClient` · `ObjectiveHud` · `InventoryHud` · `GoldHud` · `DockShopClient` · `StagingHint` ·
`UntieButton` · `ZoneBanner` · `DownedHud` · `RunClient` · `AdminClient` · `GunClient` ·
`WeaponClient` · `EnemyHealthBars` · `GameLoading` · `TeleportGui`

### Edited

| File | Change |
|---|---|
| `UI/IntroHudGate.local.luau` | Add the new ScreenGuis to `HUD`; stop restoring the core Health bar (§2.5) |
| `UI/Theme.luau` **×2 trees** | New icon + sound IDs. **Copy to both, same commit** (§ contract) |
| `ASSETS.md` | New §5.2 "In-run HUD icon set"; flip the *HUD icons* row from ▫ stub |
| `roblox.workspace/Assets/registry/{images,audio}.md` | Record every new ID |
| `Planned/P7-…md`, `Planned/mobile-boat-controls.md` | Mark promoted → Job #075 |
| `todo/0001`, `todo/0010`, `todo/0011` | Resolve — see below |

**Todos this job closes:**
- `0001` in-boat untie GUI button when tied at a dock → state B/C untie affordance
- `0010` hide in-game HUD objective during the plane intro → `IntroHudGate` + collapsed objectives
- `0011` role-suitability icon above the player → role chip (HUD form; the billboard half stays open)

### Untouched (explicitly)

Every `ServerScriptService` file. All remote signatures. `RobuxShop.local.luau`. `IntroFade`.
`lobby/` — apart from the two-tree `Theme.luau` copy.

---

## Part 5 — What I need from you

### 5.1 Icons — 12 required, 4 optional

**Source: Flaticon, and it must be the *same author* as the existing 23-icon set** (ASSETS.md §1.9:
*"One pack, one author — mixed packs are the #1 way an icon set looks amateur"*). PNG → upload →
give me the IDs.

The existing 23 already cover **all five role icons**, gold, hull, fuel, crate, tools, check, close,
trophy and boat — so this list is only what genuinely has no substitute.

| # | Icon | Used by | Why not reuse |
|---|---|---|---|
| 1 | **Scrap / salvage pile** | Salvage chip (in-run currency) | `loot` money-bag is already the Scavenger skill |
| 2 | **Metal plate / girder** | cargo chip, repair resource | no metal icon exists |
| 3 | **Ammo box / bullets** | cargo chip, ammo readout | `gun` is the mounted turret, not ammo |
| 4 | **Heart** | player health bar | `medkit` reads as an item, not a vital |
| 5 | **Machete / sword** | hotbar slot | the default weapon has no icon |
| 6 | **Pistol** | hotbar slot | `gun` = turret |
| 7 | **Bandage** | hotbar slot | `medkit` = the boat station |
| 8 | **Checkered / finish flag** | END marker on the river bar | — |
| 9 | **Warning triangle** | low fuel, boat under attack | — |
| 10 | **Sun** | day phase | — |
| 11 | **Moon** | night phase | — |
| 12 | **Skull** | downed overlay, crew-lost result | — |

*Optional (I have a working fallback for each, so these are nice-to-have):*
13 **Shotgun** (falls back to pistol) · 14 **Rope / knot** for untie (falls back to `tools`) ·
15 **Map pin** for the dock marker (falls back to `fuel`) · 16 **Clipboard** for the objectives tab
(falls back to `check`).

Steer/throttle arrows need **no asset** — `◀ ▶ ▲ ▼` render fine in Builder Sans.

### 5.2 Sounds — 5 new, 4 to confirm as reuse

**Source: Pixabay.** Short, dry, no music tails.

| # | Sound | When | Feel |
|---|---|---|---|
| 1 | `low_fuel` | fuel drops below 20% | single soft warning beep, not an alarm loop |
| 2 | `low_hull` | hull drops below 30% | metallic stress groan / klaxon hit |
| 3 | `downed` | you go down | low thud + breath, ~1 s |
| 4 | `revived` | picked back up | rising recovery swell, ~1 s |
| 5 | `run_lost` | crew wiped | somber descending sting, ~2 s |

**Already in the registry — confirm I may reuse these rather than sourcing new** (they are filed under
Defender, and the registry's whole point is reuse-before-re-source):
`item_drop` → loot pickup · `player_attacked` → taking damage · `level_completed` → run won ·
`battle_starts` → zone-crossing stinger.

Already correct and reused as-is: `rank_completed…` (objective done) · `upgrade_applied` (station
manned) · `ui_mouse_click` (equip) · `morning_starts` / `night_starts_2` (day/night).

### 5.3 One decision I could not make from the code

Nothing blocking. Everything else is derivable from `STYLEGUIDE.md` + the existing `Theme`.

---

## Part 6 — Order of work

1. **`HudState` + `RunComponents`** — the spine. Nothing else can be built against a moving target.
2. **State B (ABOARD)** first — the most-seen screen and the one with the most new parts (river bar,
   gauges, cargo chips, role chip). Proves the components under the hardest case.
3. **States A + C** — reuse everything from 2; only the boat-status card is genuinely new.
4. **Overlays** — downed, results, zone banner, dock shop, reticles, enemy bars.
5. **Health bar + `IntroHudGate` fix** — small but touches the intro, so it lands after the HUD is
   stable and can be tested through a full cold-open.
6. **Touch drive controls** — last, because it is the only behavioural change and wants its own
   focused device test.
7. **Registry + `ASSETS.md` + todo/Planned bookkeeping.**

Steps 1–4 can proceed with **fallback icons** (existing 23 + `Theme.productFallbackIcon`-style
substitution) if your icon batch is not ready — nothing blocks on it. Sounds likewise: `UISound.play`
on an unknown key is a silent no-op.

## Part 7 — Verification (before this is called done)

- **Play in Studio**, screenshot each of A / B / C plus every overlay. *(Reset `CameraType = Custom`
  after any `screen_capture` with a camera position — it leaves the Edit camera Scriptable.)*
- **Device Emulator, iPhone + a small Android** — every state, per §6.10's hard "test on a phone" rule.
  Specifically: nothing clipped by the notch, every tap target ≥ 44 px, touch controls reachable
  one-thumb-per-side.
- **`grep -rE "Color3\.(fromRGB|new)\(" sync/StarterPlayer sync/ReplicatedFirst`** → must return only
  `Theme`-derived call sites. A raw colour left in a screen is a bug (the #065 rule).
- **`grep -r "Enum.Font.Gotham" sync/`** → must be empty.
- **`diff -r lobby/sync/ReplicatedStorage/UI sync/ReplicatedStorage/UI`** → must be silent.
- **Run the §14 quality checklist** in `STYLEGUIDE.md`.
- Verify state switching by walking the actual loop: wake at the wreck → board → untie → ride → tie at
  a landing → go ashore → raid → come back → ride on.

---

## Estimate

~16 files rewritten, ~7 new, ~2,700 lines touched. Comparable to Job #065 (8 screens, 1,266 lines)
plus the state machine, the four new HUD features and the touch controls — so meaningfully larger.
