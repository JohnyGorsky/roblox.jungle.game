# TODO 0062: Stale comment: RiverData says docks refuel, DockServer says they do not

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-27 21:07:58

RiverData.luau:20-22 claims the greybox refuels straight from the dock pump. DockServer.server.luau:458 says the opposite — no refuel here, refuelling happens at the boat fuel STATION using looted gasoline. The stale comment is what RiverData's own fuel-margin arithmetic at :25-28 reasons against, so it is actively misleading. Surfaced by the Job #123 economy audit.
