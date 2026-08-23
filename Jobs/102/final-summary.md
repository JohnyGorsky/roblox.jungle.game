# Job #102 — Final summary

**Project**: `roblox.jungle` · **Place**: GAME only (`sync/`) · **Status**: Complete, verified in Play

> *"1) first camp has too many enemies when i land, lets keep that in first camp we have just 2 enemies
> initial, in first part (bandit) and further camp (wolf or bandit) 2) now there is bug, after i defeat
> both, i can wait whole day and no new enemies come. we need new enemie after 2-3 minutes so they come
> from side to camp to their position, if i am near they attack as initial 3) decrease enemy hit by 20%
> 4) when you exit first time boat, we need message - gather resources etc, now users dont know what to do"*

---

## 1. 🔴 Requirement 2 was three bugs, not one — and the two I found by reading were not the whole story

The reinforcement feature existed. Job #100 had built it. It had **never once worked end to end**, for
three independent reasons that each hid the next. An independent reviewer — given only the symptom,
never my theory (GROUND-RULES §8) — found the two I had missed.

### A. Two waits in series that nobody ever added up *(found by reading; the dominant cause)*

A **wiped-out** camp had to clear two gates, one after the other:

1. `regarrisonHours` of **game** time — 7 h near, 9 h deep;
2. *then* `g.timer` began accruing toward `GUARD_RESPAWN_MIN..MAX` = 120–240 real seconds.

`DayNightServer` runs 13 daylight hours over 480 real seconds = **36.9 real seconds per game hour**:

| | hold-off | + interval | total |
|---|---|---|---|
| near camp, cleared by day | 258 s | 120–240 s | **6.3 – 8.3 min** |
| deep camp, cleared by day | 332 s | 120–240 s | **7.5 – 9.5 min** |
| requirement | | | 2 – 3 min |

The loop's own header claimed *"reinforcements arrive every ~2–3 REAL minutes"* the whole time. That
claim described gate 2 and silently ignored the 4–5 minute gate standing in front of it.

**Why it reads as "never".** Dusk is 19:00 and dawn 06:00, so a whole night is only **180 real seconds**.
A player who clears the camp in the afternoon and watches the sun go down and come back up has waited
**3–5.5 real minutes** — *inside* the hold-off. *"I waited a whole in-game day"* and *"nothing ever came"*
are both literally true at once.

### B. A garrison record could be reaped at birth — and only ever at the near camp *(reviewer)*

