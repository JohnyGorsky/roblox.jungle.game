# Implementation Plan — Job #015: Weapons Loadout (sword default + guns earned at camps) + 4-slot inventory

**Project**: `roblox.jungle`
**Created**: 2026-07-18
**Status**: Planning (awaiting go-ahead)

Turns the always-on handheld into a real loadout: **sword = default fallback**, **guns = scarce camp
loot**, on top of a new **4-slot inventory** (one item active at a time) and a **Dead-Rails carry mode**
for hauling gasoline/metal back to the trailer.

## Decisions locked (via wizard, 2026-07-18)

- **Inventory:** custom **4-slot** inventory, **one item active at a time** (sword / pistol / shotgun /
  small items). Built **custom, attribute-driven** (no Roblox Tools/Backpack) + a **custom mobile hotbar UI**.
- **Carry/drag (Dead-Rails):** big objects (gasoline canister, metal) are **carried** without using a
  slot; **hands full ⇒ no weapon/item use** while carrying. (Reuses the existing `Busy` attribute.)
- **Sword:** default from spawn, **pure fallback** — short range, modest damage/cooldown.
- **Guns:** everyone **starts sword-only**; a **scarce weapon crate** at camps grants a pistol/shotgun
  into a slot. Guns are a **top-tier reward**.
