# Final Summary — Job #086

**Project**: `roblox.jungle`
**Completed**: 2026-08-16
**Status**: ✅ Code complete, analyzer clean, sync verified — ⏳ awaiting playtest verification

Three of the four batch items implemented; the fourth was a decision + documentation fix. The fifth
reported issue (turret/searchlight lag) was deferred to Job #087 by the user's decision.

---

## Item 1 — Land creatures now hold land

`stepToward()` pinned **every** creature to `WATER_Y`, sea and land alike, so a "land ambusher" was a
water-plane entity with a leash: anchored 8–20 studs past the bank with `LAND_LEASH = 65`, it had
~45 studs of lunge straight into the channel. That is why wolves swam.

Two things were missing and both were added to `EnemyServer.server.luau`:

- **A bank clamp.** New `bankEdgeAt(z, side)` finds the fork-aware shoreline — the same computation
  the land spawner already used to place anchors — and the step clamps X to the land side of it plus
  `BANK_MARGIN = 6`. The edge is recomputed at the **destination** z, not the anchor's: the river
  winds, so a creature walking downstream would otherwise wade out as the channel bent toward it.
- **A ground height.** New `groundYAt(x, z)` raycasts terrain and seats the model at
  `groundY + size.Y/2`. Measured, never assumed — the bank is generated, not carved flat, so there is
  no `CLEAR_Y` equivalent to trust out here. A missed ray keeps the previous height rather than
  teleporting the creature.

Both are passed through an optional `side` parameter, so the sea path is byte-for-byte unchanged.
`side` is threaded into **both** land branches — advancing and slinking back — so a creature is
clamped whichever way it moves. The land spawner also now seats its **anchor** on the ground, which
was previously parking every idle ambusher at water height on a bank metres above it.

⚠️ The bank side is stored as **`st.bank`, not `st.side`** — `st.side` is the *sea* flank side
(`:369`), and reusing it would have made crocs pick their attack side from a bank they do not have.
The `State` type was extended with a comment recording that distinction.

Cost: one terrain raycast per land creature per frame, at most `MAX_LAND_CAP = 7`.

## Item 2 — Wolves moved to camps, Boar compensates

**Decision:** camps only, and buff Boar.

`Wolf` removed from `LAND_POOL`. Worth recording *why this does not thin the riverbank*: `pickType()`
normalises the pool weights, and the **count** of land spawns comes from `landCap()`/`spawnInterval`.
Removing Wolf changes only *which* creature appears — every bank ambusher is now a Boar.

Comparing what the bank had against what it has:

| | HP | Speed | Bite | Cooldown | DPS |
|---|---|---|---|---|---|
| Wolf | 55 | 26 | 12 | 1.8 | 6.67 |
| Boar (was) | **40** | 30 | 10 | 1.4 | **7.14** |
| Boar (now) | **50** | 30 | 10 | 1.4 | 7.14 |

Boar already hit harder per second *and* moved faster, so the only thing the bank actually lost was
hit points — hence HP alone, and **50 rather than a straight 55**: matching the Wolf's HP while
keeping Boar's higher DPS and speed would have left the riverbank harder than before, not equal to it.
The arithmetic is commented in `EnemyDefs.luau` for the next balance pass.

Camp guards can now be something other than a Bandit:

- `spawnGuard()` takes a `guardType` and writes it to a **`GuardType` attribute** on the model —
  an attribute rather than a side table because `tickGuard` runs off the `CampGuard` **tag** and
  would otherwise have no route back to the def for a given model;
- `tickGuard()` reads that attribute, falling back to Bandit so any guard built before this change
  still ticks with the stats it was built from;
- `buildCampAt()` splits the roster: the **near** camp stays all-Bandit (the human raider outpost,
  with the sandbags and the landing tower); the **deep** camp — the one holding the Metal and Ammo the
  crew actually needs — gets `max(1, guards/3)` Wolves;
- the day-respawn loop keeps the mix: `wolves` is stored on the garrison, wolves hold the first slots,
  so a re-manned camp does not drift all-Bandit.

**Guard counts are completely unchanged** — tier, `villageStep` and crew-size `scale` still produce
the number; this only decides what each one is. Difficulty impact is near-nil by design: a Wolf guard
is a Bandit with the same 55 HP and the same 12 damage, faster (26 vs 20) but biting slower (1.8s vs
1.4s).

