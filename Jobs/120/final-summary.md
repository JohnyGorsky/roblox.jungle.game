# Job #120 — final summary

**Project**: `roblox.jungle` · GAME place (`sync/`) only
**Status**: ✅ implemented and verified in Play

## The request

> new task. Players dont know that you need to tie boat at piers. So reuse existing signs, put sign on
> pier, and put info - Tie Boat, and set action on that sign. Also rope must go from sign to boat.
> visible. Test it

## What was actually wrong

The tie feature was never missing — the prompt's `ActionText` has read `"Tie Boat"` since Job 010. Three
things made it undiscoverable, all measured in Play rather than reasoned about:

1. **The trigger had no body.** It hung off a `TieSpot` Attachment on `Deck`, and `Deck` has been
   `Transparency = 1` since Job #077. The bubble floated over empty air at the centre of a 32-stud quay.
2. **The rope was anchored inside the pier.** `a1.WorldPosition = pos + (0, 2, 0)` = world Y 14.0. The
   pier's plank surface measures **15.08**. The "visible rope" ran into the decking.
3. **The rope's other end was inside the boat**, and it was a hairline. `a0` had no `Position` at all, so
   it started at the hull's geometric centre; `Thickness` was 0.15 against the 0.45 the game's other
   mooring ropes use.

## What was built

### New — `sync/ServerScriptService/World/WorldSign.luau`

`buildShopSign` lifted out of `ExcursionServer` into a shared module, so the pier stands the **same**
sign the trading posts do rather than growing a second copy: 8×3×0.4 WoodPlanks board, two 0.5×7×0.5
posts at ±3.4, `SurfaceGui` on both faces at `PixelsPerStud 50` / `MaxDistance 320`, `Theme.font.sign`
(SpecialElite), `Theme.color.cream` on `Theme.color.stroke`. Adds two things the pier needed:

- `blockRaycasts` (default **true**, i.e. camp behaviour unchanged). `DockServer` passes **false** —
  `findings/0023` is this exact bug with foliage, and `GunServer`/`WeaponServer` raycast with
  `FilterType = Exclude` over only `{ boat, character }`, so a `CanQuery` board at the water's edge
  eats rounds fired from a moored boat toward the bank.
- `WorldSign.setText` — because a prompt's `ActionText` is state and a painted board is not.

`ExcursionServer.buildShopSign` is now a thin wrapper over it. **Verified in Play that camp signs are
unchanged**: 8×3×0.4, colour (128,97,66), WoodPlanks, `CanCollide=false`, `CanQuery=true`, both faces
"TRADING POST" SpecialElite pps=50 maxDist=320 TextScaled, `ShopPrompt` on the board at reach 20.05, two
sibling `Post`s.

### `DockServer.server.luau`

| | Before | After |
|---|---|---|
| Sign | none | `TIE BOAT` board on the pier, 2 studs toward the channel at mid-length |
| Sign facing | — | angled ~45° **into the approach**, not square to the bank |
| Sign footing | — | **measured** per sign; post feet land within **0.000** of the deck |
| Prompt host | invisible `Deck` attachment | the sign board (exactly one prompt on the dock) |
| Prompt reach | 18 | 24 |
| Rope dock end | `pos + (0,2,0)` = Y 14.0, inside the pier | foot of the nearer signpost, deck + 1.0 |
| Rope boat end | hull local origin (inside the boat) | raycast onto the boat's **visible skin** |
| Rope visual | `RopeConstraint.Visible` hairline, 0.15 | 6 Fabric cylinder segments, 0.45, with sag |
| Board on tie | — | repaints `TIE BOAT` ⇄ `UNTIE BOAT` |

## Two defects found and fixed during the work

**The sign faced the wrong way (caught by a Play capture, not by reasoning).** Square to the bank, an
8×3×0.4 board is edge-on to a driver coming upriver and stays a thin dark sliver until the boat is
already level with the pier — i.e. until the player no longer needs telling. The river runs along
`+tangent`, so the board now faces `(across − tangent).Unit`, splitting the difference between "out at
the channel" and "back down the river". It reads from ~60 studs downstream and is still legible moored.

