# Job #029 — Implementation plan: wire crew-skill effects + Armored Boat weapon bonus

**Project**: `roblox.jungle` · POC · Depends on #024 (skills expose `Skill<Name>` attrs) + #027 (`GunDamageMul`).
Game-only systems (except the shared `SkillDefs` blurb tweak).

## Hooks (read the acting player's `Skill<Name>` attribute, set at run start by BoatModules)
| Skill | Attr | System | Effect |
|-------|------|--------|--------|
| Field Repair | `SkillRepair` | CargoServer repair station | HP/metal `× (1 + 0.05·L)` for the repairer |
| Fuel Handling | `SkillRefuel` | CargoServer fuel station | fuel/gas `× (1 + 0.05·L)` for the refueller |
| Combat Medic | `SkillMedic` | PlayerCombat revive | revive hold `× (1 − 0.04·L)` (per-reviver via `PromptButtonHoldBegan`) + revived HP `+2.5·L` |
| Gun Discipline | `SkillGun` | WeaponServer + GunServer | fire interval `× 0.965^L` (shooter's) — **"reload" has no mechanic, so this is fire rate** |
| Scavenger's Instinct | `SkillScavenge` | ExcursionServer | loot Salvage `× (1 + 0.03·L)` |

## Armored Boat (Job 027)
- GunServer mounted damage `× (boat.GunDamageMul or 1)` → +20% with the Armored Boat.

## Files (edits)
- `Cargo/CargoServer.server.luau` — station Triggered callbacks take the player; scale by SkillRepair/SkillRefuel.
- `Combat/PlayerCombat.server.luau` — `PromptButtonHoldBegan` sets per-reviver hold; `revive(reviver)` scales HP.
- `Combat/WeaponServer.server.luau` — fire-interval gate `× 0.965^SkillGun`.
- `Combat/GunServer.server.luau` — `FIRE_INTERVAL × 0.965^gunnerSkillGun`; `GUN_DAMAGE × GunDamageMul`.
- `Excursion/ExcursionServer.server.luau` — `awardSalvage` scales by SkillScavenge.
- `ReplicatedStorage/Progression/SkillDefs.luau` (both trees) — Gun Discipline blurb → "faster fire rate".

## Verification (Studio)
- Analyzer-clean.
- Seed skills + run: repair HP/metal, fuel/gas, weapon+turret fire interval, loot Salvage all scale by level;
  revive hold shortens for a skilled medic + revived HP higher; turret damage ×1.2 with Armored Boat.
  Verify via attributes / measured values.

## Out of scope
Scavenger nugget-spawn chance (world-level, not per-player — loot-Salvage bonus only); a real magazine/reload
mechanic; per-level UI display of live effects.
