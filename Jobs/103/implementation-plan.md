# Job #103 — Implementation plan

**Project**: `roblox.jungle` · **Place**: GAME only (`sync/`) · **Status**: plan drafted, reviewer running

> *"when i revive i must be full health not just half (with robux), also i must be invincible for 10
> seconds. Now you respawn by robux and instantly killed."*

## Decisions taken (via wizard, 2026-08-23)

| Question | User's call |
|---|---|
| Which revive gets it | **Both** — the paid Robux self-revive *and* the teammate bandage revive come back at full health with the 10 s grace |
| What the grace blocks | **All damage**, with a **visible indicator** so the player knows to move |

## Why "instantly killed" happens

`PlayerCombat.revive()` (`:105-121`) brings the player back **in the exact spot they went down**, with
`HP = REVIVE_HP + 2.5 × medic` = **50**, and nothing else changes. The enemies that downed them are still
standing over them, still aggroed, and their bite cooldowns have been running the whole time they were
down — so the first bite can land on the same frame they stand up. At 50 HP against a camp guard that is
a survivable but panicky situation; the real problem is that there is **no window in which to move**.

## The player damage surface (my own read — the reviewer is auditing this independently)

Player health is the character attribute **`HP`**, not `Humanoid.Health` (`HealthHud:124` is emphatic
about it). `Humanoid.Health` is touched exactly once, at `PlayerCombat:190`, to kill on bleed-out.

Writes to a **player's** `HP` across the whole game tree:

| Site | What it is | Direction |
|---|---|---|
| `ExcursionServer:1996` | camp guard bite | **damage** |
| `EnemyServer:348` | river creature bite (`applyBite`) | **damage** |
| `PlayerCombat:129` | `enterDowned` sets HP 0 | state, not damage |
| `PlayerCombat:93` | spawn at `MAX_HP` | heal |
| `PlayerCombat:112` | revive | heal |
| `RoleServer:92` | Medic station regen | heal |
| `CampfireHeal:128` | resting at a fire | heal |

So there appear to be exactly **two** paths that can hurt a player, plus the bleed-out death. Everything
else that takes damage in this game (`ObstacleServer:51`, `EnemyServer:357`) damages the **boat**, not the
person. ⚠️ Not committing to this list until the reviewer's audit lands — a missed path is a literal hole
in the invincibility, which is the one failure mode that matters here.

## Planned changes

1. **Full health on revive** — `PlayerCombat.revive()`: `HP = MAX_HP` for both routes.
2. **`REVIVE_GRACE = 10`** — `revive()` stamps `char:SetAttribute("InvincibleUntil", os.time() + 10)`.
   `os.time()` (wall clock) deliberately, matching `BleedOutAt` (`:178`) and for the same reason: the
   **client** has to render a countdown from it, and `os.clock()` is per-process and means nothing there.
3. **Enforce at every damage site** — a guard clause at `ExcursionServer:1996` and `EnemyServer:348`
   (pending the reviewer's list). Enforced at the *damage* sites rather than by reverting the attribute
   afterwards, because a revert would fight the two heal loops writing to the same attribute.
4. **Visible indicator** — a countdown on the HUD plus a character highlight in `Theme.color.gold`, so
   the 10 s reads as "run now" rather than passing unnoticed. Gold because that is the progression/-
   positive accent; red would read as danger.

## ⚠️ Consequence to flag: the Combat Medic skill loses one of its two effects

`revive()` currently grants `REVIVE_HP + 2.5 × medic` — the Combat Medic skill's whole point on this path
is *"revived ally comes up with more HP"* (`:110-112`). At full health there is nothing left for it to
add, so that half of the skill becomes dead. Its other effect — a shorter revive hold (`:151-156`) —
still works. This follows directly from the user's "both revives, full health" call and is not a mistake,
but it should not happen silently: if the skill is being sold or levelled on that promise, its
description needs revisiting, or the skill should grant grace **seconds** instead of HP.

## Verification (GROUND-RULES §7) — must be done in PLAY

- [ ] `tools/luau-analyze.sh` clean on every changed file
- [ ] Go down at a camp, revive → HP is **100**, not 50
- [ ] Enemy adjacent and attacking: HP stays at 100 for the full 10 s. **This test can fail** — if any
      bite lands during the window, a damage path was missed.
- [ ] Damage resumes normally at second 11
- [ ] The indicator appears, counts down, and disappears
- [ ] Paid Robux route and teammate-bandage route both verified (the paid route goes through
      `grantSelfRevive` → `pendingRevive[player]` → the same closure, so both should behave identically —
      confirm rather than assume)
