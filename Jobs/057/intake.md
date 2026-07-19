# Job #057: Medic role (4th crew role): heal station + revive buffs

**Project**: `roblox.jungle`
**Created**: 2026-07-19 22:15:29
**Status**: Requirements Gathering (intake)

## Requirements / goal

From GAME.md decision (todo 0000): the 4th role is Medic. Presence-based, like the other role stations. (1) CargoServer builds a labelled MEDIC station on the back deck. (2) RoleServer sets boat.StationMedic when manned + passively heals non-downed crew (HP<MaxHP) at MEDIC_REGEN/s (mirrors the repair-station hull regen). (3) PlayerCombat revive buffs while StationMedic: RevivePrompt longer range + slower bleed-out (snapshot at down) + shorter hold (live, stacks with SkillMedic). Distinct from the per-player SkillMedic (they stack). Greybox. Not committed.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
