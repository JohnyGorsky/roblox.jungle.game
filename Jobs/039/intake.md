# Job #039: Enemy glowing eyes (spot them in the dark)

**Project**: `roblox.jungle`
**Created**: 2026-07-19 17:37:59
**Status**: Requirements Gathering (intake)

## Requirements / goal

From todo 0008. Give river enemies two glowing Neon EYE dots so you can spot threats at night. Attachment-aware placement: if the (future real) model has EyeLeft/EyeRight Attachments, put the eyes there; else (greybox) compute an offset from the PrimaryPart + EnemyDefs size (front + up + left/right). Neon parts (cheap, always emit → read in the dark), red. Applied in EnemyServer.spawnEnemy for all river enemies; parts ride the model via PivotTo. POC greybox.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan (inline; design in prior chat)
- [x] Implementation completed — 2 Neon red eyes per enemy, attachment-aware; verified (Piranha eyes=2 Neon red); analyzer-clean
- [x] Final summary + changelog written
