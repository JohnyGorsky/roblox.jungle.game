# Final Summary — Job #024: Skill tree (10 skills, 1→10, Gold-bought)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Design source: Job #020 §4.
Depends on #021 (profile) + #022 (Gold) + #025 (boat applier).

## What was built
A per-player **skill tree** (10 skills × levels 1–10), bought in the lobby with Gold, applied to the
boat/crew in-game ("modules unlock, skills tune"). Skill list confirmed with the user (all 10 as designed).

### Cost ladder
`cost(n) = round(4 · 1.3^(n-1))` → 4,5,7,9,11,15,19,25,33,42 (≈171 to max one skill).

### The 10 skills
**Boat (fully wired — max crew level → boat attribute, combined with modules):**
- Twin Motors +3%/lv → `ThrustMul` · Rudder Tuning +2.5%/lv → `TurnMul` · Hull Plating +5 HP/lv → `MaxHP`
  · Diesel Efficiency ×0.975/lv → `FuelBurnMul` · Cargo Rigging +~0.5/lv → `CargoMax`.

**Crew (persisted + exposed as `Skill<Name>` player attributes; deep-wired later):**
- Field Repair · Fuel Handling · Combat Medic · Gun Discipline · Scavenger's Instinct.

### Files
- **New (both trees):** `ReplicatedStorage/Progression/SkillDefs.luau` (catalog + `cost`/`cumulative`).
- **Edit (both trees):** `ReplicatedStorage/Progression/ProfileConfig.luau` — `skills = {}` in default + migrate.
- **New (lobby):** `ServerScriptService/Progression/SkillServer.server.luau` (`Skills` RF: list/buy);
  `StarterPlayer/StarterPlayerScripts/UI/SkillShop.local.luau` ("SKILLS" button + panel).
- **Edit (game):** `Boat/BoatModules.server.luau` — apply boat-skill effects (max crew level, on top of
  modules) + set crew-skill player attributes; `Boat/BoatServer.server.luau` — rudder `* TurnMul`, fuel
  drain `* FuelBurnMul`.

## Verified (live in Studio)
- [x] Analyzer-clean (both trees).
- [x] **Purchase (lobby, real RF):** refuel 0→1→2 (cost 4+5) → **Gold 100→91**; buying a maxed skill
      (motors L10) → `error=maxed`. Panel shows levels, next-costs, MAX (screenshot).
- [x] **Game application (all boat skills L10):** `ThrustMul=1.3, TurnMul=1.25, MaxHP=150,
      FuelBurnMul=0.776, CargoMax=15` — all exact — plus crew attributes `SkillRepair=5, SkillMedic=3`.
- [x] Combines with modules (multiplicative ThrustMul, additive MaxHP/CargoMax).

## Notes / follow-ups
- **Not committed.** Test account reset to clean.
- **Crew skills (5) are persisted + exposed but not yet deep-wired** into their systems (repair/refuel
  station rates, revive speed, reload, loot/nugget odds) — do that when polishing those systems (read the
  `Skill<Name>` player attributes).
- Boat skills use **max crew level** (shared boat); crew skills are per-player. Same co-op model as modules.
- Deferred: skill respec/refund, a real skill-tree visual (flat list for POC).
- Remaining jobs: **#027** (Robux — needs a published place to fully test purchases), **#028** (retention).
