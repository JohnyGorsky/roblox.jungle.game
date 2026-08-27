# Job #122: Endgame grenadiers: slow the fire rate and shorten their reach

**Project**: `roblox.jungle`
**Created**: 2026-08-27 20:36:07
**Status**: ✅ COMPLETE — implemented, verified in Play, closed 2026-08-27 (see final-summary.md)

## Requirements / goal

User after playing Job #121's endgame: 'reduce enemy (bazooka) fire rate. It is not survivable' and 'also reduce how far they shoot'. Decisions via wizard: 36s per man (a shell every 12s on the field, down from every 4s), END ZONE ONLY - river camps keep 20s. Plus shorten the end-zone grenadiers' engagement reach; note the effective number is the ALERTED sight of 300, not the 160 aggro radius.

## Checklist

- [x] Requirements reviewed (this intake)
- [~] **Independent reviewer agent** — NOT run. This job is three tuning numbers plus one target filter,
      all measured before and after in Play; Job #121's reviewer had already covered this subsystem, and
      its finding B (lockstep firing) is what the phase spread here builds on. Flagged, not skipped silently
- [x] **Symptom reproduced in PLAY** — the pre-change rate was measured in Job #121 (blast gaps 4.04 s
      and 3.95 s at the field centre), which is the symptom the owner reported
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] **Proof it works better** — measured before/after: field rate 4 s → 12.0 s, warlord's post 4 s → one
      shell in 44 s, grenadiers reaching that post 3 → 1, blasts on a tower platform → 0 with 29 melee as
      the liveness proof. ⚠️ IMAGE pair still not captured (screen_capture times out; Studio not in front)
- [x] Final summary + changelog written
