# Job #085: Separate Studio (editor) and live DataStores

**Project**: `roblox.jungle`
**Created**: 2026-08-16 22:06:14
**Status**: Requirements Gathering (intake)

## Requirements / goal

Studio playtests and the published game currently share the SAME persistent stores, so dev testing writes into real player data and posts fake scores onto the live global leaderboards. Split them by RunService:IsStudio(), mirroring Defender's Job 080 pattern (STORE_NAME_DEV / STORE_NAME_LIVE). Scope agreed with the user: (1) ProfileConfig.STORE_NAME (player profiles), (2) RankDefs.BOARD_RIVERSCORE and (3) RankDefs.BOARD_DISTANCE (the two OrderedDataStore global boards). Data side agreed: STUDIO keeps the current names (existing test progress survives); LIVE gets new, empty store names so real players start fresh. Both Jungle places are in scope because ProfileConfig.luau and RankDefs.luau are byte-identical copies under /sync/ and /lobby/sync/ and must stay identical (one experience, one DataStore).

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
