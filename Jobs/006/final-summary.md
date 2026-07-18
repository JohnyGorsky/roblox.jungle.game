# Final Summary — Job #006: P3 POC (first alligator)

**Project**: `roblox.jungle`
**Completed**: 2026-07-18
**Status**: ✅ Completed & verified (greybox POC)

## What was implemented

The first slice of P3 (threats/combat) — the boat now has a predator, and you can fight back. Proves
the core survival tension: **a croc chases and bites the boat (HP + fail state), and you shoot it dead.**
Greybox, server-authoritative, built on Jobs #003 (boat) + #005 (river).

- **`EnemyDefs`** (`ReplicatedStorage/Enemies`, ModuleScript) — data-driven enemy stats. The Crocodile
  (hp 40, speed 20, aggro 150, bite 8/1.5s). Carries a **`category` ("sea"/"land")** and an optional
  **`strengthAt(phase)`** time-of-day hook, so land threats + day/night scaling slot in later
  (GAME.md "Threats") without reshaping this.
- **`EnemyServer`** (`ServerScriptService/Enemies`, server Script) — spawns one croc near the boat and
  runs the AI (Humanoid-less, roblox-ai swarm path): **detect** (magnitude ≤ aggro) → **chase**
  (steer toward the boat's **velocity-led** position, kinematic `PivotTo` on the water surface) →
  **bite** (in range, `dt`-accumulator cooldown) → damage the boat. Tags the croc `Enemy`
  (CollectionService); despawns at HP ≤ 0.
- **Boat HP + fail** (`BoatServer`) — `MaxHP`/`HP` attributes on the Boat model; at HP ≤ 0 → fail
  (`BoatDestroyed`, propulsion/steering cut → dead in the water). EnemyServer bites apply a red
  hit-flash.
- **`WeaponServer`** (`ServerScriptService/Combat`, server Script) — **authoritative free-aim
  hitscan**: client sends only the tapped world **aim point**; the server re-raycasts from the
  shooter's character toward it, hits `Enemy`-tagged models, applies damage. Per-player rate limit.
- **`WeaponClient`** (`StarterPlayer/StarterPlayerScripts/Combat`, LocalScript) — centre crosshair;
  on click/tap, raycasts the camera through the pointer, sends the aim point, draws a local tracer.

## Verification (live via Studio MCP)

- [x] `bash tools/luau-analyze.sh` clean on all new/edited scripts.
- [x] Croc detects the boat, swims to intercept a **moving** boat (tracks the drift at bite range),
      and bites.
- [x] Boat HP drops **~8 per 1.5 s** (cooldown correct after switching to a dt-accumulator) with a
      red flash; hits 0 → **fail state**, boat goes dead in the water.
- [x] Shooting: client→server→raycast→damage→despawn confirmed — croc **40 → 20 → dead** in 2 hits,
      server-authoritative (client can't fake hits).
- [x] Balance by design: croc speed 20 < boat top ~30 → **full throttle escapes**; dawdling gets you
      caught (~19 s from full HP against one croc).

## Files changed (roblox.jungle)

- New (auto-sync): `sync/ReplicatedStorage/Enemies/EnemyDefs.luau`,
  `sync/ServerScriptService/Enemies/EnemyServer.server.luau`,
  `sync/ServerScriptService/Combat/WeaponServer.server.luau`,
  `sync/StarterPlayer/StarterPlayerScripts/Combat/WeaponClient.local.luau`.
- Edited: `sync/ServerScriptService/Boat/BoatServer.server.luau` (boat HP + fail state).
- New: `Jobs/006/*`.

## Notes / follow-ups (next P3 slices)

- **Not committed** (per the rule).
- **Playtest the aim feel** — client uses `ViewportPointToRay(input.Position)`; if tap-aim reads
  slightly off (GUI-inset), switch to `ScreenPointToRay`. One-line change.
- Deferred, in priority order: **player health + downed + bandage revive**; **spawn/pacing director**
  + **multiple crocs** (EnemyServer is written for one — generalize to a pool + CollectionService tick);
  **land threats** + **day/night strength** (hooks are in `EnemyDefs`); formal **gunner role** (P2);
  real **Meshy croc model** + swim/bite anims and a visible gun (art, P9).
- Enemy + weapon are the reusable base the rest of P3 builds on.
