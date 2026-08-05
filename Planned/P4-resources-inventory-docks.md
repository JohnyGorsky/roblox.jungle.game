# P4 — Resources, inventory & docks

**Source:** Job 001 roadmap. **Depends:** P3.

**Fuel** (scavenge + haul back to the boat to keep moving; run dry = stranded) + **ammo**, a
**limited inventory** (purchasable slots later), and **designated docks**: disembark → scavenge under
threat → refuel/rearm. Closes the core loop.

→ Promote to a job.

## ⏱️ This is what fixes the short run (analysis 2026-08-05)

A playtest observation — *"the run is pretty short"* — was traced here rather than to the river's length.
The numbers, derived from `BoatServer` and `RiverData`:

| | |
|---|---|
| Top speed downstream | `(THRUST 60000 + CURRENT 12000) / DRAG 2000` = **36 studs/s** |
| `END_DISTANCE` | 18000 studs |
| **Pure travel time, throttle held** | **~8 min 20 s** |
| Range per tank | `MAX_FUEL 100` ÷ 1.0 fuel/s = 100 s = **3600 studs** |
| Landings | every 3200 studs (`DOCK_SPACING` × 2 — only odd docks are landings) → **6** |

**The distance is fine; the stops are free.** The design intends six forced excursions —
tie up → trek inland → raid a guarded camp → haul gasoline/metal/ammo back → pour it in at the station →
untie. GAME.md flags what actually ships today: *"the current greybox refuels straight from the dock — a
simplification of this loot → deck → station flow."* So a stop costs seconds instead of minutes, and
9 minutes of travel is the whole run.

**Do NOT fix this by raising `END_DISTANCE`.** It's free in memory terms (the generator streams ~10 chunks
regardless of total length, so `MAX_CHUNK` just grows), but it buys more of the same 70 chunks of noise and
drags `DOCK_SPACING` with it — fuel range is only **1.125×** landing spacing, so the two can't move
independently. Build the reason to stop instead, and the existing 18000 studs becomes the intended
15–25 min on its own.

The stale *"≈ a long ~15–25 min run"* comment on `RiverData.END_DISTANCE` has been corrected with the
derivation, so nobody re-tunes against a wrong number.
