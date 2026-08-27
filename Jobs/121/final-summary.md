# Job #121 — Final summary

**Project**: `roblox.jungle` · **Status**: ✅ COMPLETE — implemented, verified in Play, closed 2026-08-27

The extraction end zone had no enemies in it. It now has a **sea gauntlet on the approach**, **three tower
grenadiers**, **ten spaced ground raiders**, and a **550 HP warlord who gates the win**.

## What shipped

| Requirement (owner's words) | Delivered | Verified in Play |
|---|---|---|
| *"lot of sea creatures next to entrace to endgame, so last camp counts"* | ×3 sea surge over the last 800 studs (z 17200 → 18000), cap **and** spawn interval | 2 → **16** concurrent (solo, day), filled in ~12 s |
| *"endgame territory has towers. Each tower must have 1 grenadier"* | 3 Rocket Men on the editor `Defender` pads, **12 s** cadence, phased 0/4/8 | 3 posted at y=62.19; 40-damage hits every ~4 s, never simultaneous |
| *"on ground 10 enemies (random wolfs or bandits)"* | 10 Wolf/Bandit, positions searched + validated, spread over the circled middle | **10/10** placed, all on flat y=18.00, 54–170 studs from the dock |
| *"but do not make that they all run towards you"* | shared chase budget of **4** of ten; the other six hold post | peak off-post = **4**, never 5, sampled across eight player positions |
| *"one bigger and scaled bandit that is boss, he has x10 health"* | `BanditBoss`: 550 HP, rig at 1.6×, Bandit-grade bite | MaxHP **550**; rig **1.600×** on all three axes; bite **5.5296** at 1.4 s |
| the sprint-past bypass (raised, then decided) | the warlord gates extraction, **fail-open** | locked with crew aboard; opens on his death; nil flag never blocks |

## Files touched

| File | Change |
|---|---|
| `sync/ReplicatedStorage/Enemies/EnemyDefs.luau` | + `BanditBoss` (550 HP, honest 6.4×9.3×4.8 box, bite unchanged) |
| `sync/ServerScriptService/Enemies/EnemyAssets.luau` | + `BanditBoss` art, `table.clone(ART.Bandit)` with `scale = 1.6` |
| `sync/ServerScriptService/EndZone/EndGarrison.luau` | **NEW** — the whole end-zone layout, tuning and `build(api)` |
| `sync/ServerScriptService/EndZone/EscapeServer.server.luau` | the boss gate (fail-open), locked-sign copy, softlock fix |
| `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` | 6 opt-in additions (approved cross-edit; all no-ops for camps) |
| `sync/ServerScriptService/Enemies/EnemyServer.server.luau` | final surge, end-zone water guard, land-spawn gate, hull exemption |
| `sync/ServerScriptService/Combat/Rocket.luau` | enemy blast cannot damage the hull inside the end zone |

**No new assets.** `WesternBandit`, `Wolf` and `ArmySoldier` were already in `AssetLibrary.Enemies`.

## The architectural decision worth remembering

The camp guard AI — `tickGuard`, `tickRocketMan`, `guardState`, `campChasers` — is **local to
`ExcursionServer.server.luau`**, and `tickGuard`'s second line destroys any `CampGuard` with no state
entry. So a rig spawned by a script in `EndZone/` is tagged, picked up by that Heartbeat on the next frame,
found stateless, and **destroyed inside 16 ms**.

The alternative was lifting ~700 lines of repeatedly-debugged AI out of that file, risking every camp on the
river to add content to the end zone. Put to the owner and declined. So:

> **ExcursionServer owns BEHAVIOUR. `EndGarrison` owns the PLACE.**

`EndGarrison` receives seven functions through an `Api` table and holds every position and number itself. It
cannot see `guardState`, `campChasers`, `garrisons` or the site-cull loop. The six additions to
ExcursionServer are all **opt-in and default to today's values**, which is the property that made the
cross-system edit acceptable — and it was checked, not assumed: at landing 1, every camp guard reads
`FireInterval=nil FirePhase=nil LeashMax=nil`, and the camp rocket man fired twice in 52 s (20 s cadence,
not 12).

### The six ExcursionServer additions

1. `extraFloors`/`addFloor` — teaches the seating raycast about the **runway**. Measured: slab top **21.11**
   against terrain **18.00**, and `groundAt` filters to `Terrain` only, so a guard chasing toward the pad
   would stand 3.1 studs sunk in concrete. Only the three `RunWay` models are registered — the clamp is
   `CLEAR_Y + BASIN_RISE` = 23, so the margin is **1.89 studs**, and `EndGarrison` now `warn`s at build if
   the runway ever rises above it (a comment cannot fail; that check can).
2. `FireInterval` attribute → the 12 s grenadier cadence.
3. `GuardState.firePhase` + `FirePhase` attribute → the anti-lockstep stagger.
4. `LeashMax` attribute → the warlord cannot be pulled off the pad (default alert leash is **250**, which
   reaches the mooring).
5. `campChaserCap`/`setChaserCap` → per-area chase budget.
6. `disposeGuards` → a teardown that releases chase slots, AI state and `AnimationTrack`s.

## Positions (measured, not authored)

Posts are **searched for and validated** rather than hardcoded, because the airfield is hand-dressed content
the owner keeps editing. Each candidate must have readable terrain with `Normal.Y > 0.7` in y ∈ [14, 26], no
visible `EndBase` part within 10 studs, and 16 studs of clearance from every other defender. The warlord's
post is reserved first so the raider search spreads around him.

```
grenadiers  (216, 18343) (209, 18256) (341, 18253)   — on the Defender pads, 44 studs up
warlord     (345, 18300)                             — 46 studs short of the pad
raiders     (301,18316) (259,18316) (259,18274) (301,18274)      inner ring r=30
            (341,18284) (327,18335) (240,18342) (223,18320)
            (249,18241) (314,18243)                              outer ring r=62
```

## Decisions the owner made along the way

Grenadier = Rocket Man at **12 s** · layout = **no new buildings, spaced in the middle** · chasers = 2, then
**4 after review** · boss = pad guard, normal bite · surge = **last 800 studs ×3** · tower chests = salvage,
then **all three → ammo after review** · boars **stop at the mouth** · grenadier friendly fire = **left in as
a tactic** · the bypass = **the boss gates extraction**.

Two of those reversed on the reviewer's evidence, which is the reviewer earning its keep.

## What the owner should know before publishing

1. **The field is lethal.** A stationary tester died in well under a minute: 4 chasers at 5.53 per 1.4 s plus
   a 40-damage shell every 4 s. That is the intent, but it is a big step up from any camp.
2. **The towers will kill the boss for you.** Friendly fire was kept deliberately. Measured: the warlord went
   **550 → 42 HP** while a player stood next to him, from his own towers' shells. 14 shells at one every 4 s
   is ~56 seconds of dodging to open the gate without landing a hit. A real tactic, and a fast one.
3. **The sea surge does not cost ammunition** — crocs move 15 against a boat top of ~30, and `CULL_BEHIND`
   deletes what you outrun. Shipped as asked; the real answer is
   [Planned/final-approach-pirate-ship.md](../../Planned/final-approach-pirate-ship.md), the owner's own next task.
4. **Mobile is unmeasured** for 16–39 concurrent sea creatures arriving while the client streams `EndBase`'s
   2136 parts. Needs the Device Emulator, which needs their Studio session.

## Not verified

- **Screenshots — GATE WAIVED BY THE OWNER (2026-08-27).** `screen_capture` timed out on every attempt in
  Play (client not rendering; Studio window not in the foreground). Offered a two-minute capture pass before
  closing; the ruling was *"close now — I'll judge it in play"*, because what an image would settle is
  whether the field LOOKS right, and that is a judgement made at the controls. So every check in this job is
  instrumented: it covers counts, positions, seating heights, damage magnitudes and fire timings, and says
  **nothing** about the look of the field. Recorded here so the gap is on the record rather than implied.
- **A full sailed run.** All end-zone testing used the admin force-start + teleport; the boat was held at
  z=17400 for the surge measurement rather than sailed there.
- **A crew of more than one.** Every number above is solo (`crewScale` 0.55). Full-crew caps are 30 day / 39
  night by formula, unmeasured.
- **Second-run chase behaviour.** The teardown is verified, but a genuine second run cannot be observed:
  `RunEnded` is never cleared by any script, so once a run ends the game expects a new server.

## Findings logged

**0039** rocket man stands 1.19 studs above the tower deck (pre-existing Job #119 pad geometry) ·
**0040** `RunKills` counts only river wildlife — no camp guard or end-zone kill has ever counted toward the
`hunter` objective · **0041** the 550 HP warlord pays the same flat 6 salvage as a boar, in a currency that
cannot be spent past z=17600.
