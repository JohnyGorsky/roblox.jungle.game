# Final Summary — Job #085

**Project**: `roblox.jungle`
**Completed**: 2026-08-16 22:10:05
**Status**: ✅ Completed (code + Studio verification; not committed)

## What was implemented

Jungle's three persistent stores now resolve to **different names in Studio and in the published
game**, so playtesting can no longer touch real player saves or the real global leaderboards.

| Store | Studio (editor) | Published (live) |
| --- | --- | --- |
| Player profiles | `PlayerProfiles_v1` *(existing test data — unchanged)* | `PlayerProfiles_live_v1` *(new, empty)* |
| River Score board | `Board_RiverScore_v1` | `Board_RiverScore_live_v1` |
| Best Distance board | `Board_BestDistance_v1` | `Board_BestDistance_live_v1` |

Ported from Defender's Job 080 pattern (`UserDataStorage.luau:185-188`) and extended to the two
`OrderedDataStore` boards, which Defender's version does not cover.

### How it works

The DEV/LIVE pick lives **inside the two shared config modules**, and the pre-existing field names
(`STORE_NAME`, `BOARD_RIVERSCORE`, `BOARD_DISTANCE`) now hold the *already-resolved* value:

```luau
ProfileConfig.STORE_NAME_DEV  = "PlayerProfiles_v1"
ProfileConfig.STORE_NAME_LIVE = "PlayerProfiles_live_v1"
ProfileConfig.STORE_NAME = if RunService:IsStudio()
    then ProfileConfig.STORE_NAME_DEV
    else ProfileConfig.STORE_NAME_LIVE
```

Because the resolution happens at declaration, **no call site changed**: `Profiles.luau:24`,
`RunServer.server.luau:21-22` and `RankServer.server.luau:16` are untouched.

`RunService:IsStudio()` is true in every Studio playtest (solo, Team Test, Play Here) and false on a
live server, and returns the same answer on client and server — so the lobby and game places always
agree on which store they are using. Neither module gained any DataStore access, so
`ProfileConfig`'s "client-safe" contract still holds.

### ✅ Auto-synced files

- `sync/ReplicatedStorage/Progression/ProfileConfig.luau`
- `sync/ReplicatedStorage/Progression/RankDefs.luau`
- `lobby/sync/ReplicatedStorage/Progression/ProfileConfig.luau`
- `lobby/sync/ReplicatedStorage/Progression/RankDefs.luau`

Both places were edited with explicit permission (GROUND-RULES §1) because these two modules are
byte-identical copies serving one experience and one DataStore — a one-sided change would have split
the lobby and the game onto different stores on a live server.

### ⚠️ Manual Studio copy required

- _none_

## Verification

- [x] `diff` — both file pairs are byte-identical across `sync/` and `lobby/sync/` after the edit.
- [x] `bash tools/luau-analyze.sh` clean (exit 0, no diagnostics) on all four files, in both trees,
      plus a sweep of `sync/ReplicatedStorage/Progression` and `sync/ServerScriptService/Progression`.
- [x] **Live Studio check, GAME place** (`Last River COOP Game`, running server):
      `IsStudio = true`, `STORE_NAME = PlayerProfiles_v1`, `BOARD_RIVERSCORE = Board_RiverScore_v1`,
      `BOARD_DISTANCE = Board_BestDistance_v1` — the split synced and Studio resolved to DEV.
- [x] **Live Studio check, LOBBY place** (`Last River COOP lobby`, Edit): identical values — both
      places agree.
- [ ] **Yours, after publishing**: a fresh join on the live server starts at 0 gold and both global
      boards are empty, confirming the published server picked the `_live_v1` names.

## Notes / follow-ups

- **Assumption confirmed with the user:** nobody has live progress in `PlayerProfiles_v1`, so it was
  safe to give Studio the existing name and start the live stores empty. If real saves had existed,
  the sides would have had to be flipped.
- **The store name IS the save id.** To wipe live later, bump `STORE_NAME_LIVE` (`_v1` → `_v2`); dev
  data is untouched, and switching a name back restores that store's previous save set intact. Same
  for the two `_LIVE` board names.
- Not committed — the user commits (GROUND-RULES §1).
