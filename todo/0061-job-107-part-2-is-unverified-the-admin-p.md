# TODO 0061: Job #107 Part 2 is UNVERIFIED: the admin panel 'TP to First Camp' was rewritten (release moor via ServerStorage.ForceStartRun -> move boat to the landing -> ForceFirstCamp -> RequestStreamAroundAsync -> teleport, with the client now showing failure reasons) but was NEVER run once. Untested: RequestStreamAroundAsync server-side, the boat surviving a 1900-stud PivotTo, ForceFirstCamp finishing inside its 30s poll, and the RemoteFunction blocking that long. Play-test before relying on it.

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-23 20:24:34

_(the thought/task; expand here, or promote to a Job when it's real work)_
