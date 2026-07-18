# Implementation Plan — Job #017: Lobby place + launch-pad party + reserved teleport

**Project**: `roblox.jungle`
**Created**: 2026-07-18
**Status**: Planning (awaiting go-ahead)

The two-place front end (first slice of P6): a **Lobby** place where players form parties on **launch
pads** and the leader teleports the group into a private **reserved gameplay server**.

## Decisions locked (via wizard + chat, 2026-07-18)

- **Two places:** current place stays **gameplay**; a **new Lobby place** becomes the **start place**.
- **Launch-pad party:** **3 pads**, 1–6 players each. Step on to join; a **sign** shows count/names/leader;
  **first on an empty pad = leader**; leader-only **Start**; leader leaves → **next-longest becomes leader**;
  step off to leave.
- **Start → 3s countdown → reserved teleport** of the pad group together.
- **Airfield/departure** greybox theme.
- **Deferred:** shop/skills/boat-upgrades (P8), random fill/queue matchmaking, cosmetics.

## Roblox mechanics (from the roblox-multiplayer skill)

- One **experience**, two **places**. Lobby = start place; teleport to the gameplay `PlaceId`.
- `ReserveServerAsync(gamePlaceId)` → access code; `TeleportOptions.ReservedServerAccessCode` +
  `TeleportAsync(placeId, {players}, opt)` sends the party into **one private** instance. Reserved servers
  exclude random matchmaking (good for co-op).
- `TeleportOptions:SetTeleportData({...})` is **PUBLIC** — only pass non-secret context (a run **seed**).
  Authoritative data (currency/unlocks) loads from **DataStore by userId** later, never teleport data.
- **Teleport is server-only and does NOT run in Studio** — everything *up to* the teleport is
  Studio-testable; the hop itself is verified **live**.

## Human prerequisites (I can't do these)

1. **Create the Lobby place** in the experience and set it as the **start place**; keep the current place
   as gameplay. Point Studio Sync at the new `lobby/` tree (below) for that place.
2. **Give me the gameplay `PlaceId`** → I put it in `LobbyConfig`. Until then it's a placeholder and Start
   logs "set GAMEPLAY_PLACE_ID" instead of teleporting (no error in testing).

## Repo layout (two sync targets)

- New top-level **`lobby/`** tree mirroring `sync/` convention: `lobby/sync/<Service>/…`, plus
  `lobby/default.project.json` (for the lobby place's Studio Sync + luau-lsp sourcemap). Gameplay's `sync/`
  is untouched.

## Plan

### 1. Config — `lobby/sync/ReplicatedStorage/LobbyConfig.luau`
- `GAMEPLAY_PLACE_ID` (placeholder `0` → human fills), `PAD_COUNT = 3`, `MAX_PER_PAD = 6`,
  `COUNTDOWN = 3`. `--!strict`.

### 2. Lobby world (greybox, script-built for reproducibility) — in `LobbyServer`
- A `SpawnLocation` in the lobby spawn area (so players spawn in the lobby, not the void).
- Greybox **airfield**: a runway/hangar block, ground, and **3 launch pads** (coloured pads laid out in a
  row) — clearly marked PLACEHOLDER for the art pass.
- Each pad: a **BillboardGui sign** above it — pad name, **N/6**, occupant names, **leader** ★, and a
  status line (idle / "Leader: press Start" / "Launching in 3…").

### 3. Pad-party system — `lobby/sync/ServerScriptService/LobbyServer.server.luau` (authoritative)
- Per pad: an **ordered occupant list** (by arrival). **Occupancy** via a periodic overlap check
  (`GetPartBoundsInBox`/magnitude, ~0.3s) — robust, matches the game's other detectors.
- On change: recompute **leader = occupants[1]**; refresh the sign; enable/disable the pad's **Start**.
- **Start = a ProximityPrompt on the pad** ("Start Expedition"); the server's `Triggered` **validates
  `player == leader`** (non-leaders ignored). Prevents non-leader/exploit starts.
- **Countdown:** on valid Start, lock the pad, show "Launching in 3…2…1" on the sign, then teleport. If the
  leader (or all) leave mid-countdown, **cancel**.

### 4. Reserved teleport — in `LobbyServer` (server-only)
- `local ok, code = pcall(ReserveServerAsync, gamePlaceId)`; build `TeleportOptions` with the code +
  `SetTeleportData({ seed = <int> })`; `pcall(TeleportAsync, placeId, padPlayers, opt)` with a **retry**
  (SafeTeleport pattern) + `TeleportInitFailed` handler that puts players back on the pad.
- If `GAMEPLAY_PLACE_ID == 0`: skip the hop, `warn("[Lobby] set GAMEPLAY_PLACE_ID")`, unlock the pad
  (keeps Studio testing clean).

### 5. Gameplay side (tiny) — arrival hook
- On the **gameplay** place, read `player:GetJoinData().TeleportData` for the **seed** (feed
  `RiverData.setSeed` so the whole party shares one river). If absent (joined gameplay directly), fall back
  to the current default. This is the only gameplay-place edit; the staging flow (#016) is otherwise unchanged.

### 6. Client — `lobby/sync/StarterPlayer/StarterPlayerScripts/LobbyClient.local.luau`
- Minimal: a small on-screen hint ("Step on a pad to form a party; the leader starts the run"). Signs are
  server BillboardGuis; Start is the ProximityPrompt — so little client code is needed now.

## Files
- **New (lobby place):** `lobby/default.project.json`, `lobby/sync/ReplicatedStorage/LobbyConfig.luau`,
  `lobby/sync/ServerScriptService/LobbyServer.server.luau`,
  `lobby/sync/StarterPlayer/StarterPlayerScripts/LobbyClient.local.luau`.
- **Edited (gameplay place):** a small arrival-seed hook (likely `RiverBootstrap` or a new tiny
  `ArrivalServer`) — read teleport-data seed.
- New: `Jobs/017/*`.

## Verification
- luau-analyze clean (lobby tree gets its own sourcemap via `lobby/default.project.json`).
- **Studio (single player, lobby place):** spawn in the lobby; step on a pad → sign shows 1/6 + you as ★
  leader; Start prompt appears for you; pressing Start runs the 3s countdown; with placeholder PlaceId it
  logs "set GAMEPLAY_PLACE_ID" and unlocks (no teleport in Studio). Step off → removed; leader handoff works
  with a 2nd test player if available.
- **Live (after you publish the lobby place + give the PlaceId):** Start actually teleports the pad group
  together into one reserved gameplay server; they arrive at the crash-site staging with a shared seed.

## Out of scope / deferred
- Shop / skills / boat upgrades (P8 economy) — leave space in the lobby.
- Random fill / matchmaking queue (MemoryStore), friends-invite UI (`SocialService` PromptGameInvite) — can
  add later; pads + manual grouping first.
- Rejoin-same-instance, cross-server messaging, results/return-to-lobby flow.
- All art/sound (P9).

## Open (confirm during build)
- Exact pad layout/spacing + lobby size (greybox, easy to tune).
- Whether to also add a friends-invite button now or defer (leaning defer).
