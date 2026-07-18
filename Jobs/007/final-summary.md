# Final Summary — Job #007: Croc spawn director + multiple crocs

**Project**: `roblox.jungle`
**Completed**: 2026-07-18
**Status**: ✅ Completed & verified (greybox)

## What was implemented

Generalized the single-croc POC (#006) into a **spawn director**: crocs keep coming as you travel, so
the ride is continuously threatening. Also added the weapon rules the design called for.

- **`EnemyServer` rewritten** (`ServerScriptService/Enemies`) — a spawn director + multi-croc AI:
  - **Spawns** crocs near/ahead of the boat (70–140 studs ahead, offset within the channel) while the
    boat is alive, up to **`MAX_ACTIVE` = 4**.
  - **Escalation:** spawn interval ramps **5 s → 2 s** over the first 12,000 studs (distance-driven;
    the hook where day/night/zone scaling plugs in later).
  - **One global Heartbeat ticks every `Enemy`-tagged croc** (roblox-ai multi-agent pattern): each runs
    the same chase (velocity-led steering) → bite (per-croc cooldown) loop.
  - **Culls** crocs the boat has left >260 studs behind (they lost the chase); despawns dead ones.
- **Weapon rules** (`WeaponServer` + `WeaponClient`, from the #006 base):
  - **Range** — can only hit enemies within `WEAPON_RANGE` (220 studs); the raycast stops at range.
  - **Driver can't shoot** — the `DriverSeat` occupant is blocked (server-authoritative).
  - **Busy/fishing can't shoot** — a player with the `Busy` attribute is blocked (the future
    fishing/catching state sets it). Client hides the crosshair when you can't shoot.

## Verification (live via Studio MCP)

- [x] `bash tools/luau-analyze.sh` clean on all changed scripts.
- [x] Spawn director: crocs spawn over time, **capped at 4** (max seen = 4); each chases to bite range.
- [x] **Culling**: driving the boat forward left crocs behind → they despawned once >260 back, while
      fresh crocs spawned ahead (steady pressure).
- [x] Multiple crocs compound damage (an idle boat is destroyed in a few seconds → you must shoot/flee).
- [x] Weapon rules: normal shot hits (40→20); **driver blocked** (20→20); **busy blocked** (20→20);
      range capped — all server-side.

## Files changed (roblox.jungle)

- Rewritten: `sync/ServerScriptService/Enemies/EnemyServer.server.luau` (single croc → spawn director).
- Edited: `sync/ServerScriptService/Combat/WeaponServer.server.luau` (range + can-shoot rules),
  `sync/StarterPlayer/StarterPlayerScripts/Combat/WeaponClient.local.luau` (skip + hide crosshair).
- New: `Jobs/007/*`.

## Notes / follow-ups

- **Not committed** (per the rule).
- Tunables: `MAX_ACTIVE`, spawn ahead/interval + `ESCALATE_DISTANCE`, `CULL_BEHIND`; `WEAPON_RANGE`/
  `WEAPON_DAMAGE`/`FIRE_INTERVAL`.
- **Perf later:** crocs are kinematic Models with a global tick — fine at 4; if counts grow, pool rigs
  and LOD distant crocs (roblox-ai/optimization).
- **Next P3 slices:** player health + downed + **bandage revive**; **land threats** + **day/night
  strength** (hooks in `EnemyDefs`); real Meshy croc model + anims (P9). The **fishing/catcher** system
  will set the `Busy` attribute the weapon already respects.
