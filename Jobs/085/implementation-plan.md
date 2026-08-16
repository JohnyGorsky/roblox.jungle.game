# Implementation Plan — Job #085

**Project**: `roblox.jungle`
**Created**: 2026-08-16 22:06:52
**Status**: Planning (awaiting go-ahead)

## Analysis

### The problem

Jungle has exactly three persistent stores, and **all three use one name in Studio and in the
published game**:

| Store | Name today | Declared in | Read by |
| --- | --- | --- | --- |
| Player profiles (`DataStore`) | `PlayerProfiles_v1` | `ReplicatedStorage/Progression/ProfileConfig.luau:8` | `ServerScriptService/Progression/Profiles.luau:24` (both places) |
| River Score board (`OrderedDataStore`) | `Board_RiverScore_v1` | `ReplicatedStorage/Progression/RankDefs.luau:9` | `sync/.../RunServer.server.luau:21`, `lobby/.../RankServer.server.luau:16` |
| Best Distance board (`OrderedDataStore`) | `Board_BestDistance_v1` | `ReplicatedStorage/Progression/RankDefs.luau:10` | `sync/.../RunServer.server.luau:22` |

So every Studio playtest writes gold/skills/modules into the same profile records real players would
use, and posts test River Score / distance onto the same global boards players would see.

Defender already solved this (Job 080, `UserDataStorage.luau:185-188`): two constants and a
`RunService:IsStudio()` pick. This job ports that pattern to Jungle and extends it to the two
leaderboards, which Defender's version does not cover.

### Where the switch goes

Both `ProfileConfig.luau` and `RankDefs.luau` are shared `ReplicatedStorage` modules that only
*declare* the names — the DataStore handles are opened at the call sites. Resolving DEV vs LIVE
**inside those two modules**, and keeping the existing field names (`STORE_NAME`,
`BOARD_RIVERSCORE`, `BOARD_DISTANCE`) as the already-resolved value, means **no call site changes at
all**: `Profiles.luau`, `RunServer.server.luau` and `RankServer.server.luau` are untouched.

`RunService:IsStudio()` is safe in these modules — it needs no DataStore access, so
`ProfileConfig`'s "client-safe" contract holds, and it returns the same answer on the Studio client
and the Studio server, so the lobby and game places always agree.

### Both places are in scope (needs your OK — GROUND-RULES §1)

`ProfileConfig.luau` and `RankDefs.luau` exist as **byte-identical copies** in the GAME tree
(`sync/`) and the LOBBY tree (`lobby/sync/`) — verified with `diff`, both are currently identical.
They are one experience sharing one DataStore, so the edit **must** be applied to both copies and
they must stay byte-identical afterwards. That crosses the place boundary, so it needs explicit
permission before I start.

### Assumption you should sanity-check

You chose "**Studio keeps the current data, live starts fresh**". That means the LIVE stores start
**empty** — correct while Jungle is not yet published to real players, and *wrong* if anyone already
has progress saved under `PlayerProfiles_v1` on a live server, because they would be reset. Say so
and I flip which side keeps the old name; it is a one-line change per constant.

## Implementation steps

1. **`ProfileConfig.luau`** — add `local RunService = game:GetService("RunService")`, replace the
   single `STORE_NAME` line with:
   - `ProfileConfig.STORE_NAME_DEV = "PlayerProfiles_v1"` (Studio — keeps existing test progress)
   - `ProfileConfig.STORE_NAME_LIVE = "PlayerProfiles_live_v1"` (published — empty, fresh)
   - `ProfileConfig.STORE_NAME = if RunService:IsStudio() then ...DEV else ...LIVE`
   - Comment block explaining the split, that the name **is** the save id, and that bumping
     `_LIVE` to `_v2` is how you wipe live later without touching dev data.
2. **`RankDefs.luau`** — same treatment for both boards:
   - `BOARD_RIVERSCORE_DEV = "Board_RiverScore_v1"` / `_LIVE = "Board_RiverScore_live_v1"`
   - `BOARD_DISTANCE_DEV = "Board_BestDistance_v1"` / `_LIVE = "Board_BestDistance_live_v1"`
   - `BOARD_RIVERSCORE` / `BOARD_DISTANCE` become the resolved values.
3. **Copy both edited files verbatim into `lobby/sync/ReplicatedStorage/Progression/`**, then
   `diff` each pair to prove they are byte-identical.
4. **No other file changes.** `Profiles.luau`, `RunServer.server.luau`, `RankServer.server.luau`
   keep reading the same field names.
5. Run `bash tools/luau-analyze.sh` on the four edited files and clear findings.
6. Write `final-summary.md` + `changelog.md`.

## What I need from you

- [ ] **Go-ahead on the plan.**
- [ ] **Permission to edit both places** — the GAME tree (`sync/`) *and* the LOBBY tree
      (`lobby/sync/`), per GROUND-RULES §1. The change is meaningless if only one side switches.
- [ ] **Confirm no real players have progress in `PlayerProfiles_v1`** (see the assumption above).
- [ ] Studio-side: open the **lobby** place at least once after the change so its `ReplicatedStorage`
      copy syncs — the game place picks up its copy on the next sync of the game place.
- [ ] Nothing else — no asset IDs, no Creator Hub setup.

## Verification

- [ ] `diff` proves `ProfileConfig.luau` and `RankDefs.luau` are byte-identical across `sync/` and
      `lobby/sync/`.
- [ ] `bash tools/luau-analyze.sh` clean on all four files.
- [ ] Studio playtest: your existing test profile still loads with its gold/skills/modules intact
      (proves Studio resolved to `PlayerProfiles_v1`).
- [ ] Studio playtest: print `ProfileConfig.STORE_NAME` on the server → `PlayerProfiles_v1`; confirm
      the rank board still shows the existing dev entries.
- [ ] Published-place check (yours, after publish): a fresh join starts at 0 gold and the global
      boards are empty — confirming the live server picked `_live_v1`.
