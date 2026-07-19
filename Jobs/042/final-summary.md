# Final Summary — Job #042: Game-place loading screen (mirror lobby)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · **Game place.** Step 1 of the
game-intro-sequence (see `Planned/game-intro-sequence.md`).

## What
Mirrored the lobby loading screen (Job 041) onto the **Game** place so it also waits-then-reveals instead of
using Roblox's default loader. Same simple "LAST RIVER" greybox screen; a design pass replaces visuals later.

## Implementation
- **`sync/ReplicatedFirst/GameLoading.local.luau`** (new). Same structure as the lobby loader:
  RemoveDefaultLoadingScreen → hide core HUD → build ScreenGui in code (dark bg, "LAST RIVER" title, status,
  green progress bar) → `ContentProvider:PreloadAsync` in batches → wait for `game.Loaded` → `MIN_SHOWN` floor
  → fade → destroy → restore HUD.
- **Added a forward-compatible hook** for the intro sequence: after `game.Loaded`, if
  `Workspace:GetAttribute("WorldReady") == false` the screen holds ("Building the river...") until the world
  generator flips it to `true`. **Inert today** — skipped entirely unless something sets the attribute — so it
  masks world-gen for free once the generator exists.
- Removed the leftover `ReplicatedFirst/Demo/Test` hello-world in the game tree.
- The game already mapped `ReplicatedFirst` → `sync/ReplicatedFirst`, so no project.json change needed.

## Verified (live in Studio — game place)
- [x] Analyzer-clean.
- [x] Synced into `ReplicatedFirst` as a LocalScript.
- [x] On Play: custom screen shows (dark bg, "LAST RIVER", "Finishing up..." / ~92% bar), core HUD hidden.
- [x] Fades and reveals the game with full HUD restored (Gold/Salvage, Cargo, hotbar, Fuel/Boat bars, boat
      objective, Admin).
- [x] Test-only `MIN_SHOWN=8` used to catch it on screen, reverted to 1.5.

## Notes / follow-ups
- **Not committed.**
- Greybox visuals — art/design later.
- This is **step 1** of the locked-in **game-intro-sequence** (`Planned/game-intro-sequence.md`): the loading
  screen is the *mask*. Next steps in that plan: gate reveal on real readiness (all players joined via
  TeleportData count + `WorldReady`), then the plane fly-up scene, smoking descent, crash cold-open, and
  wake-up at the boat/start-area Robux shop.
