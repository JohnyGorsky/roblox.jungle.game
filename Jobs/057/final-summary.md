# Final Summary — Job #057: Medic role (4th crew role)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Implements the GAME.md decision
(todo 0000): the 4th role is **Medic**. Game place. Greybox.

## What
A presence-based 4th role (like the Fuel/Repair stations): while a crew member mans the **Medic station**, the
crew is passively healed and revives are buffed (further range, faster, slower bleed-out). Stacks with the
per-player Combat Medic skill (`SkillMedic`).

## Implementation
- **`CargoServer`**: builds a labelled **"Medic Station"** part on the back deck (presence target, no spend).
- **`RoleServer`**: sets `boat.StationMedic` while the station is manned, and passively heals non-downed crew
  (HP < MaxHP) at **`MEDIC_REGEN` 3 HP/s** (mirrors the repair-station hull regen).
- **`PlayerCombat`** (revive buffs, read from `StationMedic`): snapshot at down-time → RevivePrompt range
  **2×** (12→24) and bleed-out **1.6×** longer; live at hold-begin → hold **×0.6** (stacks with `SkillMedic`).

## Verified (live in Studio — medic manning the station)
- [x] Analyzer-clean.
- [x] `StationMedic=true` when the station is manned; the Medic Station part + "MEDIC" label build on the boat.
- [x] **Crew heal**: an injured crew member at HP 50 rose to **57** over 2.5s (~3 HP/s).
- [x] **Revive range**: a player downed while a medic was aboard got RevivePrompt `MaxActivationDistance=24`
      (vs 12 normal). Faster-hold + slower-bleed use the same verified `StationMedic` snapshot.

## Notes / follow-ups
- **Not committed.**
- Numbers tunable (`MEDIC_REGEN`, range ×2, bleed ×1.6, hold ×0.6).
- Crew heal currently applies to all non-downed crew (the medic supports everyone); could be limited to
  near-boat if it feels too strong. Solo tuning pass (the other GAME.md follow-up) is still open.
