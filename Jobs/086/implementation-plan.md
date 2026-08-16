# Implementation Plan — Job #086

**Project**: `roblox.jungle`
**Status**: Planning (awaiting go-ahead)

Batch closed at four items. Decisions taken with the user 2026-08-16 are recorded inline.

---

## Item 1 — Land creatures must hold land *(todo 0046a)*

### Analysis

`stepToward()` ([EnemyServer.server.luau:184]) builds **every** move as `Vector3.new(x, WATER_Y, z)`,
for sea and land alike, so a land creature is a water-plane entity with a leash. The land spawner
anchors it only 8–20 studs past the bank edge while `LAND_LEASH = 65`, which leaves ~45 studs of
lunge straight into the channel. Nothing clamps it to shore and nothing reads terrain height.

The spawner already knows the geometry it needs: it calls `RiverData.branchesAt(z)` to find the bank
edges, and it already picks a `side` (+1 right bank / −1 left bank). That side is currently thrown
away after spawn — it is exactly what the movement clamp needs.

### Steps

1. **Persist the bank side.** In the land spawner (~`:441`), store the chosen `side` in the enemy's
   state table alongside `anchor`.
2. **Add a land-aware step.** Give `stepToward` an optional `side` parameter. When present:
   - recompute the bank edge at the *destination* `z` via `RiverData.branchesAt(z)` (the river winds,
     so the edge at the target z is not the edge at the anchor z);
   - clamp the new X to stay on the land side of that edge plus a small margin, so the creature can
     walk the shoreline but never step into the channel;
   - set Y from a downward raycast against terrain (`Include` filter on `Workspace.Terrain`), seating
     the model at `groundY + def.size.Y / 2`, with `WATER_Y` as the fallback if the ray misses.
3. **Pass `side` from both land branches** of the AI tick (`:318-325`) — the chase branch and the
   slink-back-to-anchor branch — so a land creature is clamped whether it is advancing or retreating.
4. Leave the sea path untouched; it is correct as-is.

### Consequences (intended)

Land creatures line the bank and lunge only when the boat comes within `biteRange`, which is what the
file header at `:4` always claimed they did ("ambush from the banks, leashed"). Cost is one terrain
raycast per land creature per frame — at most `MAX_LAND_CAP = 7`, negligible.

---

## Item 2 — Wolves move to camps; Boar compensates *(todo 0046b)*

**Decision:** camps only, and buff Boar to hold the riverbank's difficulty.

### Analysis — what removing Wolf actually changes

`pickType()` normalises the pool weights, and the **number** of bank spawns is governed by
`landCap()` and `spawnInterval()`, not by the pool. So dropping `Wolf` from `LAND_POOL` does **not**
thin the riverbank — it only changes what shows up. Every bank ambusher becomes a Boar.

Comparing the two defs, the gap is durability, not threat:

| | HP | Speed | Bite | Cooldown | **DPS** |
|---|---|---|---|---|---|
| Wolf | 55 | 26 | 12 | 1.8 | 6.67 |
| Boar | **40** | 30 | 10 | 1.4 | **7.14** |

Boar already out-damages *and* outruns the Wolf. The only thing the bank loses is **27% of its
hit points**. So the correct compensation is HP alone — raising Boar's damage as well would make the
riverbank harder than it is today, not equal to it.

### Steps

5. **`EnemyDefs.luau`** — Boar `hp = 40` → **`50`**. Deliberately not the Wolf's 55: Boar also brings
   more DPS and more speed, so matching HP exactly would leave the bank net-harder than before.
   Comment the arithmetic so the next balance pass sees the reasoning.
6. **`EnemyServer.server.luau:343`** — remove the `Wolf` entry from `LAND_POOL`, leaving Boar. Note in
   the comment that Wolf now spawns at camps.
7. **`ExcursionServer.server.luau`** — let a camp guard be something other than a Bandit:
   - `spawnGuard()` (`:784`) takes a `def` rather than hardcoding `EnemyDefs.Defs.Bandit`, and writes
     the def name to a `GuardType` attribute on the model;
   - `tickGuard()` (`:1410`) reads `GuardType` instead of hardcoding Bandit, falling back to Bandit so
     any guard built before this change still ticks;
   - `buildCampAt()` splits its guard count into bandits and wolves.
8. **Roster rule (proposed — say the word if you want it different):** the **near** camp stays all
   Bandit — it is the human raider outpost with the sandbags and the tower. The **deep** camp gets
   `math.max(1, floor(guards / 3))` Wolves and Bandits for the rest. That guarantees at least one wolf
   per landing, keeps every camp's total guard count **identical** to today, and makes the deep camp —
   the one holding the Metal and Ammo you actually need — read as a different kind of place.

All existing scaling still applies untouched: tier, `villageStep`, and crew-size `scale` produce the
guard count; this only decides what each one is.

---

## Item 3 — Drop hint no longer overlaps the health bar *(todo 0048)*

