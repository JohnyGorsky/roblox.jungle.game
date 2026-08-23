# Job #102 — Implementation plan

**Project**: `roblox.jungle` · **Status**: in progress

## Decisions taken (via wizard, 2026-08-23)

| # | Question | User's call |
|---|---|---|
| 1 | Guard count at the first landing | **3 total** — near camp **1** (Bandit), deep camp **2** (Wolf + Bandit). Reason given: *"first time players just confused when 2 attack same time"* |
| 2 | Scope of that count | **First landing only.** Later villages keep the existing +10%/village escalation |
| 3 | Scope of the 20% damage cut | **All enemies** — the one global `DAMAGE_SCALE` |
| 4 | Go-ashore hint trigger | **First time the player steps off the boat, once ever** (persisted on the profile) |

## Part 1 — First landing = 3 guards ✅

`ExcursionServer.buildLandingSite`. Job #100's `GARRISON_MIN/MAX = 2, 3` floor rolls **2–3 per camp**,
and a landing builds **two** camps — so the first time anyone ever goes ashore they meet **4–6** guards.

Fix: a flat override for `index == 1` (`nearGuards = 1`, `deepGuards = 2`) placed *after* the existing
scaling, so the 2–3 floor keeps applying at every other landing. This is an on-ramp, not a rebalance.

- `index` is the **dock** ordinal; only odd docks are landings (`RiverData:319`), so `index == 1` is
  exactly the first landing. Deliberately not written as `tier == 1`, which is also true for dock 2.
- The Wolf/Bandit mix needs no change: `buildCampAt` gives `KIND.near` `wolves = 0` (all Bandit) and
  `KIND.deep` `math.max(1, math.floor(2/3)) = 1` (one Wolf, one Bandit) — which is what was asked for.
- Side effect, intended: this also sets each camp's respawn `target`, so the first landing's camps
  refill to 1 and to 2 rather than back up to a wall.

## Part 3 — Global bite damage −20% ✅

`EnemyDefs.DAMAGE_SCALE` `0.64 → 0.512`. The cuts **compound** (0.8³), they do not add — both consumers
(`EnemyServer:343` river threats, `ExcursionServer:1883` camp guards) multiply by this one constant, so
one edit covers every bite in the game.

| Enemy | Authored | Now | ×1.5 phase peak |
|---|---|---|---|
| Bandit / Wolf | 10.8 | 5.53 | 8.29 (day) |
| Boar | 10 | 5.12 | 7.68 (day) |
| Crocodile | 8 | 4.10 | 6.14 (night) |
| Piranha | 4 | 2.05 | 3.07 (night) |
| RiverHippo | 20 | 10.24 | 15.36 (night) |

Recorded in the file: this is near the floor of meaningful. A fourth cut puts a daytime Bandit under 7
against a 100 HP player; if the fight is still wrong after this, the lever is guard **count**, the
chase-slot cap or the reinforcement rate — not this number.

## Part 4 — "Gather supplies" hint on first going ashore ✅

The `Hints` system (Job #098) already existed and already had the right shape (one-shot, persisted on
`ProfileConfig.seen`, rendered by `ZoneBanner` via the `HintBanner` remote). It was missing the **first
link in the chain**: two hints taught what to do with loot once you hold it, nothing told a player to
get off the boat and go find it.

    goAshore  →  carryToBoat  →  fuelAndRepair
    (new)        (first pickup)   (first deposit)

- New `DEFS.goAshore` in `Hints.luau`: **"GATHER SUPPLIES" / "Raid the camps inland for fuel, metal and
  ammo"**, `loot` icon. Copy names the resources the first landing actually stocks (near camp 2× Gasoline,
  deep camp Metal + Ammo) — "gather resources" alone does not tell anyone where to walk.
- Trigger: a 0.5 Hz watcher in `ExcursionServer`. It fires on a **confirmed transition**, not on the
  state "not on the boat", because:
  1. **Jumping on deck leaves the boat by this test.** The on-boat check is a raycast 8 studs down from
     the HumanoidRootPart (copied from `StagingServer.isOnBoat:234` — a bounding-box test counts people
     standing on the pier). HRP sits ~3 studs above the feet and a jump adds ~5, so a player bouncing on
     deck mid-river reads as ashore. Hence `ASHORE_CONFIRM = 2.0 s` continuously off.
  2. **The crash-site hub is not the boat.** `Workspace.RunStarted` gates the loop, and a `boarded` set
     additionally requires the player to have actually stood on the boat — so "exit the boat" is
     literally true rather than "is not currently on the boat".
  3. **Dying is not disembarking.** `PlayerCombat:86` puts a mid-run respawn back on the hull, so death
     re-arms this rather than tripping it.

