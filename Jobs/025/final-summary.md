# Final Summary — Job #025: Boat modules (visible one-time Gold unlocks)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Design source: Job #020 §5.
Depends on #021 (profile) + #022 (Gold).

## What was built — the Gold *spend* side ("modules unlock, skills tune")
Six one-time boat modules, **bought in the lobby with Gold**, **persisted in the profile**, and **applied
to the shared boat in-game** as the **union of the crew's** owned modules.

### Catalog (Job 020 §5 prices)
| id | Name | Gold | Visible part | Effect |
|----|------|-----:|--------------|--------|
| motor2 | Twin Motors Mount | 150 | stern engine block | `ThrustMul=1.25` (BoatServer reads it) |
| hullkit | Reinforced Hull | 200 | side armor plates | `MaxHP/HP → 150` |
| searchlight | Searchlight Rig | 120 | bow mast + head | real forward `SpotLight` |
| fueltank | Extended Fuel Tank | 150 | fuel drum | `MaxFuel/Fuel → 150` |
| trailer | Cargo Trailer | 180 | towed barge (welded) | `CargoMax += 10` |
| gunupgrade | Mounted Gun Upgrade | 200 | bigger barrel | `GunTier=2` attr (combat reads later) |

### Files
- **New (both trees):** `ReplicatedStorage/Progression/ModuleDefs.luau` (catalog).
- **Edit (both trees):** `ReplicatedStorage/Progression/ProfileConfig.luau` — `modules = {}` in default +
  migrate.
- **New (lobby):** `ServerScriptService/Progression/ModulesServer.server.luau` (RemoteFunction `BoatModules`:
  `list` / `buy` — validates cost/affordability/ownership, `trySpendGold`, sets `profile.modules[id]`);
  `StarterPlayer/StarterPlayerScripts/UI/ModulesShop.local.luau` ("BOAT UPGRADES" button + panel).
- **New (game):** `ServerScriptService/Boat/BoatModules.server.luau` (applies union of crew modules on
  `RunStarted` — welds massless/non-colliding parts + sets attributes/effects).
- **Edit (game):** `BoatServer.server.luau` — thrust force `* (boat.ThrustMul or 1)` (also future-proofs
  skill tuning).

## Verified (live in Studio)
- [x] Analyzer-clean (both trees).
- [x] **Purchase (lobby, real server RF):** `buy motor2` → Gold **500→350**, `motor2` owned; re-buy →
      `error=owned`; unknown id → `error=unknown`; Gold attribute replicated to 350.
- [x] **Persistence:** after buying + leaving, the DataStore reads back `gold=350, modules.motor2=true`,
      lock released.
- [x] **Apply (game):** with all six owned, the boat gets `MaxHP=150, MaxFuel=150, ThrustMul=1.25,
      CargoMax=20, GunTier=2` **and** all six visible parts incl. a working SpotLight (attributes + part
      query + screenshot).

## Notes / follow-ups
- **Not committed.** Test account reset to a clean default (gold 0, no modules).
- **Co-op ownership = union** (any crew member's module benefits the shared boat). Simple + generous for
  POC; revisit (leader-only?) if it feels exploitable.
- Modules apply **at `RunStarted`** (crew/profiles loaded by then); the boat is base during staging. Fine
  for POC; could apply earlier once profiles are ready if we want the upgraded boat visible at the pier.
- **Trailer** is a welded rigid barge (no rope-swing physics) for POC safety; **gunupgrade** sets
  `GunTier` but combat scaling is wired later.
- Testing note (see `roblox-studio` skill): `execute_luau` runs in a separate VM — verified purchase via a
  **Client**-context `InvokeServer` (real server path) and apply via **DataStore-seeded** profile; Edit
  writes *were* visible in Play (the earlier "split" was leftover locks, not a data split).
- Next: **#026** (Leaderboards + River Score + overhead rank) or **#024** (skill tree — pending your
  skill-list review).
