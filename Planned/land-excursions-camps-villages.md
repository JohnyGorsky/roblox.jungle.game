# Land excursions — landing sites, camps & villages to raid

**Source:** GAME.md "Landing sites & land excursions" (2026-07-18). **Depends:** #005 (river generator),
docks (P4), land combat (P3).

Turn "reach a dock and scavenge" into a real set-piece: at **designated landing sites** the river widens
onto a **coast / open bank**, the crew **disembarks onto bigger walkable terrain**, treks to a **camp or
village**, **raids it** (guarded loot: fuel/ammo/currency/upgrades), and hauls it back. The boat waits,
exposed.

## The loop (refined 2026-07-18)
Docks are the **only** disembark points. At a dock: **tie the boat** (rope, hands-on) → only then can the
crew **get out** → **trek into dense jungle on foot** → reach a **generated camp** → **raid** (guarded
loot) → **haul back** → **untie** → drive on. Boat + trailer sit **anchored but exposed** while you're
inland (guard-vs-raid trade-off). At night the water's deadly, so going ashore can be the *safer* play.

## Scope (future)
- **Tie/untie mechanic** — rope the boat to the dock (a `RopeConstraint` / anchored state); disembark is
  gated on "tied". Untie to leave.
- **Dense jungle along ALL shores** — forested banks (trees/foliage), not bare grass — a big addition to
  the #005 generator (greybox blocks → Meshy foliage at P9). Watch mobile perf (instancing/streaming).
- **Walkable jungle pocket at each dock** — terrain **opens inland** into a larger on-foot area + camp,
  vs the tight travel banks.
- **Generator = multiple seeded modes** — main river + **jungle/camp POI zones** stitched in at docks.
  Extends #005 `RiverData`/`RiverGenerator`; keep them **mode-aware**.
- **Camps** — seeded structures inland: defended, loot tables (metal/ammo/fuel/currency), carry-back.
- **On-foot combat** — land threats (panthers +…) defend camps; a boat-defense trade-off (who guards).

## Open questions
- Are docks/camps **fixed** (seeded) or random? (Leaderboard fairness vs variety — leaning seeded.)
- Camp footprint vs **mobile perf** — streaming a wide jungle POI vs the narrow channel.
- Is **every** dock a raid site, or are big camps/villages special (some docks = just refuel)?
- Boat security while tied: fully safe, or can threats damage the tied boat/trailer (someone must guard)?

## Why it matters
This is the river game's equivalent of Dead Rails' **towns** — the reason to stop, the loot spikes, the
best risk/reward moments, and a major source of variety & replay.

→ Promote to a job (after the main river + docks exist).
