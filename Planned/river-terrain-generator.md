# Seeded river + terrain generator (reusable module)

**Source:** Spike #004 "Next" + Job #003 (P1) follow-up. **Depends:** #004 (voxel direction locked).

The winding river the boat drives on is currently a **one-off baked into the live place** — the boat
even hardcodes a centerline/waterline **measured** from that sculpt. It does not regenerate, and if the
terrain is re-sculpted the boat constants silently desync.

## Scope
- A reusable module: **input a seed → river centerline + carved channel + terrain water + flanking
  noise hills** (altitude-painted grass → rock → snow), built with the `roblox-terrain` verify
  discipline (compute geometry → carve-then-fill → read-back verify).
- **WIDE river by design** (GAME.md, 2026-07-18): a broad channel with room for **obstacles** (rocks,
  logs, sandbars, wrecks) and **ramps/jumps**, not a tight lane. **Width is a generator parameter**
  (min/typical width per stretch); occasional **narrows/rapids** as pinch-point set-pieces; possible
  **forks**. Obstacle/ramp *placement hooks* along the channel (the props themselves can come later).
- **Stream/cull** ahead of / behind the boat for a long river (mobile perf).
- Expose the centerline **and the width profile** as **shared data** so both the terrain and the boat
  (`BoatServer`) read one source instead of the boat hardcoding a measured centerline.
- Same seed → same river (random per run, or a shared **daily seed** for fair leaderboards).

## Why it matters
Turns the greybox river into real, regenerable content; removes the boat↔terrain constant desync;
foundation for endless mode (P10) and fair seeded runs.

→ Promote to a job (likely alongside P5 zones).
