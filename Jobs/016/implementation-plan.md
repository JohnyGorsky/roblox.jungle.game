# Implementation Plan — Job #016: Crash-site staging area + rope Start gate

**Project**: `roblox.jungle`
**Created**: 2026-07-18
**Status**: Planning (awaiting go-ahead)

Insert a **staging phase** in front of the river run (same place, phased): spawn at a greybox
**crash-site hub**, walk to the **moored boat**, **untie the rope** to start the run. Threats + boat
motion are gated until untie. Driving is unchanged after start.

## Decisions locked (via wizard + chat, 2026-07-18)

- Same gameplay place, **phased** hub → river (no teleport). **Start gate = untie the mooring rope.**
- **Boat driving unchanged** after untie; the untie is purely the Start trigger.
- **Threats/progression gated** until started; **players spawn at the hub** (not the boat) pre-start.
- **Hand-built vs procedural (GROUND-RULES §2):** the human hand-builds the hub + startup river section;
  the procedural generator takes over after it. **This job = logic + a throwaway greybox hub + the handoff
  marker.** No hero-art scripting.

## What the code map found (grounding)

- **Boat** (`Boat/BoatServer.server.luau`) — built at `RiverData.positionAt(Z_START+40)`, **server-owned**
  (`SetNetworkOwner(nil)`), moved by a Heartbeat force loop incl. a constant `Current` push (so an empty
  seat still drifts). Holding it still = `hull.Anchored = true` (forces no-op against anchored parts).
- **Tie/untie rope ALREADY EXISTS** (`World/DockServer.server.luau` L55–105): tie → `hull.Anchored=true` +
  `boat:SetAttribute("Tied",true)` + a visible brown `RopeConstraint`; untie reverses it. **Reuse this.**
- **`Tied` already means "safe"** — `EnemyServer` L144 gives a tied boat bite-immunity.
- **Player spawn** (`Combat/PlayerCombat.server.luau` L26–32) — one self-contained block teleports the
  character onto the hull; **runs on every respawn**.
- **Threats** (`Enemies/EnemyServer.server.luau` L224–251) — sea+land spawn loops run from load, keyed off
  boat Z; **no start gate today** → they'd cluster at the moored boat unless gated.
- **No game-state flag exists** — established pattern is `Workspace`/`Boat` **attributes** (RiverReady,
  BoatDistance, HP/Fuel/Tied). Add a new `Workspace` attribute `RunStarted`.
- **Cargo/Gun/Excursion init** is safe while moored (all static-on-hull; `docksBetween` skips Z≈0, so no
  camp/dock spawns at the hub).
- **RiverData** — `Z_START=0`, `WATER_Y=12`; `positionAt(z)`, `centerlineX(z)`, `widthAt(z)`,
  `tangentAtZ(z)` for placement. Bank position = `centerlineX(z) + side*(widthAt(z)*0.5 + offset)`.

## Plan (server-authoritative; new state = `Workspace:GetAttribute("RunStarted")`)

### 1. Run state (new)
- Set `Workspace:SetAttribute("RunStarted", false)` early (in the new StagingServer, after `RiverReady`).
  It replicates to clients for HUD/spawn logic. Flips to `true` on untie, once, for the whole crew.

### 2. New `StagingServer.server.luau` (`sync/ServerScriptService/Staging/`)
- Waits `RiverReady` + `Boat`; sets `RunStarted=false`.
- **Moor the boat at start:** `hull.Anchored=true`, `boat:SetAttribute("Tied",true)` (reuses the existing
  tie semantics + immunity), and build a visible **mooring rope** (lift DockServer's `RopeConstraint`
  code) from the hull to a **mooring post** on the bank.
- **Greybox hub** (clearly commented "PLACEHOLDER — replace with hand-built hub"): a flat platform on the
  bank at ~`Z_START` (`centerlineX(0) + side*(widthAt(0)*0.5 + ~12)`), a couple of greybox crates / a
  "plane wreck" block for flavour, and the mooring post + a short gangway toward the boat. Parented under
  a `StagingArea` folder so the human can delete/replace it wholesale.
