# Final Summary — Job #023: In-run Salvage + dock shop

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Design source: Job #020 §3.
**Game-only** (docks + runs live in the game place).

## What was built
An in-run **Salvage** currency (soft, resets each run, never persisted) + a **dock shop** to spend it.

### Salvage (per-player attribute `Salvage`)
- **Distance drip:** ~1 per 60 studs travelled (~300 over an 18k run), awarded to all crew.
- **Loot:** grabbing a camp crate awards Salvage (resource/ammo +40, weapon +80); a gold nugget also +30.
- **Reset to 0 on `RunStarted`** (never carries between runs / into the profile).

### Shop = a village TRADING POST (moved off the pier per user feedback)
The pier is just where you moor; the shop is a **visible TRADING POST stall** (wooden counter, posts, red
awning, big floating "TRADING POST" sign) **inland in the landing-site village**, reached on foot after
tying up. A "Trade" ProximityPrompt on the counter opens the panel. Buys go through a server RemoteFunction:
bandage 50 (`Bandages+1`) · fuel 120 (`Gasoline+1`) · ammo 90 (`Ammo+1`) · repair 150 (`Metal+1`) ·
pistol 400 · shotgun 750 (`InventoryService.grant`). Resource buys respect `CargoMax`.
Remote renamed `OpenDockShop` → `OpenShop`; panel titled "TRADING POST".

### Files (all `sync/`)
- **New:** `ReplicatedStorage/Economy/ShopDefs.luau` (catalog); `ServerScriptService/Economy/SalvageServer.server.luau`
  (remotes + reset + drip + buy handler); `StarterPlayer/StarterPlayerScripts/UI/DockShopClient.local.luau`
  (Salvage pill + shop panel).
- **Edit:** `Excursion/ExcursionServer.server.luau` (award Salvage on loot + nugget; **build the village
  TRADING POST stall + Trade prompt**); `World/DockServer.server.luau` (pier prompt removed — mooring only).

## Verified (live in Studio)
- [x] Analyzer-clean (all files).
- [x] **Reset:** Salvage 500 → 0 on `RunStarted`.
- [x] **Shop (real server RF):** from 1000 Salvage — bandage(50)→Bandages 2→3, fuel(120)→Gasoline 0→1,
      ammo(90)→Ammo 0→1, pistol(400)→granted; **Salvage 1000→340** (exact); **shotgun(750)→"poor"** rejected.
- [x] **UI:** DOCK SHOP panel + both HUD pills (GOLD / SALVAGE), affordable items green, unaffordable greyed
      (Pistol/Shotgun at 340), CARGO bar reflected the buys (screenshot).

## Notes / follow-ups
- **Not committed.**
- **Drip + loot awards** are construction-verified (they set the `Salvage` attribute; drip reads
  `BoatDistance`) — not separately walked live (needs the boat to travel / a camp raid).
- Cargo-full rejection is construction-verified (buy checks `cargoTotal >= CargoMax`).
- The test session had polluted boat state from earlier testing (I normalized cargo for the buy test).
- Deferred: dock-shop art, a sell side, per-item stock, run objectives paying Salvage.
- Remaining jobs: **#024** (skill tree — pending your skill-list review), **#027** (Robux), **#028** (retention).
