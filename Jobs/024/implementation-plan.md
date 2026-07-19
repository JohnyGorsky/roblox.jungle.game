# Job #024 — Implementation plan: Skill tree (10 skills, 1→10, Gold-bought)

**Project**: `roblox.jungle` · POC · Design source: Job #020 §4 · Depends on #021 (profile) + #022 (Gold) + #025 (boat applier).

## Model
- Per-player **skills** stored in `profile.skills` = `{ [id] = level (1..10) }`.
- **Bought in the lobby** with Gold; cost ladder `cost(n) = round(4 · 1.3^(n-1))` → 4,5,7,9,11,15,19,25,33,42
  (≈171 to max one skill).
- **Applied to the boat in-game** alongside modules ("modules unlock, skills tune"): boat-stat skills use the
  **max crew level**; crew skills are per-player.

## The 10 skills (Job 020 §4)
**Boat (wired now — attribute effects):** Twin Motors (+3%/lv speed → `ThrustMul`), Rudder Tuning (+2.5%/lv
→ `TurnMul`), Hull Plating (+5 HP/lv → `MaxHP`), Diesel Efficiency (×0.975/lv fuel burn → `FuelBurnMul`),
Cargo Rigging (+~0.5/lv → `CargoMax`).
**Crew (persist + expose now, deep-wire later):** Field Repair, Fuel Handling, Combat Medic, Gun Discipline,
Scavenger's Instinct — each sets a `Skill<Name>` player attribute their system can read in a later pass.

## Files
**Both trees:**
- `ReplicatedStorage/Progression/SkillDefs.luau` — catalog (id/name/group/per-level/blurb), `cost(level)`,
  `cumulative`, `MAX_LEVEL`. NEW.
- `ReplicatedStorage/Progression/ProfileConfig.luau` — add `skills = {}` to default + migrate. EDIT.

**Lobby:**
- `ServerScriptService/Progression/SkillServer.server.luau` — `RemoteFunction "Skills"`: `list` /
  `buy id` (next level, `cost`, `trySpendGold`, `profile.skills[id]=lvl`). NEW.
- `StarterPlayer/StarterPlayerScripts/UI/SkillShop.local.luau` — "SKILLS" button + panel (name, Lv X/10,
  next cost / MAX, Buy). NEW.

**Game:**
- `ServerScriptService/Boat/BoatModules.server.luau` — EXTEND `apply()`: after modules, apply boat-skill
  effects (max crew level, combined on top of modules) + set per-player crew-skill attributes.
- `ServerScriptService/Boat/BoatServer.server.luau` — EDIT: rudder yaw `* (boat.TurnMul or 1)`; fuel drain
  `* (boat.FuelBurnMul or 1)`.

## Verification (Studio)
- Analyzer-clean (both trees).
- Lobby: buy skill levels → Gold drops per the ladder, level increments, persists; MAX at 10.
- Game (seed skills + start run): boat `ThrustMul`/`TurnMul`/`MaxHP`/`FuelBurnMul`/`CargoMax` reflect the
  levels, combined with modules; crew `Skill<Name>` attributes set. Verify via attributes + Client `InvokeServer`.

## Out of scope
Deep-wiring the 5 crew skills into their systems (repair/refuel/revive/reload/scavenge) — persisted + exposed
now, hooked later. Skill respec/refund. Fancy tree UI (flat list for POC).
