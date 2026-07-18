# Final Summary — Job #013: Resource loop (trailer, stations, ammo)

**Project**: `roblox.jungle`
**Completed**: 2026-07-18
**Status**: ✅ Built & structurally verified (interactive flows need a playtest)

## What was implemented

Replaced the pier auto-refuel with the real **loot → store → use** loop.

- **Back cargo deck** (`CargoServer`) — cargo is stored **ON the boat** (one rigid assembly — decided
  with the user over a towed trailer, which was fiddly/jittery per roblox-physics). A **massless welded**
  back deck extends the boat (adds no mass → **handling unchanged**, verified: hull mass 851, coasts
  freely after a push). Cargo attributes on the boat: **Gasoline, Metal, Ammo** (crates) + **Rounds**
  (loaded) + **CargoMax** (10). Starts with 3 ammo. _(An earlier towed-trailer version was built then
  replaced — it dragged the boat and looked lame.)_
- **On-boat stations** (`CargoServer`, welded to the hull, on the back deck):
  - **Fuel Station** — hold → spend **1 gasoline** → +40 fuel (capped).
  - **Repair Station** — hold → spend **1 metal** → +25 hull HP (capped).
- **Ammo** (`WeaponServer`) — each shot draws a **round** from the trailer; when empty it reloads a
  round-pool from an **ammo crate**; **out of ammo = no shot** (server-enforced).
- **Loot that matters** (`ExcursionServer`) — camps yield **varied resources**: near camp = gasoline,
  deeper camp = metal + ammo (colour-coded crates, "Loot Gasoline/Metal/Ammo" prompts). Deposit adds to
  the **trailer** cargo (refused when full → keep carrying).
- **Pier refuel removed** (`DockServer`) — the dock only ties the boat now; refuelling is a boat station.

## Verification (live via Studio MCP)

- [x] `bash tools/luau-analyze.sh` clean on all changed scripts.
- [x] Trailer exists, **tows behind the boat** (offset −17), **roped**; cargo attributes set (Ammo=3,
      CargoMax=10); **Fuel + Repair stations** present on the boat.
- [~] **Ammo-gate / station-consume / deposit** — logic wired + analyzer-clean, but the prompt/weapon
      interactions couldn't be driven solo (the MCP harness keeps auto-seating the test player as the
      boat **driver**, who can't shoot, and crocs swim off during setup). **Playtest to confirm:** loot a
      crate → deposit to trailer → cargo goes up; hold Fuel/Repair station → fuel/HP up + cargo down;
      shoot until ammo runs out → can't fire until you loot ammo.

## Files changed

- New: `sync/ServerScriptService/Cargo/CargoServer.server.luau`.
- Edited: `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` (varied loot, deposit→trailer),
  `sync/ServerScriptService/Combat/WeaponServer.server.luau` (ammo), `.../World/DockServer.server.luau`
  (removed pier refuel).
- New: `Jobs/013/*`.

## Notes / follow-ups

- **Not committed.**
- **Playtest** the full loop end-to-end (crew job: haul loot → feed the stations).
- A cargo/ammo **HUD** would help (show trailer Gasoline/Metal/Ammo + rounds) — quick add to HudClient.
- Deferred: **capacity gamepass** slots; a **physics-tow** trailer (currently kinematic); fuel-can haul
  visuals; repair/refuel animations; balance (station amounts, cargo max, ammo per crate).
- Client fires a tracer even when out of ammo (server rejects the damage) — add a client ammo check +
  "out of ammo" feedback later.
