# Final Summary — Job #041: Lobby loading screen (wait for load, then reveal)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · From todo 0006. **Lobby place only.**

## What
A game loading screen for the **lobby**, modelled on roblox.defender's `ReplicatedFirst/Loading`: take over from
the default Roblox loading screen, show a custom screen while assets stream in, **wait until the game is fully
loaded**, then fade out and reveal the lobby. Simple greybox GUI for now — a design pass replaces the visuals later.

## Implementation
- **`lobby/sync/ReplicatedFirst/LobbyLoading.local.luau`** (new). ReplicatedFirst LocalScript so it's up before
  anything else replicates:
  1. `ReplicatedFirst:RemoveDefaultLoadingScreen()`.
  2. Hides core HUD (Backpack/Chat/PlayerList/Health) during load; restores it at the end.
  3. Builds a simple ScreenGui in code — dark backdrop, "LAST RIVER" title, status line, rounded green progress
     bar. No external assets (nothing to fail to load).
  4. `ContentProvider:PreloadAsync` over Workspace/ReplicatedStorage/StarterGui/Lighting/SoundService
     descendants in small batches → smooth bar to ~90%.
  5. `if not game:IsLoaded() then game.Loaded:Wait() end` → guarantees the client is fully replicated before reveal.
  6. `MIN_SHOWN` (1.5s) floor so it never just flickers, then fade (TweenService) → destroy → restore HUD.
- **`lobby/default.project.json`**: added a `ReplicatedFirst` → `sync/ReplicatedFirst` mapping (the lobby project
  didn't map it before). Removed the leftover `ReplicatedFirst/Demo/Test` hello-world.

## Verified (live in Studio — lobby place)
- [x] Analyzer-clean (luau-lsp against a lobby sourcemap).
- [x] Script synced into `ReplicatedFirst` as a LocalScript.
- [x] On Play: custom screen shows (dark bg, "LAST RIVER", status, green bar), **core HUD hidden**, held until
      loaded (screenshot at the "Finishing up..." / ~92% stage).
- [x] Fades out and reveals the full lobby with HUD restored (Gold, shop buttons, launch pads, banner all back).
- [x] Test-only `MIN_SHOWN=8` used to catch it on screen, then reverted to 1.5.

## Notes / follow-ups
- **Not committed.**
- **Lobby only.** The Game place still uses the default loading screen — a separate ReplicatedFirst screen there
  is todo **0007** (the "fancy" teleport lobby→game screen the user wants to spec first).
- Visuals are intentionally greybox; a design pass (logo art, background, animation) comes later.
