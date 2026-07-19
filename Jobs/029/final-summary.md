# Final Summary — Job #029: Wire crew-skill effects + Armored Boat weapon bonus

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Depends on #024 + #027.

## What was built
The 5 crew skills (bought in #024, exposed as `Skill<Name>` player attributes at run start) now have real
in-game effects, and the Armored Boat's weapon bonus is live.

| Skill / item | System (edit) | Effect (per level / value) |
|---|---|---|
| Field Repair (`SkillRepair`) | `Cargo/CargoServer` repair station | HP/metal × `(1 + 0.05·L)` (L10: 25→37.5) |
| Fuel Handling (`SkillRefuel`) | `Cargo/CargoServer` fuel station | fuel/gas × `(1 + 0.05·L)` (L10: 40→60) |
| Combat Medic (`SkillMedic`) | `Combat/PlayerCombat` revive | hold × `(1 − 0.04·L)` via `PromptButtonHoldBegan` (L10: 3→1.8s, min 0.6) + revived HP `+2.5·L` (L10: 50→75) |
| Gun Discipline (`SkillGun`) | `Combat/WeaponServer` + `Combat/GunServer` | fire interval × `0.965^L` (L10: 0.70×) — **"reload" has no mechanic → fire rate** |
| Scavenger's Instinct (`SkillScavenge`) | `Excursion/ExcursionServer` | loot Salvage × `(1 + 0.03·L)` (L10: 1.30×) |
| **Armored Boat** (`GunDamageMul`) | `Combat/GunServer` | mounted-gun damage × `GunDamageMul` (Armored = ×1.2 → 60→72) |

`SkillDefs` (both trees): Gun Discipline blurb corrected to "Shoot faster (guns & turret)" — honest, since
there's no reload mechanic.

## Verified (live in Studio)
- [x] Analyzer-clean (all edited files).
- [x] **Inputs + formulas confirmed live @ L10 + Armored Boat:** `SkillRepair/Refuel/Medic/Gun/Scavenge=10`
      set at run start, `GunDamageMul=1.2`; derived values exact — repair 37.5, fuel 60, fire 0.70×, turret
      dmg 72, revive hold 1.8s, revive HP 75, salvage 1.30×.
- [~] **The actual triggers** (holding a station / shooting / reviving) weren't fired headlessly — they read
      the same confirmed attributes with the same formulas (identical pattern to the live-verified #024/#027),
      so they'll show in a live playtest.

## Notes / follow-ups
- **Not committed.** Test account reset to clean.
- Scavenger nugget-spawn chance is world-level (not per-player) → left as loot-Salvage bonus only; the nugget
  grab still gives a flat +30 Salvage (not scaled).
- Revive-speed uses `PromptButtonHoldBegan` to set `HoldDuration` per reviver (ProximityPrompt can't vary it
  per-player otherwise).
- Every purchasable upgrade in the economy now has a real effect. Open threads: `todo/` UX items
  (untie button, visual upgrade stations, admin panel) and P11 live-ops.
