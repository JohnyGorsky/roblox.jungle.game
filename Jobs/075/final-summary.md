# Final Summary — Job #075

**Project**: `roblox.jungle`
**Completed**: 2026-08-03
**Status**: ✅ Implemented and verified in Studio Play. **Two follow-ups outstanding** — the asset batch
(placeholders are live and tracked) and a mobile-device pass. Both detailed below.

---

## What this job was

The game place had **15 ScreenGuis, 2,743 lines of runtime-built client GUI, 60 distinct raw `Color3`
literals and 34 uses of `Enum.Font.Gotham*`** — a font `STYLEGUIDE.md` never mentions — plus pure-white
text, which §4 forbids. The lobby had been put on a proper design system in Job #065. The game place
never was, so the two places looked like different products.

The design system was already *present* in the game tree (`sync/ReplicatedStorage/UI/`, ported by Job
#074 for the Robux shop) — but **exactly one screen used it.**

So: put every game-place screen on it, and organise the result into the three contexts the run actually
has.

## The three states

One controller, `RunUI/HudState.luau`, decides which of three layouts is live. Every screen subscribes
instead of re-deriving it — **six separate per-frame `RunStarted` polls collapsed into one 5 Hz loop.**

| | State | Condition | Shows |
|---|---|---|---|
| **A** | `CRASHSITE` | `RunStarted ~= true` | staging card + crew progress bar, PULL & START, boat gauges dimmed |
| **B** | `ABOARD` | running, standing/seated on the Boat | river progress bar, cargo chips, fuel/hull gauges, role chip, collapsed objectives, touch controls |
| **C** | `ASHORE` | running, not on the Boat | boat-status card (hull · distance · UNDER ATTACK), dock shop; boat vitals hidden |

Persistent in all three: Gold + Salvage chips (top-right), player health + bandages (bottom-left),
hotbar, toasts. **No avatar / name / level / XP bar** — that block in `GUI_PATTERN.png` is the lobby's
top bar, and §6.11 forbids it on the play screen.

**How the client decides who is aboard.** `StagingServer:234` already had the right predicate, and the
right reason for it: *"a bounding box overlaps the pier when the boat is docked ~2 studs off it,
wrongly counting pier-standers."* It raycasts 8 studs down with an Include filter on the Boat — but
stops publishing `OnBoatCount` the moment the run starts, exactly when states B/C need it. `HudState`
re-runs the same rule client-side at 5 Hz (a drawing decision needs no server round-trip), short-circuits
to ABOARD for a seated player (a driver's ray can slip between hull parts), and holds a candidate state
for 0.4 s before publishing so walking the gangplank doesn't strobe the HUD.

## Three things the game had but never showed the player

These fell out of the state work and are the most valuable part of the job:

1. **Station bonuses.** `RoleServer` has granted them since Job #034 — engineer −30% fuel burn, driver
   +15% turn authority, gunner +18% turret speed, mechanic +2.5 hull HP/s, medic +3 crew HP/s — and in
   every build since, **nothing told the player any of it was happening.** GAME.md's entire role design
   rests on "manning a station gives a bonus"; a bonus nobody can perceive is not a mechanic. There is
   now a role chip that appears when you man a station and states the effect.
2. **The boat being attacked while you're ashore.** GAME.md names this as core tension — *"the boat sits
   exposed at the dock while you're inland"* — and nothing surfaced it. You'd walk inland, loot, walk
   back, and discover the hull chewed down, with no signal at any point and no reason to turn back
   early. The ASHORE card now carries hull %, distance back, and an **UNDER ATTACK** strip that is
   edge-triggered on hull *dropping* (a boat sitting at 40% untouched is not an emergency; one at 95%
   losing HP every second is).
3. **Whether you can reach the next fuel stop.** The old readout was `NEXT FUEL 1234 studs` — accurate,
   and close to meaningless. It is now a pin on the river progress bar that **turns red when a full tank
   can't reach it.** That is the "conserve or be stranded" decision the whole run is built around.

## Everything else that changed

**New — `sync/ReplicatedStorage/RunUI/`** (game-only; the `UI/` folder is byte-identical across the two
trees by contract, so run-only modules could not live there):
- `HudState.luau` — the state machine, role sub-flags, `onChange` / `bind`
- `RunComponents.luau` — `card` · `gauge` · `statChip` · `riverBar` · `roleChip` · `slot` ·
  `touchButton` · `tray`, all built on `UI/Components`

**New — client screens:** `HealthHud` · `CurrencyHud` · `RiverProgress` · `RoleChip` · `BoatStatusCard` ·
`Boat/TouchControls`

**Rewritten onto the design system:** `HudClient` · `ObjectiveHud` · `InventoryHud` · `DockShopClient` ·
`StagingHint` · `UntieButton` · `ZoneBanner` · `DownedHud` · `RunClient` · `AdminClient` ·
`EnemyHealthBars` · `TeleportGui` · `GunClient` + `WeaponClient` (reticles) · `GameLoading` (palette)

**Deleted:** `GoldHud.local.luau` — merged into `CurrencyHud`. The Gold and Salvage pills were drawn by
two unrelated scripts at hardcoded pixel offsets (`(1,-14,0,14)` and `(1,-14,0,58)`), the second
positioned by having counted the first one's height. They are one laid-out row now.

**Notable smaller changes:**
- `ZoneDefs.luau` extracted from `ZoneServer` — the river bar needs the zone list, and the alternative
  was a second hand-maintained copy. Zone banner colours moved onto the palette (they were a raw cyan
  `Color3.fromRGB(90,200,230)` that appears nowhere in §4).
- **The hotbar hides while you're in a control seat.** `WeaponClient`, `MeleeClient`, `WeaponServer` and
  `MeleeServer` all already refuse to fire from the DriverSeat or GunSeat — the bar was offering four
  buttons that provably did nothing, and on a phone it sat exactly where the driver's steer thumb needs
  to be.
- **Objectives default collapsed** to a `OBJECTIVES 2/4` tab (§6.11: heavy panels default collapsed
  during play). They also stopped redrawing all four rows on `RenderStepped`.
- **Enemy health bars hide at full health** — twenty untouched crocodiles were twenty green rectangles
  carrying no information.
- **The results panel is built once** at start-up instead of inside the `RunEnded` handler, which leaked
  a whole panel tree per fire and could stack two.
- **Roblox's core health bar is off for good.** `IntroHudGate` used to switch it back on when the intro
  ended, and `GameLoading` restored it on load-finish; both now leave it off.

## Mobile touch drive controls

`Boat/TouchControls.local.luau`. Two-thumb button clusters — steer `◀ ▶` bottom-left, throttle `▲ ▼`
bottom-right — scale-based, safe-area aware, shown only on touch devices and only while seated in the
DriverSeat.

**Answering the open question in `Planned/mobile-boat-controls.md` ("buttons vs joystick"): buttons.**
`VehicleSeat.Steer` is tri-state `-1 | 0 | 1` (roblox-physics §8), so a joystick's analogue precision
quantises to the same three values while being materially harder to hit — a joystick needs the thumb to
find and hold a floating origin, and the driver is watching the river.

Writes `SteerFloat`/`ThrottleFloat` at `RenderPriority.Input + 1`, so our value stands at the end of the
frame while a button is held, and a PC player who never touches them keeps their keys. **No new remote** —
this is the same replicated seat property the keyboard drives, so server authority is unchanged.

## What the playtest caught

Four real defects, all fixed and re-verified:

1. **`VehicleSeat.HeadsUpDisplay`** — Roblox's own "Speed 0" readout was sitting between our fuel and
   hull gauges, in Roblox's font. Now `false`. (Its number is studs/s, which means nothing to a player.)
2. **Role chip type scale** — measured in Studio: the labels capped at 14 px inside a 76 px card and
   read as a footnote. The width was never the problem ("DRIVER" measured 44 px in a 160 px box); the
   type scale was. Now h2 / body.
3. **DOWNED overlay layered *into* an open panel** — both were `DisplayOrder = 20`, so the shop's scrim
   sat over the red vignette and its rows showed through the card. Downed is 30 now, results is 70.
4. **The results screen appeared stacked on an open Trading Post.** Added
   `Components.closeAllPanels()` — an explicit call, deliberately *not* automatic close-on-open, which
   would have silently changed how the lobby's four panels behave. Called when you go down and when the
   run ends.

### Second playtest round (user-driven)

Five more, all fixed and re-verified:

5. **The staging card floated at `y = 0.12`** — the middle of the view, over the wreck and over whoever
   you were walking towards. A banner reading as an obstacle. Pinned to the top (`0.02`) with the rest of
   the chrome. Safe by construction rather than luck: this card only exists *before* `RunStarted` and the
   river bar only *after* it, so the two can never share the top-centre.
6. **"What is that 3?"** — the bandage chip was an icon we haven't sourced yet plus a bare number, so it
   was unreadable. `statChip` takes an optional label now: it reads **BANDAGES 3**. The health bar went
   the same way — **HEALTH 100**, not `100`, which also makes it consistent with the `FUEL 95%` /
   `BOAT 100%` gauges directly below that it used to be the odd one out against.
7. **The ammo chip showed arithmetic.** The boat tracks turret ammo in *two* places — `Ammo` is crates on
   the deck, `Rounds` is what's loaded — and `GunServer` silently spends a crate for 12 rounds when the
   turret runs dry. The chip printed `3+0`, then `2+11` after one shot. It now shows **one number: total
   shots** (`36` → `35` → …), which is exact (a crate is exactly `TURRET_ROUNDS_PER_CRATE` rounds) and
   decrements by one per shot instead of appearing to jump. The gunner's readout under the reticle keeps
   the breakdown in words, where there's room: `35 SHOTS · 11 RDS + 2 CRATES`.
   `ROUNDS_PER_AMMO` moved out of `GunServer` into `ItemDefs.TURRET_ROUNDS_PER_CRATE` so the HUD isn't
   holding a second hand-copied 12.
8. **🐛 REAL BUG — the empty turret still "fired."** `GunServer` correctly refuses a shot with no rounds
   and no crates (`:167-169`), but `GunClient` called `drawTracer()` unconditionally — so an empty turret
   looked and sounded exactly like a firing one, and you could keep shooting and wonder why nothing died.
   The handheld path already got this right; only the turret didn't. Empty now means: no remote call, no
   tracer, a dry click, a red reticle pulse, and `NO AMMO — LOAD CRATES ON THE DECK` under the crosshair.
9. **Handheld guns flashed red on empty but stayed silent.** A silent trigger pull is indistinguishable
   from an input that never registered — which on a phone is the likelier explanation a player reaches
   for. Both paths play `emptyClick` now.

**One new sound to source: `emptyClick`** (dry trigger click, ~0.2 s). We had nothing suitable — the
closest was `failed_or_not_allowed`, which is a UI buzz and reads wrong on a weapon. Added to
`ASSETS.md` §5.3 and the registry, so the placeholder count is **16 icons + 6 sounds**.

Also added `Components.button.setMuted()`: unaffordable shop rows were the same green as affordable
ones. Colour could not be set from outside (the component repaints to its variant on MouseLeave, so an
external tint reverts on first hover) and `setEnabled(false)` sets `Active = false`, which stops
`Activated` firing — killing the `flashFail` + `fail` cue and leaving a dead button with no explanation.
`setMuted` desaturates through the component's own base colour, so it survives hover and stays tappable.

## Verification

- ✅ **Studio Play, full loop** — crash site → board → untie → ride → ashore → dock shop → downed →
  results. Screenshots taken of every state and overlay. **No errors or warnings** in the output beyond
  the two intentional placeholder notices.
- ✅ `grep -rn "Enum.Font.Gotham" sync/` → **empty**.
- ✅ `grep -rn "Color3.(fromRGB|new)" sync/StarterPlayer sync/ReplicatedFirst` → only `GameLoading`
  (documented exception, below) and `IntroFade` (true black, on purpose — it's the crash blackout, and a
  tinted "dark jungle" fade would read as a dimmed scene rather than unconsciousness).
- ✅ `diff -r` between the two `UI/` folders → **silent**. `AdminClient` and `TeleportGui` copies match too.
- ✅ `tools/luau-analyze.sh` → **clean** on the game tree. The lobby tree reports 4 diagnostics, all
  pre-existing in files this job never touched (`PilotIdle` ×3, `InventoryService` ×1).

**`GameLoading.local.luau` is the one file allowed literal colours and fonts** — and not by oversight.
It runs from `ReplicatedFirst`, whose whole purpose is to execute before the rest of the game
replicates; `require(ReplicatedStorage.UI.Theme)` there would `WaitForChild` on a folder that hasn't
arrived and block the loading screen behind the very replication it exists to hide. Its values are
hand-copied from `Theme` with a header note saying so.

---

## ⏳ Outstanding — two things

### 1. The asset batch (user is sourcing)

**Nothing is broken while these are missing.** Every key exists with an empty id, every call site is
wired, and both a fallback and a Studio nag are in place. Full sourcing tables with search terms:
**`ASSETS.md` §5.2 (icons) and §5.3 (sounds)**; also recorded in the shared registry.

- **16 icons** (12 required, 4 optional). Flaticon, **same author as the §1.9 set**. Each renders a
  semantically-near stand-in via `Theme.iconFallback` until its id lands.
- **6 sounds** (`lowFuel`, `lowHull`, `downed`, `revived`, `runLost`, `emptyClick`). Pixabay. `UISound`
  skips an empty id silently; an *unknown* key still warns loudly.
- **4 reuses awaiting the user's OK** — `item_drop`, `player_attacked`, `level_completed` (filed under
  Defender) and `battle_starts` (jungle). Wired and working; swap for Jungle-specific uploads on request.

`Theme.reportPendingIcons()` / `reportPendingSounds()` print what's outstanding on every Studio start —
verified firing in the playtest. **When an id lands, update BOTH copies of `Theme.luau`.**

### 2. Mobile device pass — NOT DONE

Everything is scale-based, safe-area aware, and thumb-floored (44 px controls, 58 px touch buttons, 40 px
panel close), and the constraints were sized for it. But **§6.10's hard rule is "test every GUI on a
phone", and that has not happened** — Studio Play on desktop is not that test. The touch controls in
particular have never been touched by a thumb.

Logged as **`findings/0004`**: Roblox's default VehicleSeat touch D-pad has no documented toggle and may
still draw alongside ours on a real device. `HeadsUpDisplay` is off, but the D-pad is a separate thing.

Also logged: **`findings/0005`** — the lobby place still has Gotham in `LobbyLoading` (same
ReplicatedFirst excuse as `GameLoading`, so it wants the same hand-copied-values treatment) and in
`RankServer` (server-built GUI labels, which *can* require Theme). Out of scope here; this job was the
game place.

## Corrections to the plan

- The plan said this job would close todos **0001, 0010 and 0011**. It closes **none of them**: 0001 and
  0010 were already marked resolved (Jobs 030 and 055), and 0011 is a *billboard over each player's head
  showing the role their skills suit* — genuinely different from the role chip, which shows your own
  current station. **0011 stays open.**
- `Planned/P7` is **partly** delivered, not fully: the HUD and results half is done, **leaderboards are
  untouched** and the file has been re-flagged for that. `Planned/mobile-boat-controls.md` is fully
  delivered.

---

## Files

### New (9)
| File | |
|---|---|
| `sync/ReplicatedStorage/RunUI/HudState.luau` | the three-state controller |
| `sync/ReplicatedStorage/RunUI/RunComponents.luau` | run-only builders |
| `sync/ReplicatedStorage/World/ZoneDefs.luau` | zone list, shared with the client |
| `sync/StarterPlayer/StarterPlayerScripts/UI/CurrencyHud.local.luau` | Gold + Salvage chips |
| `sync/StarterPlayer/StarterPlayerScripts/UI/HealthHud.local.luau` | health bar, vignette, bandages |
| `sync/StarterPlayer/StarterPlayerScripts/UI/RiverProgress.local.luau` | river bar |
| `sync/StarterPlayer/StarterPlayerScripts/UI/RoleChip.local.luau` | station bonus indicator |
| `sync/StarterPlayer/StarterPlayerScripts/UI/BoatStatusCard.local.luau` | ASHORE boat status |
| `sync/StarterPlayer/StarterPlayerScripts/Boat/TouchControls.local.luau` | touch steer + throttle |

### Deleted (1)
`sync/StarterPlayer/StarterPlayerScripts/UI/GoldHud.local.luau` → merged into `CurrencyHud`

### Modified — all auto-synced (`sync/` and `lobby/sync/` are both Rojo trees)
`UI/{Theme,Components,UISound}.luau` **×2 trees** · `UI/AdminClient` **×2 trees** ·
`UI/TeleportGui` **×2 trees** · `ReplicatedFirst/GameLoading` · `ServerScriptService/Boat/BoatServer` ·
`ServerScriptService/World/{ZoneServer,RampTest}` · `ServerScriptService/Excursion/ExcursionServer` ·
`Combat/{GunClient,WeaponClient,MeleeClient}` ·
`UI/{HudClient,ObjectiveHud,InventoryHud,DockShopClient,StagingHint,UntieButton,ZoneBanner,DownedHud,RunClient,EnemyHealthBars,IntroHudGate,IntroFade}`

### Docs
`ASSETS.md` (§5.2, §5.3) · `Planned/P7-hud-scoring-leaderboards.md` ·
`Planned/mobile-boat-controls.md` · `findings/0004`, `findings/0005` ·
`roblox.workspace/Assets/registry/{images,audio}.md`

**No manual-copy steps.** Everything is under auto-synced paths; no place-file edits are required.
