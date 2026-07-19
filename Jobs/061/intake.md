# Job #061: Run objectives (per-run bonus goals)

**Project**: `roblox.jungle`
**Created**: 2026-07-19 23:18:25
**Status**: Requirements Gathering (intake)

## Requirements / goal

Review decision #4. Per-run objectives that reward bonus Salvage + River Score (+Gold for finish). ObjectiveDefs (shared catalog, 4 for POC: reach The Rapids, survive a night, take down 15 threats, complete the run). ObjectiveServer tracks via Zone/Phase/RunKills/RunResult, awards the crew on completion, publishes ObjDone_/ObjProg_ Workspace attributes, resets on RunStarted. EnemyServer increments RunKills on a kill. ObjectiveHud panel shows the list + progress + checks (hidden during intro). Not committed.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
