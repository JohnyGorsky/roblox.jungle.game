# Job #025 — Implementation plan: Boat modules (visible one-time Gold unlocks)

**Project**: `roblox.jungle` · POC · Design source: Job #020 §5 · Depends on #021 (profile) + #022 (Gold).

## Model
- **Modules = one-time Gold unlocks** that add a **visible boat part + a capability** (the "split model":
  modules unlock, skills tune later in #024).
- **Bought in the LOBBY** (persistent meta sink), stored in `profile.modules` (a `{[id]=true}` set).
- **Applied to the shared boat IN-GAME** as the **union of the crew's** owned modules (any owner → the
  boat gets it). Co-op-friendly for POC; can switch to leader-only later.

## Catalog (Job 020 §5 prices)
| id | Name | Gold | Visible part | POC effect |
|----|------|------|--------------|-----------|
| `motor2` | Twin Motors Mount | 150 | 2nd engine block (stern) | `ThrustMul=1.25` (BoatServer reads it) |
| `hullkit` | Reinforced Hull | 200 | armor plates | `MaxHP/HP → 150` |
| `searchlight` | Searchlight Rig | 120 | mast + SpotLight | real light (night) |
| `fueltank` | Extended Fuel Tank | 150 | tank drum | `MaxFuel/Fuel → 150` |
| `trailer` | Cargo Trailer | 180 | welded barge behind hull | `CargoMax += 10` |
| `gunupgrade`| Mounted Gun Upgrade | 200 | bigger barrel at turret | `GunTier=2` attr (combat reads later) |

## Files
**Both trees** (`sync/` + `lobby/sync/`, byte-identical via copy):
- `ReplicatedStorage/Progression/ModuleDefs.luau` — catalog (id/name/cost/blurb/order). NEW.
- `ReplicatedStorage/Progression/ProfileConfig.luau` — add `modules = {}` to `default()` + `migrate()`. EDIT.

**Lobby only:**
- `ServerScriptService/Progression/ModulesServer.server.luau` — `RemoteFunction "BoatModules"`:
  `list` → `{gold, owned}`; `buy id` → validate + `trySpendGold` + set `profile.modules[id]` →
  `{ok, gold, owned}` (or `{error}`).
- `StarterPlayer/StarterPlayerScripts/UI/ModulesShop.local.luau` — a "🛠 Boat Upgrades" toggle button +
  panel: one row per module (name, cost, Buy / OWNED / can't-afford). Minimal, mobile-safe.

**Game only:**
- `ServerScriptService/Boat/BoatModules.server.luau` — on `RunStarted`, apply the crew-union modules to the
  boat (weld Massless/non-colliding visible parts to the hull + set the attributes/effects above).
- `ServerScriptService/Boat/BoatServer.server.luau` — EDIT: thrust force `* (boat.ThrustMul or 1)`
  (1-line; also future-proofs skill tuning).

## Verification (Studio)
- Analyzer-clean (both trees).
- Lobby: buy a module → Gold drops by its cost (GoldHud), row shows OWNED, persists across rejoin;
  can't buy when too poor or already owned.
- Game: with a module owned, the boat shows the part on run start + the effect applies (e.g. `MaxFuel=150`,
  `MaxHP=150`, `ThrustMul=1.25`, SpotLight present). Verify via attributes + screenshot.
- (Verify via shared Instances/DataStore per the `roblox-studio` MCP testing notes.)

## Out of scope
Skill tuning of these stats (#024); full gun-tier combat wiring; rope-swing trailer physics (welded barge
for POC); Robux Armored Boat (#027).
