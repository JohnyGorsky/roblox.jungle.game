# Final Summary — Job #043: Intro readiness gate (hold reveal until crew joined + world built)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Step 2 of the
game-intro-sequence (`Planned/game-intro-sequence.md`). Lobby + Game places.

## What
The game-place loading screen now holds the reveal until the run is actually ready: (a) the whole party has
joined this reserved server, and (b) the world is built — instead of revealing as soon as `game.Loaded`.
Server-authoritative; solo/Studio Play never hangs; a timeout failsafe covers dropped/slow members.

## Implementation
- **Lobby — `lobby/sync/ServerScriptService/LobbyServer.server.luau`**: `SetTeleportData` now also carries
  `partySize = #group` and `members = { UserIds }` (public data) alongside the river `seed`, so the game place
  knows how many to wait for.
- **Game — `sync/ServerScriptService/World/IntroGateServer.server.luau`** (new): sets
  `Workspace.IntroReady = false` + `IntroStatus` at startup; reads expected party size from any joined
  player's `GetJoinData().TeleportData.partySize` (falls back to headcount / `__DebugExpectedParty`); waits
  until `#players >= expected` **or** `JOIN_TIMEOUT` (25s) — publishing `"Waiting for your crew (n/N)..."`;
  then, if a generator declared `Workspace.WorldBuilt = false`, waits for it (or `WORLD_TIMEOUT` 30s) showing
  `"Building the river..."`; finally sets `IntroReady = true`. The `WorldBuilt` step is **inert** until a
  generator exists.
- **Game — `sync/ReplicatedFirst/GameLoading.local.luau`**: the hook now gates on `IntroReady` (was the old
  `WorldReady` stub) and mirrors `IntroStatus` on screen. Skipped entirely if no gate is present (standalone).

## Verified (live in Studio — game place)
- [x] Analyzer-clean (game + lobby trees).
- [x] **Happy path (solo):** `IntroReady=true`, status "Ready", gate opens immediately, game reveals — no hang.
- [x] **Crew-wait hold:** with `__DebugExpectedParty=3`, screen holds on **"Waiting for your crew (1/3)..."**.
- [x] **Failsafe release:** console `[IntroGate] expecting a party of 3` → `ready — 1/3 aboard, gate open`
      after `JOIN_TIMEOUT`; game reveals. (Tested at a shortened 5s, then confirmed the on-screen text at 20s.)
- [x] Test overrides reverted: `JOIN_TIMEOUT` back to 25, `__DebugExpectedParty` cleared.

## Notes / follow-ups
- **Not committed.**
- `members` (UserIds) is sent but not yet consumed — reserved for the plane scene (seating specific players).
- Pre-existing scaffold `Demo/Test` "Hello world!" scripts still litter the game tree (ServerScriptService,
  ServerStorage, StarterPlayer x2, ReplicatedStorage) — unrelated noise, left for a separate cleanup.
- **Next in the sequence:** the plane scene behind the mask (greybox plane, seat the crew, fly-up hold), then
  the smoking descent → crash cold-open → wake at the boat/start-area shop.
