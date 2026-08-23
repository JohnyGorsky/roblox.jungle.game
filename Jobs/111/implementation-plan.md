# Job #111 — Implementation plan

**Project**: `roblox.jungle` · **Status**: implemented & verified in Play

## The problem

The run had no ending. `RiverBootstrap.placeEnd()` planted a gold Neon `FinishLine` bar across the
channel at `END_DISTANCE`; it did not collide, nothing existed behind it, and `RunServer` won the run
on `BoatDistance >= END_DISTANCE`. So the crew crossed a glowing wall into unwritten world and fell to
their deaths behind a VICTORY screen. Job #110 built the end zone; this job makes arriving there mean
something.

## Design (agreed with the user)

| Question | Decision |
|---|---|
| What wins the run | The crew is **extracted** from a pad at the plane, not a distance crossed |
| Waiting on the pad | **Standing on it protects you** — otherwise a trickling crew is picked off one at a time and a 6-player extraction deadlocks |
| Straggler / AFK | **Hold-to-launch** once a majority of the living crew is aboard — mirrors the lobby launch pads |
| Pad look | A **part-for-part replica of the lobby launch pad**, in gold (STYLEGUIDE §4 = progression) |
| Results screen | Unchanged |

## Changes

| File | Change |
|---|---|
| `ServerScriptService/EndZone/EscapeServer.server.luau` | **NEW.** Owns the pad, the occupancy loop, the invincibility and the win |
| `ServerScriptService/River/RiverBootstrap.server.luau` | `placeEnd()` and its caller deleted |
| `ServerScriptService/RunServer.server.luau` | Win arm is now `Workspace.EscapeReached`; `DEV_WIN_DISTANCE` removed; `winDistance()` → `riverLength()` (reward denominator only); **on a win, credit the full river** |
| `StarterPlayer/.../UI/RunClient.local.luau` | Results panel is `dismissable = false` |
| `ReplicatedStorage/UI/Components.luau` | `PanelOptions.dismissable` added (defaults true) |
| `StarterPlayer/.../UI/DownedHud.local.luau` | INVULNERABLE chip hidden once `RunEnded` |

## Key decisions

- **Reuse `InvincibleUntil`, do not invent a second flag.** Both damage paths (`EnemyServer`
  target selection, `ExcursionServer.tickGuard`) already read it, and PlayerCombat's comment states the
  rule: every path that damages a player must check it. Two guards keep the pad and the revive grace
  from fighting: never *shorten* someone else's deadline (take the max), and only *clear* a deadline we
  wrote (compare the exact stamped value).
- **Find the pad marker by name.** `Workspace.EndBase.Objects.Plane.Escape` is editor-placed; the pad
  geometry is generated at runtime so the hand-built zone stays pure content.
- **Downed players count as living.** They are not out yet; the majority force-launch is the release
  valve for a crew that cannot revive them in time.

## Bugs found and fixed during the work

1. **Distance credited from the boat, not the run** — a successful extraction filed `distance=17867
   zone=3`, costing 50 River Score and failing the weekly *"Reach Zone 4 in a run"* objective the same
   run had just earned. The win no longer implies the boat crossed the mouth. Fixed by crediting
   `math.max(boatDistance, endDist)` on a win.
2. **The results screen was dismissable** — X and tap-outside closed it, leaving the player walking a
   finished world (invincible, boat gone) until the auto-teleport. Found by the user in playtest.
3. **Sign wrapped, then over-corrected** — 11 studs wide wrapped "EXTRACTING…" across two lines;
   24 made one short line fill the whole box. Fixed with 18 studs **plus** a `MaxTextSize` cap.
4. **Pad buried in the runway** — the ground probe filtered to `Workspace.Terrain`, but the marker sits
   on the RunWay slab 3 studs above terrain, so the pad seated at 18.0 with only its ring showing. The
   probe now casts against everything except the marker.
5. **Walking surface too high** — first build put the deck 2.4 studs up, the limit of a Humanoid step.
   Replicating the lobby's real stack geometry puts it at 1.9.

## Verification (Play, GAME place)

Negative control first, so the check could fail:

- Run live, player 18,600 studs from the pad, 8 s → `EscapeReached` false, `RunEnded` nil,
  `InvincibleUntil` nil, sign `0/1 aboard`. ✅
- Step onto the pad → `InvincibleUntil` at 0.22 s, `EscapeReached` at 0.22 s, `RunEnded` at 0.45 s,
  `RunResult = win`, player alive. ✅
- `[Run] ENDED — WIN | distance=18000 (boat at 0) zone=4 gold=+10 survivors=1` — full river credited
  with the boat nowhere near the mouth. ✅
- Results panel: `Close.Visible=false`, `Scrim.Active=false`, poking Close leaves it open. ✅
- No INVULNERABLE chip behind the results. ✅
- Pad base underside 21.11 == RunWay surface 21.11. ✅
- `luau-analyze` clean on all six files (canary-tested: a deliberate type error exits 1).

## NOT verified — needs 2+ players

Both multi-crew paths are solo-untestable and are reasoned-about only:

- **protection while waiting** — with one player, `1/1 aboard` extracts instantly, so the pad's rolling
  `PAD_GRACE` stamp never gets exercised as "protected while waiting".
- **majority hold-to-launch** — `canForce` requires `total > 1`, so the prompt never enables solo.

A Local Server test with 2 players would cover both.
