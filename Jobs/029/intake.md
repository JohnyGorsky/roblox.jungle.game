# Job #029: Wire crew-skill effects + Armored Boat weapon bonus

**Project**: `roblox.jungle`
**Created**: 2026-07-19 15:37:30
**Status**: Requirements Gathering (intake)

## Requirements / goal

Make the 5 crew skills actually work. They are bought (Job 024) and exposed as per-player attributes SkillRepair/SkillRefuel/SkillMedic/SkillGun/SkillScavenge (set at run start). Hook them into their systems: Field Repair -> repair-station HP-per-metal (CargoServer); Fuel Handling -> fuel-station fuel-per-gas (CargoServer); Combat Medic -> revive speed + revived HP (PlayerCombat); Gun Discipline -> weapon reload time (WeaponServer/GunServer); Scavenger Instinct -> loot Salvage + gold-nugget chance (ExcursionServer). Also hook the Armored Boat GunDamageMul (Job 027) into mounted-gun damage. Per-level values from Job 020 section 4. POC, server-authoritative.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created (`implementation-plan.md`)
- [x] Implementation completed — 5 crew skills + Armored Boat weapon bonus wired; inputs+formulas confirmed
      live at L10; analyzer-clean
- [x] Final summary + changelog written