- **Untie prompt:** a ProximityPrompt "Untie rope — START" on the post/rope (only reachable from the boat
  or bank). On trigger: set `RunStarted=true`, `hull.Anchored=false`, `boat:SetAttribute("Tied",false)`,
  destroy the rope + prompt. → boat is free, driving + current resume, threats begin.
- Idempotent: ignore triggers once `RunStarted`.

### 3. Player spawn → hub before start (`PlayerCombat.server.luau`)
- In `setupCharacter` L26–32, branch on `Workspace:GetAttribute("RunStarted")`:
  - **not started** → place the character on the **hub** (a spawn pad position exposed by StagingServer,
    e.g. `Workspace:GetAttribute("HubSpawn")` or a named part `StagingArea/HubSpawn`).
  - **started** → keep the current **onto-the-hull** behaviour (so mid-run respawns land on the boat).

### 4. Gate threats on start (`EnemyServer.server.luau`)
- Add `and Workspace:GetAttribute("RunStarted")` to the sea + land spawn conditions (L226/L242) — no
  enemies during staging; they begin at untie. (Camp guards need no change — nothing spawns at Z≈0.)

### 5. Handoff marker (hand-built → procedural) — documented, minimal now
- Add a single constant/comment `HANDOFF_Z` (= where the hand-built startup section will end) in RiverData
  or StagingServer, **documented but not enforced yet**: for this POC the procedural river still generates
  from `Z_START` as today. When the human hand-builds the hub + startup river, a follow-up job will tell
  `RiverBootstrap` to begin procedural generation at `HANDOFF_Z` instead of 0. **Flagged, not built** —
  keeps this job to the staging/start logic.

### 6. Staging HUD hint + boat-occupancy counter (client + server) — INCLUDED
- **Server (StagingServer):** while not `RunStarted`, a ~0.4s loop counts players **on the boat** (their
  HumanoidRootPart inside the hull's oriented bounding region, expanded to cover the cargo deck) and
  publishes `Boat:SetAttribute("OnBoatCount", n)` + `Boat:SetAttribute("CrewCount", #players)`.
- **Client (`StagingHint.local.luau`):** before `RunStarted`, show a centred banner:
  **"Board the boat & untie the rope to start"** + **"N/M on boat"** (reads the two attributes live).
  Hides once `RunStarted` is true. Anyone can untie (no driver gate).

## Files
- **New:** `sync/ServerScriptService/Staging/StagingServer.server.luau` (+ optional
  `sync/StarterPlayer/StarterPlayerScripts/UI/StagingHint.local.luau`).
- **Edit:** `sync/ServerScriptService/Combat/PlayerCombat.server.luau` (spawn branch),
  `sync/ServerScriptService/Enemies/EnemyServer.server.luau` (RunStarted gate).
- **Untouched:** BoatServer, DockServer, CargoServer, GunServer, ExcursionServer, RiverBootstrap (bar the
  optional HANDOFF constant).

## Verification (luau-analyze + live Studio MCP)
- Analyzer clean.
- On play: spawn on the **hub** (not the boat); boat sits **moored** with a visible rope; **no enemies**
  appear during staging.
- Walk to boat / stand near post → **Untie** prompt → triggering flips `RunStarted=true`, boat unanchors
  and can drive, enemies begin spawning.
- Die after start → respawn on the **boat**, not the hub.
- `Tied` immunity holds pre-start; damage resumes after.

## Out of scope / deferred
- Hand-built hub + startup-river art (human) and switching procedural gen to start at `HANDOFF_Z`.
- Role assignment at the hub (P2), pre-run Robux shop (P8), lobby place + party teleport (P6) — all hang
  off this hub in later jobs.
- Polished staging design, plane-wreck art, gangway/rope visuals.

## Open (confirm before/while building)
- Any player's untie starts the run for everyone (assumed **yes**).
- Hub on which bank / how far from the boat (POC: same side as boat spawn, ~12 studs onto the bank).
