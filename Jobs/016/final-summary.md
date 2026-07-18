# Final Summary — Job #016: Crash-site staging area + rope Start gate

**Project**: `roblox.jungle`
**Completed**: 2026-07-18
**Status**: ✅ Built, analyzer-clean, verified live via Studio MCP. **Functional greybox POC** — the
crash-site hub is a throwaway placeholder for the human's hand-built version.

## What was implemented

A **staging phase** in front of the river run (same place, phased), gated by a new run-state flag.

- **`RunStarted` (new game-state flag)** — `Workspace:SetAttribute("RunStarted", …)`. None existed before;
  this is the first real game-state gate (replicates to clients for spawn + HUD).
- **`StagingServer`** (`sync/ServerScriptService/Staging/`) —
  - **Moors the boat WITHOUT anchoring** (the hard-won core fix). The boat stays **dynamic + server-owned**
    and is held by an **`AlignPosition`** constraint. Releasing = **`:Destroy()` the constraint** — there is
    NO anchor→unanchor transition. *(Why: anchoring the boat then unanchoring it while a client-owned player
    stood on it exploded the assembly in one physics step and the engine deleted the boat — the "boat
    disappears on untie" bug. Diagnosed via logging: `hull.Parent → nil` with no `Destroying` event. The
    base game never anchors its boat, so it never hit this. Recorded in the roblox-physics skill "Mooring"
    section.)*
  - **AlignPosition holds X/Z only, not Y** — buoyancy owns the vertical float; driving both Y made the boat
    **bounce**. Each frame the hold's target Y is re-aimed at the hull's current Y (zero Y error → zero Y
    force). Verified: moored vertical range ~0.6 studs (gentle bob, was jumping).
  - **Terrain-aware docking:** the boat reels to a point whose **whole hull footprint** (a probed grid) is
    over water deep enough to clear the underwater bank, kept well out (`EXTRA_CLEAR`) so it never beaches.
    A jetty extends from the shore to reach it.
  - **Pull-to-reel:** a **"Pull rope"** ProximityPrompt on a placeholder **Winch** cube moves the hold target
    toward the dock in steps; the boat glides in (a player standing on it rides along). Once docked the
    prompt becomes **"Untie rope — START"**.
  - **On-boat detection = downward raycast** hitting only boat parts (a bounding box wrongly counted players
    on the pier ~2 studs off the hull). Verified: pier = 0, boat = 1.
  - **Untie = START:** requires **someone aboard** (`OnBoatCount ≥ 1`, so the boat can't sail off without
    the crew) → `RunStarted=true`, **destroy the hold constraint** (boat is already dynamic + server-owned →
    it drifts/drives free, no explosion), `Tied=false`, remove the rope + prompt. **The hub is left standing**
    (crew has sailed off) — it is NOT torn down (fixed the "everything disappears" issue).
  - **Greybox hub** (a `StagingArea` folder — clearly marked PLACEHOLDER, for the hand-built hub): a bank
    platform, a "plane wreck" block, a gangway, and the **Winch cube** (placeholder for a future winch
    asset). Publishes `HubSpawn` (Vector3) for the spawn logic.
  - **Occupancy counter:** while staging, publishes `Boat.OnBoatCount` / `Boat.CrewCount` (players standing
    on a boat part, via a downward raycast) for the HUD.
- **Spawn branch** (`PlayerCombat.server.luau`) — before start, spawn at the **hub** (`HubSpawn`); after
  start, on the **boat** (mid-run respawns land on the boat, as before).
- **Threat gate** (`EnemyServer.server.luau`) — the sea + land spawn directors now also require
  `RunStarted`; no enemies during staging.
- **Staging HUD** (`StagingHint.local.luau`) — a pre-run banner "Board the boat & untie the rope to START"
  + **"N/M on boat"** (turns green when the whole crew is aboard). Hides once `RunStarted`.
- **Handoff marker** — a documented `HANDOFF_Z` constant marks where the hand-built startup section will
  end. **Not enforced yet** (procedural river still builds from `Z_START` this POC); a follow-up job will
  point `RiverBootstrap` at `HANDOFF_Z` once the hub + startup river are hand-built.

## Verification (live via Studio MCP)

