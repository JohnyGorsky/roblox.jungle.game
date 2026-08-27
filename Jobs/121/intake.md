# Job #121: Endgame garrison: tower grenadiers, ground raiders, boss and a sea gauntlet

**Project**: `roblox.jungle`
**Created**: 2026-08-27 18:22:12
**Status**: ✅ COMPLETE — implemented, verified in Play, closed 2026-08-27 (see final-summary.md)

## Requirements / goal

The extraction end zone is empty of enemies. Add: (1) a surge of sea creatures on the final river approach into the end zone so the last camp's ammo/supply stock matters; (2) one grenadier on each of the three EndBase RangerTower Defender pads; (3) ten ground enemies (random Wolf/Bandit) across the end-zone territory that do NOT all charge at once; (4) one oversized Bandit boss with 10x health.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] **Independent reviewer agent run** - given the symptom/requirement, NOT my theory (GROUND-RULES 8)
- [~] **Symptom reproduced in PLAY** — confirmed instrumented (`CampGuards within 250 of END_CAMP = 0`,
      no garrison folder, flag unset), but NOT from the player's camera: see the screenshot note below
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] **Proof it works better** — 14 instrumented checks, all passing (see implementation-plan.md).
      ⚠️ **The before/after IMAGE pair was WAIVED by the owner, 2026-08-27**, not skipped: `screen_capture`
      timed out on every attempt (client not rendering — Studio window not in the foreground), and their
      ruling was *"close now — I'll judge it in play"*, on the grounds that what images would settle is
      whether the field LOOKS right, which is a feel judgement made at the controls. Instrumented checks
      cover counts, positions, seating heights, damage magnitudes and fire timings; they say nothing about
      the look. If the field reads wrong in play, that is a new job.
- [x] Final summary + changelog written