## Part 2 — Reinforcements never arrive ✅ (pending Play proof)

`DayNightServer` runs 13 daylight hours over 480 real seconds → **36.9 real seconds per game hour**
(16.4 s/h at night). A **cleared** camp (`alive == 0` — exactly the reported case) had to pass *two*
gates in series, and they were never added up:

1. `regarrisonHours` of **game** time — 7 h near / 9 h deep = **4.3 / 5.5 real minutes** in daylight;
2. *then* `g.timer` started accruing toward `GUARD_RESPAWN_MIN..MAX` = **120–240 real seconds**.

| | first reinforcement after a full clear | after this job |
|---|---|---|
| Near camp, cleared by day | 6.3 – 8.3 min | **2 – 3 min** |
| Deep camp, cleared by day | 7.5 – 9.5 min | **2 – 3 min** |
| Requirement | 2 – 3 min | ✔ |
| Full game day, for scale | 11.0 min | |

The loop's own header claimed "reinforcements arrive every ~2–3 REAL minutes" the whole time — the
hold-off standing in front of it was simply never counted in that claim.

**Changes**

- `GUARD_RESPAWN_MIN, GUARD_RESPAWN_MAX` `120, 240` → **`120, 180`**, so the spread is the 2–3 minutes
  that was asked for and not 2–4.
