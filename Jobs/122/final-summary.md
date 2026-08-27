# Job #122 — Final summary

**Project**: `roblox.jungle` · **Status**: ✅ COMPLETE — implemented, verified in Play, closed 2026-08-27

Job #121's endgame played too hard at the towers. Three things changed, all **end zone only** — every river
camp is untouched by construction (they set none of the new attributes).

## The ask (owner, after playing it)

> *"reduce enemy (bazooka) fire rate. It is not survivable"*
> *"also reduce how far they shoot"*
> *"also rocketmans cant shoot me while i am at tower, now i climb on tower, and other rocket man targets me"*

## 1. Fire rate: 12 s → 36 s per man

🔴 **The number you feel is not the per-man interval — it is that divided by however many towers can see
you**, because `EndGarrison` phases them evenly across the cycle.

| Where | Before | After |
|---|---|---|
| Open field centre (3 in reach) | a shell every **4 s** | a shell every **12.0 s** *(measured: gaps 12.0, 12.0)* |
| Warlord's post (1 in reach after §2) | a shell every **4 s** | **1 shell in 44 s** *(measured)* |

So the boss fight — where the complaint came from — went from a shell every 4 s to one every ~36 s, a **9×
reduction**. Phases are now 0 / 12 / 24 s.

## 2. Reach: capped at 130 studs — and the number that mattered was not the obvious one

**`aggroRadius` (160) was never the problem.** `tickRocketMan` reads
`if alerted then R.range else aggroRadius`, `R.range` is **300**, and `alertUntil` is refreshed by *any* hit
landing within `ALERT_SPREAD` (70) for `GUARD_ALERT_SECONDS` (15). So once a firefight starts the tower crews
are alerted essentially continuously and were engaging from **300 studs across a ~400-stud airfield**.
Lowering the 160 alone would have changed almost nothing.

The new `SightMax` attribute caps **both branches**, so there is no second number to forget.

Measured in Edit — grenadiers able to engage, by candidate cap:

| | 160 | **130** | 110 | 90 | 70 |
|---|---|---|---|---|---|
| boat mooring | 2 | **2** | 2 | 2 | 0 |
| field centre | 3 | **3** | 3 | 1 | 0 |
| extraction pad | 1 | **1** | 1 | 1 | 0 |
| warlord's post | 3 | **1** | 1 | 1 | 1 |
| river mouth | 0 | **0** | 0 | 0 | 0 |

**130 is the cliff worth having**: it takes the warlord's post from three grenadiers to one, while leaving
the open middle contested by all three — which is where the fight is supposed to be. 110 is identical to 130
at every measured spot, so **90 is the next real step** if the middle is still too hot. Note the river mouth
reads 0 at every cap: the boat was never shelled on its way in.

Verified in Play at the warlord's post: `143 studs → holds`, `150 → holds`, `65 → ENGAGES`.

## 3. A grenadier will not shell a player standing on a *different* tower

Job #119's design is that you answer a rocket man by **climbing to him** — *"if you get close to enemy, you
go into close combat"* — and the shell's counter-play is that a walking player covers 64 studs in its 4 s
flight against a 30-stud blast, so **moving at all clears the ring**. On a 20×20 platform 44 studs up there
is nowhere to move to. The telegraph was unanswerable there, which made the intended counter to one
grenadier a death sentence delivered by another.

- Resolved **once per frame for all players** (`refreshTowerRiders`), not per grenadier — there are three of
  them and `tickRocketMan` runs per guard per frame.
- Detected by **asking the floor**, not by a height threshold: one short downward ray, then walk up for a
  Model named `RangerTower`. A y-threshold would also catch the runway, the pad deck, hut roofs and stumps,
  and would need a different number for the end zone (deck y=62.19) than for a camp (y=54.26, because `prop`
  scales the tower by 0.85). Same reasoning as the perched-ambusher release in `tickGuard`.
- ⚠️ Keyed on `st.tower`, so the man on **your** platform still fights you — in melee, which he already did.

**Verified, with a liveness proof so the test could fail:** standing on a platform for 40 s with another
grenadier **96 studs away (inside the 130 cap, so it would have shelled)** →
**0 blast hits**, and **29 melee hits** from that platform's own grenadier. The melee count is what proves
something was targeting the player at all; a 0/0 result would have meant a dead test, and did once — an
earlier run of this check silently measured a corpse after the run had ended.

## Files touched

| File | Change |
|---|---|
| `sync/ServerScriptService/EndZone/EndGarrison.luau` | `GRENADIER_FIRE_INTERVAL` 12 → 36; new `GRENADIER_SIGHT_MAX` 130; both stamped per grenadier; boot log now states the effective field rate |
| `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` | `SightMax` cap after the alerted/unalerted branch; `refreshTowerRiders` + the different-tower filter in the acquire loop; the per-frame pass hooked into the guard Heartbeat |

Two new opt-in levers (`SightMax`, plus the tower filter which is universal), consistent with Job #121's six.

## Camps: untouched, and checked rather than assumed

Verified in Play at landing 1: `CAMP grenadier: FireInterval=nil SightMax=nil`. Camps keep
`CampDefs.TOWER.rocketMan.fireInterval` = 20 and sight 160 / 300.

⚠️ **One camp-side behaviour change, deliberate and worth naming:** the tower filter is universal, not
end-zone gated. A landing site has two towers and a rocket man on only the deep one, so if you climb the
**near, unmanned** tower the deep camp's grenadier used to shell you there. It no longer will. That is the
same unfairness the owner reported, in the only other place it can occur, and gating it to the end zone would
have meant the rule being true in one place and not the other.

## What the owner should know

**Melee is now the dominant damage source, not the bazooka.** Measured at the field centre: 44 s produced
**3 blasts and 126 melee hits** — 126 × 5.53 ≈ 697 damage, about 16 dps from the 4 chasing raiders plus the
boss, against a 100 HP player. Standing still in the open middle kills you in roughly six seconds and the
shells are now a minor part of that. If the endgame still reads as unsurvivable, the lever is
`RAIDER_CHASERS` (4) or `EnemyDefs.DAMAGE_SCALE`, **not** the grenadiers.

## Not verified

- **Screenshots** — same as Job #121: `screen_capture` times out because the Studio window is not in the
  foreground. All checks here are instrumented.
- **Solo only**, and with the tester pinned in place (unable to retreat), which is the worst case for melee
  pressure and not how the fight actually plays.
