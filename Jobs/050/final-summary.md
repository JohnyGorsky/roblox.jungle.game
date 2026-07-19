# Final Summary — Job #050: River forks + small islands

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · River journey overhaul **#3 of 6**
(`Planned/river-journey-overhaul.md`). Game place. Greybox.

## What
The river now occasionally **splits into two branches around a small island, then merges** — braided
set-pieces concentrated in the wide zones (Lost Delta). Adds variety and route choice without changing boat
physics.

## Implementation
- **`sync/ReplicatedStorage/River/RiverData.luau`**:
  - Fork constants (`FORK_SPACING` 1500 · `FORK_LEN` 520 · `FORK_MAX_OFFSET` 130 · `FORK_BRANCH_FRAC` 0.62 ·
    `FORK_MIN_WIDTH` 220).
  - `forkOffsetAt(z)` — deterministic fork set-pieces, **only where the channel is wide** (≥220 ≈ Delta);
    branch separation ramps `0→max→0` (smooth split → island → merge) via a sine bump.
  - `branchesAt(z)` — returns **1 channel** normally, or **2 branches** (each 62% width) around the island
    inside a fork. The single source both terrain and boat read.
  - Obstacle hooks + docks **suppressed inside forks** (keep the braided stretch clean).
- **`sync/ServerScriptService/River/RiverGenerator.luau`**: per z-slice uses `branchesAt`; a column is water if
  within **any** branch, the land between branches becomes a **low walkable island**, banks/hills use the
  nearest branch. (`MAX_HALFW` 170 already covers the branch spread.)

No boat/pathing change: water stays continuous, current still pushes downstream, the player steers down
whichever side.

## Verified (live in Studio — Play, fresh module compile)
- [x] Analyzer-clean.
- [x] Peak fork at z=15000: `forkOffsetAt=130` → branches `c=-246 hw=83` + `c=14 hw=83` (two ~166-wide
      channels) around a ~94-wide island.
- [x] Screenshot: the Delta channel visibly splits around a small island into two branches, grassy banks,
      merging at the ends.

## Notes / follow-ups
- **Not committed.**
- **Studio gotcha noted:** Edit-mode `require` returns a *stale cached* module after a mid-session Source
  change — verify river-module changes in **Play** (fresh DataModel), not Edit.
- First fork near the Delta entrance is clipped by the width gate (opens partially) — fine; deeper forks open
  fully.
- Island is greybox low terrain; the art pass can dress it (trees/props), and #4 (off-path density) / #5 (camps)
  could later make islands raid-worthy.
- Next in the overhaul: **#4 off-path = dense & dangerous** (trees + spawns), then **#5 camps**, **#6 pacing**.
