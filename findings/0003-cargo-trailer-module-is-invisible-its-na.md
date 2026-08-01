# FINDING 0003: Cargo Trailer module is invisible + its name is stale. BoatModules welds 'Trailer' (8x1.5x7) at Z 15.5, which sits entirely inside the rear CargoDeck footprint (Z 11..27) and 1.4 studs below it -> the 180-Gold upgrade cannot be seen. Also ModuleDefs still calls it 'A towed barge', but towing was abandoned in Job 013 (jittery per roblox-physics; replaced by a welded rear deck), so the player-facing text is wrong. Needs a visible position + a truthful name.

**Project:** `roblox.jungle`
**Status:** fixed (2026-08-01)
**Severity:** med
**Created:** 2026-07-31 23:20:27

**Symptom:** _TODO_
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_


## Resolved — Job #066, 2026-08-01

Both halves fixed, and the design question behind it settled.

- **Visibility:** the part moved from `(0, −0.4, 15.5)` — buried inside the rear `CargoDeck` and 1.4 studs
  below it — to `(0, 3, HALF_Z + 4)`, sitting **on** the rear deck as cargo racks. A visible module again.
- **Name:** `"Cargo Trailer" / "A towed barge"` → **`"Cargo Racks"` / "Deck racks and crates — carry more
  loot."** Player-facing strings only; the module id stays `trailer` so profiles and `BoatParts` keep working.
- **Design settled:** there is **no towed body**. Cargo lives on the boat's own rear `CargoDeck`.
  `GAME.md` was rewritten accordingly (*Cargo — the rear cargo deck & on-boat stations*), and `ASSETS.md`
  records that no trailer/barge mesh is needed. The barge render generated before this was settled sits in
  `assets/Images/Boat/_unused/` — do not wire it up.
