# Job #100 — Final summary (interim)

**Project**: `roblox.jungle` · **Place**: GAME (`sync/`)
**Status**: ⚠️ **IMPLEMENTED, NOT SIGNED OFF.** The systems work and are verified; the **perf gate is
not passed** and I did not follow my own plan's stage 1.

Intake: [intake.md](intake.md) · Plan: [implementation-plan.md](implementation-plan.md)

---

## 1. What was built

**`World/CampLayout.luau` (new)** — the seeded assembler. `CampDefs` keeps the parts list and the rules;
this decides where things go, deterministically from `(campPos)` so a run is reproducible.

**Preserved deliberately** (a naive scatter destroys all three, and they are what make a camp readable):
fire at centre · everything faces the approach · **loot behind cover**.

**Now varies per camp:** 3–5 buildings (was always exactly 1 hut + 1 tent) in generated positions, a
**sandbag ring with 2–3 gaps** (was a 3-piece line across the front), loot tucked behind the buildings
that shelter it, guard posts, reinforcement entry points, dressing, nugget, kind-crates, radius.

**Defence half:**
- The **garrison** now stands at generated ring posts. Verified in-world: guards measured **36 and 67
  studs** from camp centre, where the old code put them **~8 studs in front of the player**.
- **Reinforcements enter from outside** the perimeter at gap-adjacent spawn points and are given a post
  to walk to.
- **The night skip is gone.** The loop used to `continue` at night — *"a cleared camp stays cleared until
  dawn"* — which is the exact opposite of the requirement. Holding ground overnight now costs a fight.
- **A cleared camp holds for `regarrisonHours` of GAME time** (near 7, deep 9) before anything returns,
  measured in `ClockTime` so it is a fact about the world, not the player's wall clock.
- **Still one at a time**, which was already true and is also the "1 or 2, then after some time others"
  requirement — a trickle keeps a defenceless hauler survivable and the R15 rig count flat.

## 2. Integration problems found and fixed

The layout was consumed from **outside** `buildCampAt` in three places that would have silently used the
old fixed slots: the trampled-ground painter, the gold nugget, and the two kind-crates. Left alone, the
nugget would spawn inside a hut that only exists in the new arrangement, and worn earth would be painted
where no building stands. `CampLayout.forCamp` memoises per camp position so every consumer sees the
same generated camp; `forget` releases it when a landing site is culled.

`spawnGuard` now returns the guard (it returned nothing) so a reinforcement can be assigned a post.

## 3. Verified

| Check | Result |
|---|---|
| Variety across 6 generated camps | **5 distinct shapes**, positions differ in all 6 |
| Rule 1 — fire at centre | pass |
| Rule 3 — no loot exposed at the camp front | pass, 0 violations |
| Reinforcement spawns outside the ring | pass, 0 inside |
| Guard posts inside the ring | pass, 0 outside |
| Determinism (same seed → same camp) | pass |
| Built in-world | 3–5 buildings/camp, 32 sandbag segments across two rings, loot + tower + crates placed |
| Garrison position | **36 / 67 studs** from centre (was ~8) |
| `luau-analyze` | clean |

## 4. ⚠️ The perf gate is NOT passed, and I skipped stage 1

My own plan said **"profile the current camp on a phone preset — the baseline decision 3 is measured
against"** as step 1. I went straight to building, so there is **no before-number**, which is exactly the
mistake that made the whole #094–#099 sequence expensive.

What I do know:
- **Server-side: 1024 BaseParts per landing site.** Job #100's share is roughly **+84** (extra buildings
  ≈ +58, sandbag ring ≈ +26), i.e. **~8%** of the site — the other ~940 were already there (clearing
  ~350, tower 128, trading post 95, two hero crates 132, foliage).
- **Client-side measurement in this session was worthless and I nearly misread it.** The client showed a
  flat ~15 fps, which looked alarming — but the landing site reports **0 BaseParts / 603 Models** there
  (geometry streamed out), and **removing the entire site changed frame time by 0.0 ms**. The frame rate
  is a Studio-Play floor unrelated to camps, and it was measured at desktop resolution because the Device
  Emulator had reset when Play restarted.

**So the honest position: the cost looks small (~8% of a site's parts) but it has not been measured on a
phone with the region streamed in.** That is the remaining gate, and it should be run before this ships.

## 5. Not yet verified

1. **The perf gate** (§4) — emulator on, streaming loaded, before/after.
2. **A reinforcement actually walking in from a gap.** The code path is correct and the entry points are
   proven outside the ring, but triggering it live needs a cleared camp plus 7–9 in-game hours.
3. **Pathfinding** — reinforcements are given a post as attributes; the walk-in itself uses the existing
   guard AI. Whether they route sensibly through a gap rather than at the sandbags needs a playtest, and
   the plan's "fallback if a path fails" is **not yet implemented**.
4. **#058 balance** — untouched on purpose (counts and mix unchanged), but arrival delay plus
   re-garrison changes encounters per run. Ship-then-tune, as agreed.

## 6. Files changed

| File | Change |
|---|---|
| `World/CampLayout.luau` | **new** — seeded assembler + memoised per-camp accessor |
| `Excursion/ExcursionServer.server.luau` | generated layout wired through `buildCampAt`; garrison at posts; reinforcements from outside; re-garrison hold-off in game hours; night skip removed; `spawnGuard` returns the guard; nugget/kind-crates/trampled-ground use the shared layout |
