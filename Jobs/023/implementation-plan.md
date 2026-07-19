# Job #023 — Implementation plan: In-run Salvage + dock shop

**Project**: `roblox.jungle` · POC · Design source: Job #020 §3 · Depends on nothing hard (in-run only).
**Game-only** (docks + the run live in the game place; no lobby copies).

## Salvage (in-run soft currency — resets each run, NOT persisted)
A per-player attribute `Salvage`. Earned two ways (Job 020 §3 — cash rewards the raid loop, not passive driving):
- **Distance drip:** ~1 per 60 studs → ~300 over the 18,000-stud run (awarded to all crew).
- **Loot pickups:** grabbing a camp crate gives Salvage (resource/ammo +40, weapon +80) to the looter.
Reset to 0 on `RunStarted`. Target ~800–1,500 per full aggressive run.

## Dock shop (spend Salvage — Job 020 §3 prices)
A "Dock Shop" ProximityPrompt at each dock opens a client panel; buys go through a server RemoteFunction
(validates Salvage + applies the effect, integrating with existing systems):
| id | Item | Salvage | Effect |
|----|------|--------:|--------|
| bandage | Bandage | 50 | player `Bandages += 1` |
| fuel | Fuel Can | 120 | boat `Gasoline += 1` (cargo, feeds Fuel station) |
| ammo | Ammo Box | 90 | boat `Ammo += 1` (turret) |
| repair | Repair Kit | 150 | boat `Metal += 1` (feeds Repair station) |
| pistol | Pistol | 400 | `InventoryService.grant(plr,"Pistol")` |
| shotgun | Shotgun | 750 | `InventoryService.grant(plr,"Shotgun")` |
Resource buys respect `CargoMax` (reject when the boat cargo is full).

## Files (all in `sync/`)
- `ReplicatedStorage/Economy/ShopDefs.luau` — shop catalog (id/name/cost/blurb/order). NEW.
- `ServerScriptService/Economy/SalvageServer.server.luau` — NEW: creates remotes (`DockShop` RF,
  `OpenDockShop` RE); resets Salvage on `RunStarted`; distance-drip loop; buy handler (cost + cargo checks
  + effects).
- `ServerScriptService/Excursion/ExcursionServer.server.luau` — EDIT: award Salvage on crate loot + nugget.
- `ServerScriptService/World/DockServer.server.luau` — EDIT: add a "Dock Shop" prompt on each dock deck →
  fire `OpenDockShop` to the triggering player.
- `StarterPlayer/StarterPlayerScripts/UI/DockShopClient.local.luau` — NEW: a Salvage HUD pill (reads the
  `Salvage` attribute) + the shop panel (opened by the dock prompt; buy via the RF; auto-closes on run end).

## Verification (Studio)
- Analyzer-clean.
- Salvage drips with distance, jumps on loot, resets on a new run, and does NOT persist across runs.
- Dock prompt opens the shop; buying deducts Salvage and applies the effect (bandage/fuel/ammo/metal/gun);
  rejects when too poor / cargo full; verify via attributes + Client-context `InvokeServer`.

## Out of scope
Real dock-shop art; a "sell" side; per-item stock limits; run objectives paying Salvage.
