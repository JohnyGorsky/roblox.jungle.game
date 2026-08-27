# Implementation Plan — Job #122

**Project**: `roblox.jungle`
**Created**: 2026-08-27
**Status**: ✅ IMPLEMENTED & VERIFIED IN PLAY — see [final-summary.md](final-summary.md)

## The ask (owner, verbatim, after playing Job #121)

> reduce enemy (bazooka) fire rate. It is not survivable
> also reduce how far they shoot
> also rocketmans cant shoot me while i am at tower, now i climb on tower, and other rocket man targets me

## Decisions taken at intake (via wizard, 2026-08-27)

| # | Question | Decision |
|---|---|---|
| 1 | How far to slow the fire rate | **36 s per man → a shell on the field every 12 s** (was 12 s per man → every 4 s) |
| 2 | Does it apply to river camps too | **End zone only.** Camps have ONE tower each so they already only saw a shell every 20 s; the unsurvivable part was three at once |

Two further calls were made from measurement rather than by asking again, and both are stated so they can be
overridden with one number:

| # | Call | Reasoning |
|---|---|---|
| 3 | Reach capped at **130**, on BOTH the alerted and unalerted branch | The engagement number that was actually hurting is the **alerted `R.range` = 300**, not `aggroRadius` = 160 — see the measured table in the summary. 130 is the only cap that changes anything at the warlord's post; 110 is identical to it everywhere; 90 is the next real step |
| 4 | The tower filter is **universal**, not end-zone gated | A landing site has two towers with a grenadier on only one, so climbing the unmanned near tower had the same defect. Gating it would make the rule true in one place and false in the other |

## Verification — RESULTS

Every check ran in **Play**. The bazooka blast is 40 damage and a bite is 5.53, so the two are separated by
magnitude in one HP-watching loop.

| # | Check | Result | What failure would have looked like |
|---|---|---|---|
| 1 | Attributes land on the end-zone grenadiers | `FireInterval=36 FirePhase=0 SightMax=130`, `…FirePhase=12…`, `…FirePhase=24…` | a missing attribute, or phases still 0/4/8 |
| 2 | Field rate in the open middle | 3 blasts in 44 s at **t=16.0 / 28.0 / 40.1** — gaps **12.0 s and 12.0 s** | ~4 s gaps (interval not applied), or one 120-damage tick (phases lost) |
| 3 | Reach cap at the warlord's post | `143 → holds`, `150 → holds`, `65 → ENGAGES`; **1 blast in 44 s** | 3 engaging, i.e. the cap not applied to the alerted branch — the branch that was doing the damage |
| 4 | 🔴 No shelling a player on another tower | 40 s on a platform with another grenadier **96 studs away, inside the cap**: **0 blasts** | any blast — the platform is 20×20 and 44 up, so the ring is unanswerable there |
| 4b | …and that test could FAIL | **29 melee hits** from that platform's own grenadier in the same 40 s | 0 melee AND 0 blasts = a dead test measuring nothing. This happened once (an earlier run measured a corpse after the run had ended) and is why the liveness count is part of the check |
| 5 | Blasts still happen off-tower | the control in check 2: 3 blasts at the field centre | 0 there too, which would have meant check 4 proved nothing |
| 6 | **Camps untouched** | landing 1: `CAMP grenadier: FireInterval=nil SightMax=nil` | either attribute set on a camp guard |
| 7 | Analyzer clean, and able to fail | 0 diagnostics full-tree; it **caught** a real strict-mode error in the new comparison (`Types Model and nil cannot be compared with ~=`) before it ran | silence from a check not reading the file |

### Not met

- ❌ **Screenshots** — `screen_capture` times out (Studio window not in the foreground), same as Job #121.
- ⚠️ **Solo, and pinned in place.** The tester was held on the spot, which is the worst case for melee
  pressure and not how the fight plays.

## Found while measuring

**Melee is now the dominant damage, not the bazooka.** 44 s at the field centre: 3 blasts vs **126 melee
hits** (~16 dps from 4 chasing raiders plus the boss). If the endgame still reads unsurvivable the lever is
`RAIDER_CHASERS` or `DAMAGE_SCALE`, not the grenadiers. Recorded in the summary.