- **Job #100's game-clock hold-off removed**, along with the now-dead `regarrisonHours` /
  `clearedAtClock` `Garrison` fields and the `ClockTime` read that fed them. The intent behind it ("a
  camp you cleared stays cleared for a while") is dropped *deliberately*: the user has given an explicit
  number that contradicts it, and their words are the specification. A comment records that anything
  like it, if reinstated, stacks **in front of** the respawn timer rather than replacing it — which is
  the exact mistake that produced this bug.

**Not changed** — the "come from the side to their position, attack if I am near" half already exists
and is correct: reinforcements spawn at `CampLayout.spawns` (beyond the perimeter, at the gaps), are
given their post as `postPos` so `tickGuard` walks them in, and aggro through the normal guard AI. The
bug was only that the spawn never fired.

**Deliberately left alone** → logged as `findings/0011`: the garrison count uses a 90-stud radius while
reinforcements spawn at 96–114 studs, so one in transit is not counted. It cannot be fixed by raising
the radius (near and deep camps are 184 studs apart, so >92 starts counting the neighbour's guards); the
right fix is to count by `guardState[guard].camp` membership. That is the *opposite* symptom to the one
reported and does not belong in this job.

## Independent reviewer's report — reconciled

The reviewer (given only the symptom, never my theory) **confirmed the hold-off arithmetic** as the
dominant cause and added a sharper reading of it, plus **two real defects I had missed**. All three were
verified against the code before acting on them.

### Confirmed, with a better explanation of "a whole day"

Dusk is 19:00 and dawn 06:00, so a full night is only **180 real seconds**. A player who clears the camp
in the afternoon and watches the sun go down and come back up has waited roughly **3–5.5 real minutes** —
*inside* the 7-hour hold-off, or barely past it. "I waited a whole in-game day" and "nothing ever came"
are both literally true at once. That is the missing piece of the report.

The reviewer also ruled out, by reading rather than assuming: `ClockTime` never being written (it is,
`DayNightServer:80,86`); the hold-off window wrapping shut forever (`g.timer` carries across windows);
the loop thread dying on a throw; dead guards keeping `alive > 0`; `target == 0`; deep-camp guards
counted into the near camp; the site being culled underfoot.

### NEW — a garrison record can be reaped at birth, and only ever at the near camp ✅ fixed

`buildCampAt` inserted into `garrisons` while the site model was still **detached** —
`model.Parent = campsRoot` is the last line of `buildLandingSite`. The respawn loop's first gate drops
any record whose `g.parent.Parent` is nil, and the build **yields** in that window (`settleTerrain()`
waits two frames inside the *deep* camp's build). If the 5-second tick resumes in there, the **near**
camp's record is removed and that camp never re-garrisons again for the whole run — silently.

The asymmetry is the tell and it matches the report exactly: the deep camp's record is created after the
last yield, so **only the near camp can lose one**. Roughly 0.7% per site at 60 Hz, up to ~8% if
world-gen frames stretch — which they plausibly do during a 400-stud basin carve.

**Fix**: `buildCampAt` now *returns* its record; `buildLandingSite` inserts both **after** the site is
parented. Gate 1 survives as the safety net it was meant to be, with no window to fire in.

### NEW — reinforcements never actually walked in ✅ fixed

Requirement 2 says *"they come from side to camp to their position"*. Job #100 built two of the three
parts — spawn beyond the perimeter, `postPos` inside — but `tickGuard` clamps every step to
`GUARD_LEASH = 55` studs from `st.anchor`, and for a reinforcement the anchor **is its post**. Entries
are 96–114 studs from the camp centre, posts 35–65, so spawn-to-post is routinely well over 55 — and the
clamp is not a speed limit, it is a hard reposition. On the guard's **first Heartbeat** it was moved
40–120 studs onto the 55-stud sphere around its post. It appeared at the barricade; nobody ever saw it
approach.

**Fix**: `GuardState.entryLeash` — a reinforcement carries a one-time leash wide enough for the walk,
released the moment it is inside the normal one. Buys exactly one trip, never a permanently roomier guard.

### NEW — entry points can land in the river or inside the rock wall ✅ fixed

`CampLayout` places entries at `radius + 26..40` with no idea what is out there. The near camp is 120
studs inland, so a waterward entry lands ~6 studs from the river; the deep camp is 300 inland, so an
inland entry lands ~414 — **inside the far wall**, which spans 400–430. `groundAt` does not save it: it
rejects the wall-top hit and falls back to `CLEAR_Y + 2.5`, seating a guard in solid rock. This was
survivable only *because* of the teleport above; once reinforcements genuinely walk, it is not.

**Fix**: the garrison record carries `waterEdge`/`side`, and entries are clamped to `ENTRY_MARGIN = 20`
studs inside both. Only the inland axis needs it — entries reach ±114 in Z against side walls at ±215.

### Reviewer findings NOT acted on

- **`GUARD_COUNT_RANGE` (90) < spawn radius (96–114)** — already logged as `findings/0011`. It now
  matters *more*, since a guard genuinely walking in is uncounted for the length of the walk rather than
  for one frame. Still not fixable by raising the number (camps are 184 studs apart); the fix is to count
  by `guardState[guard].camp` membership. Left out of this job on purpose — it is the "too many"
  direction, and this job was called for the opposite.
- **Zero observability in the respawn loop** — no `print`/`warn` anywhere in it, which is why every
  number here had to be derived from constants. Worth its own job.
- **Hold-off unit was run-dependent** — moot, it is gone.
- **`entry` is dead when `spawns` is non-empty**; **guards vanish instantly while river creatures topple**
  (`KillReward` reasons about a corpse that does not exist for guards). Cosmetic / separate.

## Verification (GROUND-RULES §7)

- [x] `tools/luau-analyze.sh` clean on all four changed files — **and confirmed the check can fail**
      (a deliberately mistyped scratch file reports `TypeError`, so "clean" means something)
- [x] Diff reviewed hunk by hunk; CRLF line endings preserved to match the rest of the tree
- [ ] 🔴 **Play verification blocked**: the Studio instance open is the **LOBBY** place
      (`ReplicatedStorage.LobbyConfig`, `ServerScriptService.LobbyServer`). Every change in this job is
      in the **GAME** tree (`sync/`). Needs the game place loaded.
- [ ] Play: first landing has exactly 1 + 2 guards
- [ ] Play: clear the near camp, time the first reinforcement on a stopwatch — expect 2–3 min.
      **This test can fail**: if nothing arrives inside ~4 minutes, the timing diagnosis is wrong and
      there is a hard blocker, because the hold-off no longer exists to explain it.
- [ ] Play: the reinforcement enters from outside the perimeter and engages a nearby player
- [ ] Play: `goAshore` banner fires on stepping off the boat, and *not* at the crash-site hub
- [ ] Independent reviewer's report reconciled against the above

## Notes

- `sourcemap.json` shows as modified: `tools/luau-analyze.sh` regenerates it via `rojo sourcemap` on
  every run. Not a hand edit.
