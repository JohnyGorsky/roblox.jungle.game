# Final Summary — Job #061: Run objectives (per-run bonus goals)

**Project**: `roblox.jungle` · **Completed**: 2026-07-19 · POC · Review decision #4 ("we need run objectives").

## What
Per-run objectives that give the crew bonus **Salvage** (in-run) + **River Score** (+ **Gold** for finishing).
A live HUD panel shows them with progress + a ✓ when done.

## Implementation
- **`ReplicatedStorage/Objectives/ObjectiveDefs.luau`** (new) — catalog (4 for POC): Reach The Rapids ·
  Survive a night on the water · Take down 15 threats · Complete the run. Each carries salvage/score/gold.
- **`ServerScriptService/Progression/ObjectiveServer.server.luau`** (new) — tracks from replicated run state
  (`Zone`, `Phase`, `RunKills`, `RunResult`), completes once, rewards **all crew**, publishes
  `ObjDone_<id>` / `ObjProg_<id>` Workspace attributes, and **resets on `RunStarted`**.
- **`EnemyServer`** — increments `Workspace.RunKills` when an enemy dies (drives the "15 threats" objective).
- **`StarterPlayer/.../UI/ObjectiveHud.local.luau`** (new) — top-right panel, live progress, green ✓ on done;
  shown only during a run. Added to `IntroHudGate` so it's hidden during the intro.

## Verified (live in Studio)
- [x] Analyzer-clean.
- [x] `hunter` (RunKills≥15), `nightOwl` (night→dawn), `finisher` (RunResult win) completed via their
      conditions; crew Salvage rose +270 (120+150) accordingly.
- [x] `reachRapids` fired end-to-end after sailing into Zone 3 (BoatDistance 9606 → ObjDone true). (The
      earlier manual `Zone=3` was overwritten by ZoneServer each tick — the logic itself is correct.)
- [x] HUD panel renders top-right with all 4 objectives and green ✓ checkmarks (✓ glyph renders, no tofu).

## Notes / follow-ups
- **Not committed.**
- Fixed set for the POC; could be seeded/randomised per run later. Rewards tunable in ObjectiveDefs.
- Distinct from the lobby **weekly** objectives (RetentionDefs). Could feed River Score's kills/camps/nights
  terms later (currently distance+zone+finish).