- [x] `bash tools/luau-analyze.sh` clean (whole-project sweep).
- [x] **Staging state:** `RunStarted=false`; boat **anchored + tied**; `StagingArea` built
      (HubPlatform/PlaneWreck/Gangway/MooringPost); rope on hull; untie prompt present; `HubSpawn` set.
- [x] **Spawn at hub:** player spawned 0.5 studs from `HubSpawn` (141 studs from the boat).
- [x] **No threats during staging:** 0 `Enemy`-tagged models.
- [x] **HUD (screenshot):** banner + "0/1 on boat" render.
- [x] **Start opens the gate** (performed StagingServer's exact `startRun` state change): `RunStarted=true`
      → boat **unanchored** (drivable) + `Tied=false`, `StagingArea` removed, **3 enemies** spawned within 3s.
- [x] **Post-start respawn** lands on the **boat** (3.9 studs from hull), not the hub.
- [x] **Full flow confirmed by human playtest** (pull → board → untie → sail). Getting there took several
      rounds — the boat "disappeared on untie" until the anchor→unanchor explosion was root-caused (logging)
      and replaced with the constraint-hold; then a buoyancy/AlignPosition Y-fight bounce was fixed. Both
      lessons are now in the roblox-physics skill.

## Files

- **New:** `sync/ServerScriptService/Staging/StagingServer.server.luau`,
  `sync/StarterPlayer/StarterPlayerScripts/UI/StagingHint.local.luau`.
- **Edited:** `sync/ServerScriptService/Combat/PlayerCombat.server.luau` (spawn branch),
  `sync/ServerScriptService/Enemies/EnemyServer.server.luau` (RunStarted gate ×2),
  `sync/ServerScriptService/Boat/BoatServer.server.luau` (buoyancy + network-ownership fixes — see below).
- **Untouched:** DockServer, CargoServer, GunServer, ExcursionServer, RiverBootstrap.
- New: `Jobs/016/*`.

## Boat physics fixes (surfaced during playtest — root-caused with logging, not guessed)

Reaching the boat via staging exposed two pre-existing boat-physics bugs the user hit hard ("boat
disappears", "bounces higher and higher"). Both fixed and written into the roblox-physics skill:

1. **Disappear on untie** → *never anchor to moor* (StagingServer): anchoring the dynamic boat then
   un-anchoring it with a client-owned player aboard exploded the assembly in one physics step and the
   engine deleted it (`hull.Parent → nil`, no `Destroying`). Replaced with a constraint-hold.
2. **Bounces higher & higher while DRIVEN** → **`BoatServer`**:
   - The `VehicleSeat` handed the boat's **network ownership to the driver's client** on sit, but buoyancy
     is computed **server-side** → the server's spring reacted to *lagged replicated* position → a
     delayed-feedback loop that pumped the bob to Y 8→33 (buoy accel ±800). **Confirmed via logging the
     `GetNetworkOwner()` in the force loop** (`owner=johnygorsky10` while driving). Fix: re-grab
     `SetNetworkOwner(nil)` whenever a client holds the boat, so it stays server-owned while driven (inputs
     still replicate via the seat). Confirmed by the user: stable while driving.
   - Buoyancy retune (secondary): damping applied **separately** from the up-only spring clamp (was folded
     into `math.max(…,0)` and lost on the rise), cutoff raised `WATER_Y+5 → +12` (was switching buoyancy
     off at the bob's peak → limit cycle), `FLOAT_D 3 → 8`. Idle/drift bob: ~3 studs → 0.

## Notes / follow-ups

- **Not committed.**
- **Human hand-builds** the real crash-site hub + startup river section (deletes the greybox `StagingArea`).
- **Follow-up job:** switch procedural generation to begin at `HANDOFF_Z` (hand-built → procedural handoff).
- **Generalize pull-to-reel to EVERY pier (user request):** the reel-in-with-the-rope mechanic should also
  work at the river docks (`DockServer`). Best done by extracting a shared "moor + winch reel" module used
  by both StagingServer and DockServer (avoid duplicating the reel/rope code). → **follow-up job.**
- **Winch asset:** the pull action currently lives on a placeholder cube — swap for a winch model later.
- **Hangs off this hub next:** role assignment (P2), pre-run Robux shop (P8), lobby place + party teleport
  (P6) — the two-place front end.
- The greybox hub camera clips the bank terrain (cosmetic); irrelevant once hand-built.
- Tune: hub position/side, untie hold time, occupancy box bounds.