### Analysis

The left column has a documented vertical budget ([InventoryHud.local.luau:70-74]):
`hotbar 0.865–0.975 · health 0.803–0.845 · HANDS FULL card 0.761–0.797 · RoleChip 0.42`.

`dropHint` is anchored top-centre at `Position = (0.5, 1.05)` **inside** the card, so it hangs below
it: card top `0.761` + `1.05 × 0.036` = **0.799**, height `0.62 × 0.036` = `0.022`, occupying
**0.799–0.821**. The health row is **0.803–0.845**. The two overlap over `0.803–0.821` — the reported
bug, confirmed by arithmetic rather than by eye.

Job #084 moved the card itself off the health row but the hint added beneath it was never given
space in that budget.

### Steps

9. Flip the hint to sit **above** the card instead of below it — the direction the left column already
   stacks. `AnchorPoint` → `(0.5, 1)`, `Position` → `(0.5, -0.15)`, placing it at **0.733–0.756**,
   clear of the card's top edge at 0.761 and of everything else up to the RoleChip at 0.42.
10. Give it an explicit `ZIndex` so its stacking is chosen rather than incidental (its sibling
    `dropBtn` is `ZIndex = 5`).
11. Update the budget comment at `:70-74` to include the hint's row, so the next person editing this
    column sees it.

Stays scale-based and mobile-first; no fixed pixels.

---

## Item 4 — A tied boat is safe from the river only *(todo 0049)*

**Decision:** keep today's behaviour. Wildlife disengages at a mooring; camp guards do not.

### Analysis

The player half is **working as decided**, not broken: `ExcursionServer` has no tie check, so guards
keep fighting you at the pier. That is now the intended design.

The boat half is **not a defect at all** — traced through every write to the boat's `HP` attribute:

- wildlife (`EnemyServer:218`) is gated on `not suppressed` (`:328`), and a boat-targeting creature
  measures suppression at distance 0 from the hull, so it is *always* suppressed while tied;
- obstacles (`ObstacleServer:37`) return early on `Tied == true` before any damage;
- camp guards (`ExcursionServer:1475`) subtract from the **player's** HP only, never the hull;
- `CargoServer:136` and `BoatModules:384` only *add* HP (repair).

No code path can damage a moored boat. The `BOAT 0%` in the screenshot was damage taken **before**
mooring — the boat was already wrecked when it tied up.

### Steps

12. **No behaviour change.** The only defect here is a promise: Job #084's changelog told players
    *"Docks are a genuine safe zone — creatures leave you alone near a tied boat"*, which overstates
    what the game does now that the decision is "river only". Correct that line in
    `Jobs/084/changelog.md` and note the correction in this job's summary, so the shipped release note
    matches the game.
13. Record the decision in a comment beside the tied-dock safe zone (`EnemyServer:46-51`) — that the
    zone is deliberately wildlife-only and camp guards are exempt by design — so nobody "fixes" it
    later as an oversight.

---

## Deferred out of this job

**Turret + searchlight lag (`todo 0047`)** → **Job #087**, by your decision. It shares its root cause
with the boat's replication behaviour, so the fix is made once, after #087 decides on network
ownership. `todo/0047` stays open and is referenced from #087's intake.

---

## Files to be changed

| File | Items | Sync |
| --- | --- | --- |
| `sync/ServerScriptService/Enemies/EnemyServer.server.luau` | 1, 2, 4 | ✅ auto |
| `sync/ReplicatedStorage/Enemies/EnemyDefs.luau` | 2 | ✅ auto |
| `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` | 2 | ✅ auto |
| `sync/StarterPlayer/StarterPlayerScripts/UI/InventoryHud.local.luau` | 3 | ✅ auto |
| `Jobs/084/changelog.md` | 4 | n/a (doc) |

All four code files are in the **GAME** tree only — no lobby copies involved, so no cross-place edit.

## What I need from you

- [ ] **Go-ahead on this plan.**
- [ ] **Confirm or change the camp roster rule** (step 8) — near camp all Bandit, deep camp ≥1 Wolf.
- [ ] **Confirm Boar HP 40 → 50** (step 5), or name a different number.
- [ ] Studio-side: keep the game place open so the edits sync, then a playtest for verification below.

## Verification

- [ ] `bash tools/luau-analyze.sh` clean on all four edited files.
- [ ] Playtest: land creatures walk the shoreline and **never** enter the channel; they still reach and
      bite the boat when it passes close to the bank.
- [ ] Playtest: land creatures sit **on** the ground, not at water height, on sloped bank terrain.
- [ ] Playtest: every bank ambusher is a Boar; at least one Wolf is present at each deep camp and none
      at the near camp; camp guard counts match today's.
- [ ] Playtest: carry a crate — the drop hint is fully clear of the health bar at desktop and at a
      phone aspect ratio (Device Emulator).
- [ ] Read back via MCP that a tied boat still takes zero hull damage while wildlife disengages.
