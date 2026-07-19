# Job #021: Persistence foundation: player profile + Gold balance

**Project**: `roblox.jungle`
**Created**: 2026-07-19 11:41:17
**Status**: Requirements Gathering (intake)

## Requirements / goal

POC. Session-locked DataStore player profile (ProfileStore-style) storing spendable Gold + lifetime stats; load on join, autosave, save on leave and BindToClose, pcall+retry. Show Gold balance in the lobby (minimal GUI). FOUNDATIONAL - all other economy/progression jobs depend on this. Design source: Job 020 sections 1 and 7. Simple GUI, no polish.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created (`implementation-plan.md`)
- [x] Implementation completed — persistence verified live in Studio (gold=100 persisted across reload;
      session lock acquire/release/reacquire; Gold HUD renders; analyzer-clean both trees)
- [x] Final summary + changelog written