- **Ammo:** **per-weapon-type, per-player** (Pistol ammo, Shotgun ammo), looted/refilled at camps. The
  **mounted gun (#014) keeps the shared boat pool** (`Boat.Rounds`/`Boat.Ammo`) — untouched.
- **Persistence:** looted guns + inventory **kept for the whole run** — stored on the **Player** (like
  `Bandages`), so death/revive doesn't strip them.
- **Reconcile:** handheld free-aim (#006) → **the looted pistol** (gated); mounted gun (#014) → gunner's;
  sword → fallback. One "what am I holding?" model.

## How today's code works (from the code map)

- Handheld: `sync/ServerScriptService/Combat/WeaponServer.server.luau` + `.../StarterPlayerScripts/Combat/WeaponClient.local.luau`.
  Always-on LocalScript, no equip; server re-raycasts, `WEAPON_DAMAGE=20`, ammo from **boat-global**
  `Boat.Rounds`/`Boat.Ammo`; gates on DriverSeat/GunSeat/`Busy` via `canShoot`. Remote `FireWeapon` on `ReplicatedStorage`.
- Mounted gun: `.../Combat/GunServer.server.luau` + `GunClient.local.luau` — seat-gated, boat ammo pool. **Leave as-is.**
- Cargo/stations: `sync/ServerScriptService/Cargo/CargoServer.server.luau` — cargo = **Boat attributes**
  (`Gasoline`/`Metal`/`Ammo`/`Rounds`/`CargoMax=10`); welded `CargoDeck`; Fuel/Repair `ProximityPrompt` stations.
- Camps/loot: `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` — `buildCampAt` places
  `LootCrate` parts (attr `Resource` + `LootPrompt`); `pickupLoot` **welds a carried part, sets
  `player.Busy=true`** (Dead-Rails carry **already exists**); `deposit` prompt on hull increments the boat
  cargo attribute (respects `CargoMax`). Guards tagged `"CampGuard"`.
- Hits: both weapon servers use `enemyFrom(inst)` (walk-up accepting `"Enemy"` **or** `"CampGuard"` tags)
  and damage by decrementing the model's `HP` attribute.
- No Tool/Backpack/StarterPack/inventory UI exists today. State is attribute-driven; HUD =
  `.../UI/HudClient.local.luau` (reads boat attrs each frame).

## Plan (server-authoritative throughout)

### 1. Inventory core (new)
- **`sync/ReplicatedStorage/Inventory/ItemDefs.luau`** (ModuleScript, `--!strict`) — item catalog:
  `Sword`, `Pistol`, `Shotgun` (+ future small items). Per item: `Kind` (Melee/Gun), display name, icon,
  `AmmoType` (guns), and whether it's droppable. `SLOT_COUNT = 4`.
- **`sync/ServerScriptService/Inventory/InventoryServer.server.luau`** — authoritative per-player
  inventory stored on **Player attributes** (`Slot1..Slot4` item ids, `ActiveSlot` index, `AmmoPistol`,
  `AmmoShotgun`). Seeds **Slot1 = Sword** on join/respawn (persist rest for the run). API via one remote:
  - **`InventoryCmd`** (RemoteEvent) — `equip(slotIndex)`, `drop(slotIndex)`. Validates ownership/range.
  - `grantItem(player, itemId)` (server-internal) — puts a looted gun into the first free slot (or refuses
    if full → player must drop something); used by the weapon crate.
  - Exposes an `ActiveItem` character/player attribute the weapon clients & servers read.

### 2. Sword (new — the default melee)
- **`sync/ServerScriptService/Combat/MeleeServer.server.luau`** — `SwordSwing` (RemoteEvent): validate
  active item == `Sword`, not `Busy`, rate-limit (~0.6s), short-range **arc/sphere hit** (~9 studs, small
  cone) from HRP, damage via the shared `enemyFrom`/HP convention (~15, pure fallback). Server-authoritative
  (client never asserts a hit).
- **`sync/StarterPlayer/StarterPlayerScripts/Combat/MeleeClient.local.luau`** — when Sword is active,
  tap/click (mobile button) → `SwordSwing:FireServer()`; simple swing feedback (anim later = P9).
- Greybox sword visual: a welded part on the character while Sword is active (no Roblox Tool).

### 3. Gate the pistol (#006 → looted, active-slot-driven)
- **WeaponServer** `canShoot`: also require the shooter's `ActiveItem == "Pistol"` (authoritative). Ammo
  now drawn from **per-player `AmmoPistol`**, not the boat pool.
- **WeaponClient** `localCanShoot` + crosshair: only when `ActiveItem == "Pistol"`. Add a client
  "out of ammo / empty" cue (fixes a `greybox-polish-perf` item too).

### 4. Shotgun (new gun)
- Reuse WeaponServer with a per-weapon config table (damage/range/spread/ammoType). Shotgun = **multi-ray
  spread**, own `AmmoShotgun`, shorter range, higher close damage. Same `FireWeapon` remote carrying the
  active-weapon id, or a sibling `FireShotgun` — decide in build (lean: one remote + server reads active item).

### 5. Per-weapon-type ammo
- Ammo counts live per-player: `AmmoPistol`, `AmmoShotgun` (Player attributes, persist for the run).
- **Ammo crates at camps** grant a **specific ammo type** (extend the loot crate `Resource`/`Kind`).
- Mounted gun (#014) + `Boat.Rounds`/`Boat.Ammo` **unchanged**. HUD shows the **active weapon's** ammo.

### 6. Weapon crate at camps (scarce)
- Extend `ExcursionServer.buildCampAt` + `pickupLoot`: add crate attribute **`Kind`** = `"Resource"` |
  `"Weapon"` | `"Ammo"`.
  - `Kind == "Weapon"` → on trigger call `InventoryServer.grantItem` (pistol/shotgun) — **no carry, no
    `Busy`**; refuse if inventory full (prompt "inventory full").
  - `Kind == "Resource"` (canister/metal) → existing carry path (weld + `Busy`).
  - `Kind == "Ammo"` → grant ammo of a type directly.
- **Scarcity:** weapon crates only at **deeper/rarer camps**, low spawn chance (tune numbers in build).

### 7. Hand-carry canister/metal → trailer (mostly reuse)
- Place standalone **canister/metal** loot at camps using the existing carry pattern (`pickupLoot` +
  `deposit`). Confirm deposit increments `Boat.Gasoline`/`Boat.Metal` under `CargoMax`. Optional: WalkSpeed
  slow while carrying (tune).

### 8. Carry-mode blocks item use (extend existing `Busy`)
- Weapons already refuse while `Busy`. Ensure **MeleeServer** also refuses while `Busy`, and the hotbar
  disables activation while carrying. (Dead-Rails "hands full" = the `Busy` attribute — reuse, don't reinvent.)

### 9. Hotbar UI (mobile-first, custom)
- **`sync/StarterPlayer/StarterPlayerScripts/UI/InventoryHud.local.luau`** — 4 slot buttons (scale-based
  `UDim2`, safe-area aware, touch to equip), active-slot highlight, per-weapon **ammo readout** on the
  active gun, and a **carry indicator**. Reads Player attributes; equip → `InventoryCmd`. Coexists with
  `HudClient` (tuck cargo/ammo readout to avoid the VehicleSeat gauge overlap — a `greybox-polish` item).

### 10. Persistence across death/revive
- All inventory + ammo state on the **Player** (not the character), seeded on join, **re-applied on
  `CharacterAdded`** (re-weld sword if active). Survives `PlayerCombat` bleedout/respawn within a run.

## Files

**New:** `ReplicatedStorage/Inventory/ItemDefs.luau`, `ServerScriptService/Inventory/InventoryServer.server.luau`,
`ServerScriptService/Combat/MeleeServer.server.luau`, `StarterPlayerScripts/Combat/MeleeClient.local.luau`,
`StarterPlayerScripts/UI/InventoryHud.local.luau`.
**Edit:** `Combat/WeaponServer.server.luau` (gate on active Pistol + per-player ammo, shotgun config),
`Combat/WeaponClient.local.luau` (active-item gate + empty cue), `Excursion/ExcursionServer.server.luau`
(crate `Kind` branch + weapon/ammo grants + canister/metal loot), `UI/HudClient.local.luau` (ammo/layout tidy).
**Untouched:** `Combat/GunServer/GunClient` (#014), `Cargo/CargoServer` core (boat pool stays for the turret).

## Verification (luau-analyze + live Studio MCP playtest)
- `bash tools/luau-analyze.sh` clean on every edited/new file.
- Spawn = **sword only**; sword hits an enemy/CampGuard at short range, not at distance.
- **No pistol fire** until a weapon crate is looted; crate → pistol in a slot; equip switches active item;
  firing consumes **per-weapon ammo**; shotgun spreads.
- Carry a canister → **can't use weapons** → **deposit adds to trailer cargo** (under `CargoMax`).
- Guns + ammo **persist** through downed → revive within a run.
- Hotbar UI works via **touch** (mobile), highlights active slot, shows active-weapon ammo.

## Out of scope / deferred
- Swing/gun animations (P9), gun tiers beyond pistol/shotgun, gamepass slot expansion, real sword/gun art,
  cross-run persistence (DataStore) — this is within-run only. Carry WalkSpeed penalty tuning.

## Open (tune during build, not blockers)
- Sword damage/range/cooldown; per-gun ammo capacities & shotgun spread; weapon-crate spawn rate & which
  camps drop pistol vs shotgun.
