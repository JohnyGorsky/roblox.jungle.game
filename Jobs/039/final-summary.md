# Final Summary — Job #039: Enemy glowing eyes

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · From todo 0008. Game-only.

## What was built
Every river enemy now spawns with **two glowing Neon eye dots**, so threats are visible in the dark
(pairs with the night surge #035 + torch/searchlight #037/#038).

- **Attachment-aware placement:** if a (future real) model has `EyeLeft`/`EyeRight` Attachments, the eyes
  go there; otherwise (greybox) they're computed from the PrimaryPart + `EnemyDefs.size`
  (front = −Z, up, ±side) — so the same code works for greybox now and rigged models later (the artist just
  adds the two attachments).
- **Neon parts** (Ball, red 255,45,45) — emit fully regardless of ambient, so they read in the dark with
  **zero dynamic-light cost** (safe with many enemies). They're anchored in the model → ride along with
  `enemy:PivotTo`, like the snout.

### Files
- **Edit:** `Enemies/EnemyServer.server.luau` — `addEyes(model, body, def)` helper; called in `spawnEnemy`.

## Verified (live in Studio)
- [x] Analyzer-clean.
- [x] Spawned enemy (Piranha) has **eyes=2**, `Material=Neon`, `Color=(255,45,45)` — confirmed on the model.
- [~] A dark-scene close-up screenshot wasn't captured cleanly (enemy AI keeps them moving + the server
      day/night clock overrode the client night dim) — the eyes are confirmed by model inspection.

## Notes / follow-ups
- **Not committed.** Test account reset to clean.
- Applied to river enemies (sea + land); camp guards (ExcursionServer) could get the same `addEyes` later.
- "Brighter at night" is inherent — Neon always emits, so eyes pop in the dark and are just dim red dots by
  day; a night-only brighten/PointLight could be added but Neon already reads well and is cheap.
- Real eye art comes with the model/design pass (drop `EyeLeft`/`EyeRight` attachments on the models).
