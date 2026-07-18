# Final Summary — Job #014: Mounted gunner turret

**Project**: `roblox.jungle`
**Completed**: 2026-07-18
**Status**: ✅ Completed & playtested — user: "gun (mounted) now is perfect"

## Post-build fixes (all playtested)

- **Aim matched to the camera** — the server ray now shares the gunner camera's origin + direction
  (`CAM_UP`/`CAM_BACK` matched client↔server), so the shot goes exactly through the crosshair.
- **First-person gun view** — the gunner's character is hidden + the camera sits over the gun + the
  cursor is hidden + the camera re-asserts Scriptable each frame (the default camera was stealing it,
  putting the player's head in the way).
- **Handheld disabled while manning the gun** (client + server) — it was also firing and its tracer
  (from the body, not the camera) was the misleading "wrong" ray.
- **Gun tracer** added along the exact fire line; **hit logging** to the console (`[Gun] HIT …`).
- **Handheld aim fix** — `ViewportPointToRay` → `ScreenPointToRay` (GUI-inset mismatch made it shoot
  ~36 px above the cursor). Now lines up with the pointer.

## What was implemented

The boat's heavy defence — a mounted gun you sit at.

- **`GunServer`** — a turret welded to the boat at the bow: **GunBase** + **GunSeat** (a Seat) +
  **GunBarrel** (kinematic). Server-authoritative:
  - The gunner sits and sends a **clamped aim** (yaw ±80° / pitch −12°..+35° **relative to the boat's
    forward** — a limited arc, not 360°) via an `UnreliableRemoteEvent`; the server rotates the barrel
    to match each frame (recentres when nobody's manning it).
  - **Fire** (`RemoteEvent`) — validated (must be seated), rate-limited, **ammo-fed from the boat cargo**
    (reloads rounds from ammo crates; out of ammo = no shot), then a **strong hitscan** (damage **60**
    vs the handheld's 20) from the muzzle along the aim; hits Enemy/CampGuard-tagged models.
- **`GunClient`** — sitting in the GunSeat switches to an **over-the-gun aiming camera**
  (`MouseBehavior.LockCenter`), the mouse aims within the arc (sends yaw/pitch), a red **crosshair**
  shows, and click/tap fires. Leaving the seat restores the normal camera.
- **Enemy health bars** (`EnemyHealthBars`) — a floating HP bar (green→yellow→red) over every enemy.

## Verification (live via Studio MCP)

- [x] `bash tools/luau-analyze.sh` clean.
- [x] Turret parts (GunBase/GunSeat/GunBarrel) + `GunAim`/`GunFire` remotes present on/for the boat;
      barrel aligned to the boat forward by default (dot = 1.00).
- [~] **Gunner flow (sit → aim camera → rotate → fire)** needs a **playtest** — the seated camera + mouse
      aim can't be driven solo via the MCP harness. **How to use:** walk to the bow, sit in the gun
      seat → camera locks to the gun → move the mouse to aim within the arc → click to fire (uses ammo).

## Files changed

- New: `sync/ServerScriptService/Combat/GunServer.server.luau`,
  `sync/StarterPlayer/StarterPlayerScripts/Combat/GunClient.local.luau`,
  `sync/StarterPlayer/StarterPlayerScripts/UI/EnemyHealthBars.local.luau`.
- New: `Jobs/014/*`.

## Notes / follow-ups

- **Not committed.**
- Playtest + tune: arc limits, sensitivity, gun damage/fire-rate, camera offset.
- Deferred: muzzle flash / recoil / tracer, turret art, the sword default + guns-from-camps (the rest of
  the weapon vision), a HUD "gunner ammo" cue, and reconciling with the handheld free-aim weapon.