## Item 3 — Drop hint no longer covers the health bar

Pinned numerically rather than by eye. The left column has a documented budget; `dropHint` was
anchored top-centre at `(0.5, 1.05)` *inside* the card, putting it at **0.799–0.821** — straight over
the health row at **0.803–0.845**. Job #084 moved the card itself clear of the health bar but never
budgeted a row for the hint it added underneath.

Flipped to anchor bottom-centre at `(0.5, -0.15)`, placing it **above** the card at ~**0.733–0.756** —
the direction the left column already stacks. Given an explicit `ZIndex = 5` matching its sibling
`dropBtn` so the stacking is chosen rather than incidental, and the budget comment updated to include
the new row.

## Item 4 — A tied boat is safe from the river only

**Decision:** keep today's behaviour — the crocs let go, the raiders do not.

The player half is now *intended*, not broken. The boat half was **never a bug**, established by
tracing every write to the boat's `HP` attribute:

- wildlife (`EnemyServer:218`) is gated on `not suppressed`, and a boat-targeting creature measures
  suppression at distance 0 from the hull, so it is **always** suppressed while tied;
- obstacles (`ObstacleServer:37`) return early on `Tied == true` before any damage;
- camp guards (`ExcursionServer:1475`) subtract from the **player's** HP only, never the hull;
- `CargoServer:136` / `BoatModules:384` only *add* HP.

No code path can damage a moored boat — the `BOAT 0%` in the report was damage taken **before**
mooring. So no behaviour changed. What was actually wrong was a **shipped promise**: Job #084's
changelog told players *"Docks are a genuine safe zone — creatures leave you alone near a tied boat"*.
That line was corrected in `Jobs/084/changelog.md` to say the river backs off but raiders do not, and
the decision is now commented beside `TIED_SAFE_RADIUS` so nobody later "fixes" the guard exemption as
an oversight.

---

### ✅ Auto-synced files

- `sync/ServerScriptService/Enemies/EnemyServer.server.luau` (items 1, 2, 4)
- `sync/ReplicatedStorage/Enemies/EnemyDefs.luau` (item 2)
- `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` (item 2)
- `sync/StarterPlayer/StarterPlayerScripts/UI/InventoryHud.local.luau` (item 3)

Plus `Jobs/084/changelog.md` (doc correction, item 4). All code files are in the **GAME** tree — no
lobby copies involved, so no cross-place edit.

### ⚠️ Manual Studio copy required

- _none_

## Verification

- [x] `bash tools/luau-analyze.sh` clean (exit 0) on all four files. The first run **failed** and
      caught two real defects — `bank` missing from the `State` type and `wolves` missing from
      `Garrison`; both types were extended and documented before re-running.
- [x] Read back live in Studio (Edit): 11/11 checks pass — Boar hp 50, Wolf gone from `LAND_POOL`,
      `BANK_MARGIN` + `groundYAt` + `st.bank` present, `GuardType` + roster split present, hint
      re-anchored. Stat table confirmed: Wolf 55/26/12·1.8, Bandit 55/20/12·1.4, Boar 50/30/10·1.4.
- [ ] **Playtest (yours)** — land creatures walk the shoreline and never enter the channel.
- [ ] **Playtest** — land creatures stand *on* sloped bank terrain, not at water height.
- [ ] **Playtest** — every bank ambusher is a Boar; ≥1 Wolf at each deep camp, none at the near camp;
      guard counts match today's.
- [ ] **Playtest** — carrying a crate, the drop hint is fully clear of the health bar at desktop and
      at a phone aspect ratio (Device Emulator).

## Notes / follow-ups

- **`todo/0047` (turret + searchlight lag) stays open**, deferred to **Job #087** by your decision —
  it shares its root cause with the boat's replication behaviour, so the fix is made once, after #087
  settles network ownership.
- Raised during this job and **not** logged as work: players have no in-game way to discover where
  Metal comes from (deep camp only), and Salvage has no dedicated pickup object — it is a by-product
  of looting crates. ASSETS.md still lists the `Scrap / salvage pile` prop as required-but-missing.
- Not committed — the user commits (GROUND-RULES §1).
