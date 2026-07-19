# Planned: Game intro sequence (lobby → game, plane crash cold-open)

**Project:** `roblox.jungle` — **LOCKED-IN end-goal** (user vision, 2026-07-19). Build mechanics now, assets/art later.

The full transition from the lobby to the start of a run. Turns the unavoidable "everyone joins + world
generates + textures stream" wait into the game's opening cinematic, so players never see a half-built world.
North-star reference: Dead Rails' train-departure intro, adapted to a **plane crash**.

## The flow (in order)

1. **Lobby — team ready → fade out.** Player/party confirms their team on a launch pad; screen fades to black.
2. **Teleport to Place 2 (Game).** TeleportService to the reserved game server (existing launch flow, Job 017).
3. **Startup loading screen (Game).** Same style as the lobby loader (Job 041/042) — "LAST RIVER" + progress.
   This screen **stays up as a mask** while, in the background:
   - a **plane is flying up into the air** with all the players aboard (the boarding scene is set up hidden
     behind the loading GUI);
   - we **wait for all players to join** the reserved server;
   - we **wait for the world to finish generating** + textures to load (this is *why* the screen is held —
     nothing is revealed until it's all ready).
4. **Plane descent.** Once everyone's in and the world is ready: the plane **starts smoking and goes down**
   with the players — the loading screen fades out into this shot.
5. **Crash cold-open cinematic.** Cut/fade to the **starting area**: the plane has **crashed**, players are
   **lying on the ground and slowly wake up** (camera + get-up sequence).
6. **Gameplay start.** Cinematic ends → players are at the **starting position**, where they first approach the
   **boat**. Likely a **small shop there too (Robux)** near the start.

## Build order (mechanics first, assets later)

- **[Job 042 — done]** Step 3 baseline: the Game-place startup loading screen (mirror the lobby one) — the mask.
- **[Job 043 — done]** Readiness gate: `IntroGateServer` holds `Workspace.IntroReady=false` until the whole
  party has joined (expected size from lobby TeleportData `partySize`, timeout failsafe) + the world is built
  (`WorldBuilt` hook, inert until a generator sets it), publishing `IntroStatus` text; the loader holds on
  `IntroReady` and shows `IntroStatus`.
- **Next:** the plane scene (greybox plane, seat all players, fly-up hold) built behind the mask — flip
  `WorldBuilt` when its (future) generator finishes.
- **Then:** the plane scene (greybox plane, seat all players, fly-up hold, smoking descent) behind the mask.
- **Then:** the crash cold-open (greybox crash site, prone→wake-up character sequence, camera).
- **Then:** starting area = boat approach + small Robux shop.
- **Last:** art/asset pass replaces every greybox (plane model, crash VFX/smoke, environment, animations).

## Notes
- All greybox/mechanics for now — a design/art pass swaps visuals later (workspace ground rule).
- Supersedes/expands **todo 0007** (fancy teleport loading screen) — 0007 is the "loading screen" slice of this.
- Ties into: lobby launch flow (Job 017), world/river generation, monetization (start-area Robux shop).