**The rope was three separate kinds of invisible**, and the first pass only fixed one of them. Fixing
`a0` to the hull *collision box* rim (6.5) was still 3.75 studs inside the boat: `Hull` is a 14-wide
collision box but the boat's visible geometry is 17.2 wide, with `ArmoredHullL1` reaching 10.25 studs
out. It is now raycast onto whatever the boat actually presents, which stays correct through any future
module or paint change. The `RopeConstraint` is kept as the tether but set `Visible = false`; the
built cylinders are the picture.

## 🔴 Latent bug found, logged, deliberately NOT fixed — `findings/0037`

**`measureDeckY` in `buildPier` is dead code.** It raycasts against the pier while the dock model is
still unparented (`buildDock` does not parent it until the end), so `Workspace:Raycast` cannot hit it,
`measured` is always `nil`, and the `DECK_Y` correction never runs.

Evidence: the live pier's bounding-box min Y is **8.99999952**, exactly the provisional seat
`WATER_Y − 3` = 9. The plank surface probes at **15.08** against the `DECK_Y` = 16 it is meant to match —
every river pier stands 0.92 studs low.

Not fixed here because raising every pier moves where the boat sits and where players stand, which is a
world change this job was not asked to make. Job #120 measures the deck **after** parenting instead, so
the sign seats correctly either way.

## Verification (in Play — GROUND-RULES §7)

| Check | Result |
|---|---|
| Sign seated on the measured deck | **PASS** — both post feet delta **0.000** vs the deck under them |
| Readable on approach | **PASS** — "TIE BOAT" legible from the water (`approach_text_closer`); the pre-fix facing is kept as `approach_readability` for contrast |
| Sign never collides | **PASS** — `CanCollide = false` |
| Sign never blocks raycasts | **PASS** — `CanQuery = false` |
| Exactly one prompt on the dock | **PASS** — 1, parented to `TieSign` |
| Tie via the real prompt path | **PASS** — `InputHoldBegin/End` → `Tied = true`, `DockMoor` + `DockMoorPoint` created |
| Rope visible | **PASS** — 6 segments, 5.18-stud span, Y 15.6–16.2 (water 12, deck 15.08); `final_sign_and_rope` |
| Board tracks state | **PASS** — `TIE BOAT` → `UNTIE BOAT` → `TIE BOAT` |
| Untie via `RequestUntie` (seated-driver path) | **PASS** — all 11 assertions, incl. 0 rope segments, no `RopeConstraint`, no `DockMoor`, no `DockMoorPoint` |
| Camp signs unchanged | **PASS** — every property identical |
| Analyzer | clean (exit 0), and **proved able to fail** first — a deliberate type error reported `Expected 'number', but got '(Part, string) -> ()'`, which also confirms the sourcemap resolves the new module |

**A false alarm worth recording**: the tie appeared to be broken for several rounds — the prompt fired
and nothing happened. It was correct: the river current had swept the boat **246 studs** downstream and
the server's `REFUEL_RANGE` (65) gate was properly refusing. The test harness now pins the boat at a
realistic berth for the duration of a tie test. Also note a rider seated on a per-frame-teleported
assembly gets ejected — pin with nobody aboard.

## Independent review (GROUND-RULES §8)

A reviewer was given only the symptom and the repo, never the approach. It supplied the `CanQuery`
hazard, the `ActionText`-vs-painted-board contradiction, the rope thickness/`a0` problem, and the
reachability arithmetic behind 18 → 24 — four things that would otherwise have shipped.

## Not fixed here — `findings/0038`

The reviewer's strongest point, and it is not a signage problem: **nothing requires the boat to be
tied.** `GAME.md:232` says "Only once it's tied can the crew get out"; no such gate exists in code. The
penalty for not tying is also invisible (`BoatStatusCard` has no tied/untied readout), and
`RiverProgress` only pins *landing* docks, so half the piers are unmarked. This job makes the affordance
discoverable; it cannot create a reason to use it. Logged as a design call.

## Files changed

- `sync/ServerScriptService/World/WorldSign.luau` — **new**
- `sync/ServerScriptService/World/DockServer.server.luau`
- `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` — delegation only
- `findings/0037`, `findings/0038` — **new**
