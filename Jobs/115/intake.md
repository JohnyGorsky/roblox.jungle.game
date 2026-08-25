# Job #115: Destructible generators — reusable script, HP, FX, sounds, wired to the 3 end-zone generators

**Project**: `roblox.jungle`
**Created**: 2026-08-25 00:24:08
**Status**: ✅ Completed (see final-summary.md)

## Requirements / goal

User request: the three editor-placed generators in the end zone (`Workspace.EndBase.Bunker.Generator1/2/3`, library copy at `ServerStorage.AssetLibrary.Structures.Generator`) must become destructible props, driven by ONE reusable script so later jobs can spawn generators anywhere and get the same behaviour.

Behaviour asked for:
- Health, damageable by the existing weapons: ~10 hits with melee, more damage from bullets (same numbers enemies take).
- Health bar shown when a player approaches.
- `eletricity_going` (90617779140381) while alive; `generator_dead` (119782619832290) when it dies; no sound once dead.
- Electricity particles constantly while alive; bigger RED burning particles when hit; smoke only once dead, plus a small 'DISABLED' message above it.
- Wire all three end-zone generators.

Decisions taken with the user (wizard, 2026-08-25):
- Hum LOOPS while alive (positional), PLUS a louder one-shot zap of the same sound on each hit.
- 150 HP = exactly 10 axe hits (axe 15/hit), 8 pistol shots, ~2 point-blank shotgun blasts.
- Destroying one pays 6 Salvage, the same as a land kill, through the existing RewardFeed notify. An `onDisabled` hook + a disabled-count attribute are exposed so a later job can wire doors/power to it.

Measured up front (Edit, 2026-08-25):
- Generator1 (319.5, 22, 18414.7) and Generator2 (298.5, 22, 18200.7): one 8.96 x 8 x 5.31 MeshPart child named `Generator`, anchored, no PrimaryPart.
- Generator3 (349.3, 63.5, 18251.8): the same model at HALF scale (4.48 x 4 x 2.66), up on the tower — so every offset must be derived from the model's own bounds, never hard-coded.

Constraints:
- Game place only (`sync/`); the lobby has no end zone.
- The three damage sites (MeleeServer, WeaponServer, GunServer) already target any Model carrying a tag + an `HP` attribute — that tag is the seam, so the hit/death reactions hang off `HP` changing rather than new code in the combat path.
- `MeleeServer` reads `best.PrimaryPart` for its hit FX and these models have none — the attach step must set it.
- Asset bible + shared audio registry must record the two new sounds.

## Checklist

- [x] Requirements reviewed (this intake)
- [ ] **Independent reviewer agent run** — NOT run: this session is instructed not to call the Agent tool unless asked (recorded in final-summary.md)
- [x] N/A — new feature. Measured the ground truth in Edit first (model sizes, half-scale Generator3, sound lengths) before writing anything
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] **Proof it works better** captured in PLAY — per-hit HP, dead-state read-back, spawn-path test (final-summary.md). ⚠️ the LOOK cannot be captured: screen_capture renders no billboards/particles
- [x] Final summary + changelog written