`buildCampAt` inserted into `garrisons` while the site model was still **detached**;
`model.Parent = campsRoot` is the last line of `buildLandingSite`. The respawn loop's first gate drops
any record whose site is unparented — and the build **yields** in that window (`settleTerrain()` waits
two frames inside the *deep* camp's build). Land on that tick and the **near** camp never re-garrisons
again for the whole run. Silently: no error, no warning.

**The asymmetry is the tell, and it matches the report exactly.** The deep camp's record is created after
the last yield in the function, so **only the near camp can lose one** — *"at the **first** camp"*.

### C. Reinforcements never actually walked in *(reviewer)*

The requirement is *"they come from side to camp to their position"*. Job #100 built two of the three
parts — spawn beyond the perimeter, `postPos` inside — but `tickGuard` clamps every step to
`GUARD_LEASH = 55` studs from `st.anchor`, and for a reinforcement **the anchor is its post**. Entries
sit 96–114 studs from the camp centre, posts 35–65, so spawn-to-post is routinely well over 55 — and that
clamp is not a speed limit, it is a hard reposition. On the guard's **first Heartbeat** it was moved
40–120 studs onto the 55-stud sphere around its post. It appeared at the barricade; nobody saw it come.

### D. …which in turn exposed a fourth: entry points in the river and inside the rock wall

`CampLayout` places entries at `radius + 26..40` with no idea what is out there. The near camp is 120
studs inland, so a waterward entry lands ~6 studs from the river; the deep camp is 300 inland, so an
inland entry lands ~414 — **inside the far wall, which spans 400–430**. `groundAt` does not save it: it
rejects the wall-top hit and falls back to `CLEAR_Y + 2.5`, seating a guard in solid rock. Survivable
only *because* of the teleport in (C). Once reinforcements genuinely walk, it is not.

## 2. What changed

| Part | Change | File |
|---|---|---|
| 1 | First landing hardcoded to near = 1 Bandit, deep = 2 (Wolf + Bandit); every other landing keeps Job #100's 2–3 floor and the +10%/village ramp | `Excursion/ExcursionServer` |
| 2A | `regarrisonHours` hold-off **removed** (with its now-dead `clearedAtClock` field and `ClockTime` read); interval tightened `120,240` → **`120,180`** | `Excursion/ExcursionServer` |
| 2B | `buildCampAt` **returns** its garrison record; `buildLandingSite` inserts both **after** the site is parented | `Excursion/ExcursionServer` |
| 2C | `GuardState.entryLeash` — a one-time leash covering the walk from entry to post, released on arrival | `Excursion/ExcursionServer` |
| 2D | Garrison record carries `waterEdge`/`side`; entries clamped `ENTRY_MARGIN = 20` studs inside the basin | `Excursion/ExcursionServer` |
| 3 | `DAMAGE_SCALE` `0.64` → **`0.512`** | `Enemies/EnemyDefs` |
| 4 | New `goAshore` hint + a 0.5 Hz confirmed-transition watcher | `Progression/Hints`, `Excursion/ExcursionServer` |
| — | `DEV_GARRISON_LOG` — the respawn loop had **zero** observability, which cost a whole diagnosis round | `Excursion/ExcursionServer` |

### Requirement 3 — the cuts compound, they do not add

`DAMAGE_SCALE` is now **0.8³ = 0.512**, not 0.4. Both consumers (`EnemyServer` river threats,
`ExcursionServer` camp guards) multiply by this one constant.

| Enemy | Authored | Now | at its ×1.5 phase peak |
|---|---|---|---|
| Bandit / Wolf | 10.8 | 5.53 | 8.29 (day) |
| Boar | 10 | 5.12 | 7.68 (day) |
| Crocodile | 8 | 4.10 | 6.14 (night) |
| Piranha | 4 | 2.05 | 3.07 (night) |
| RiverHippo | 20 | 10.24 | 15.36 (night) |

🔴 **This is near the floor of meaningful** — recorded in the file. Three cuts have taken every bite in
the game to just over half its authored value; a daytime Bandit now needs ~12 hits to kill a full-health
player. A fourth cut puts it under 7 damage and camp guards stop being a threat at all. If the fight is
still wrong, the lever is guard **count**, the chase-slot cap or the reinforcement rate — not this number.

### Requirement 4 — the first link in a chain that was missing one

Two hints already taught what to do with loot once you hold it. Nothing told anyone to get off the boat
and go find it — and a player who never walks inland never picks up a crate, so `carryToBoat` never fires
either and the whole economy stays invisible.

    goAshore  →  carryToBoat  →  fuelAndRepair
    (new)        (first pickup)   (first deposit)

**"GATHER SUPPLIES" / "Raid the camps inland for fuel, metal and ammo"** — copy names the resources the
first landing actually stocks (near camp 2× Gasoline, deep camp Metal + Ammo), because "gather resources"
alone does not tell anyone where to walk. It deliberately does **not** mention the guards: this is the
banner you get looking at an empty basin, and warning about enemies would read as the fight already being on.

The trigger is a **confirmed transition**, not the state "not on the boat", for three measured reasons:
jumping on deck leaves the boat by the raycast test (HRP sits ~3 studs up, a jump adds ~5) and would
teach "gather supplies" mid-river; the crash-site hub is off-boat by every test there is, so `RunStarted`
plus a `boarded` set make "exit the boat" literally true; and `PlayerCombat` puts a mid-run respawn back
on the hull, so dying re-arms the hint rather than tripping it.

## 3. Verified in Play — full evidence table in the implementation plan

- First landing: **NEAR 1 guard (0 wolf) · DEEP 2 guards (1 wolf)**.
- `[Garrison] registered near (321,1600) target=1 · deep (501,1640) target=2 · #garrisons=2` — the
  records now survive the build.
- Reinforcement fired at **timer=165 s (2.75 min)** against a rolled `nextIn` of 161.7 s; next interval
  re-rolled to 139.2 s.
- It entered at **(429,1585) — 109 studs from the camp centre**, outside a ~73-stud camp, and was found
  on arrival at **38 studs — ~2 studs from its post**. Spawn-to-post was 73 studs, over the old 55-stud
  clamp, so this is exactly the walk the clamp used to eat.
- `goAshore`: `title="GATHER SUPPLIES" sub="Raid the camps inland for fuel, metal and ammo" icon=loot`,
  live in `PlayerGui.ZoneBanner.Banner.Title`. With the run started and the player **on the deck** it
  correctly stayed `"none yet"`.

## 4. Left undone, on purpose

- **`findings/0011` — the garrison count uses a 90-stud radius while entries are at 96–114.** It matters
  *more* now: a guard genuinely walking in is uncounted for the length of the walk, not just one frame.
  It cannot be fixed by raising the number (camps are 184 studs apart, so >92 counts the neighbour's
  guards); the fix is to count by `guardState[guard].camp` membership. Out of scope here — it is the
  "too many" direction, and this job was called for the opposite.
- Reviewer's smaller notes: `entry` is dead when `spawns` is non-empty; camp guards vanish instantly
  while river creatures topple, so `KillReward` reasons about a corpse that does not exist for guards.

## 5. Two false trails worth remembering

1. **`execute_luau` tears down its Luau context**, so `task.spawn`ed observers die shortly after the call
   returns. Two in-place watchers froze and I read their stale output as "no reinforcement arrived".
   Poll from outside with fresh calls; take elapsed time from `os.time()` stored on an Instance.
2. **Teleporting a SEATED player drags the boat with them** — moving the driver's root moved the boat
   1,000 studs to the camp, so the on-boat raycast still returned true and the hint correctly did not
   fire. `Humanoid.Sit = false` first. It looked exactly like a bug in the new watcher and was not one.

Both are why `DEV_GARRISON_LOG` now exists: with the loop's own numbers in the Output, the answer took
one run instead of three.

## 6. ⚠️ One side effect of testing

The playtest **consumed the once-ever `goAshore` flag on `johnygorsky10`'s profile** — ProfileStore
reported "Roblox API services available", so it wrote through to the live DataStore. The banner will not
show again for that account, and `Profiles` has no reset. An alt account will see it.

## Sync

| Path | Synced |
|---|---|
| `sync/ReplicatedStorage/Enemies/EnemyDefs.luau` | ✅ auto |
| `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` | ✅ auto |
| `sync/ServerScriptService/Progression/Hints.luau` | ✅ auto |

All three confirmed live in the GAME place before the playtest.
