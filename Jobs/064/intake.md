# Job #064: Lobby: Jungle Airfield — layout, base terrain & asset list

**Project**: `roblox.jungle`
**Created**: 2026-07-20 01:13:42
**Status**: Requirements Gathering (intake)

## Requirements / goal

Design the lobby (Jungle Airfield) per assets/Images/MapIdea.png. Step 1: agree the spatial layout (zones, landmarks, paths, scale). Step 2: generate a BASE terrain blockout in Studio via MCP (island/sand airfield/water/river shore), verified by read-back + screenshot. Step 3: plan asset placement. Step 4: produce the final lobby asset list (models/props/signs/pads) for the assets job. Applies the jungle-style guide (landmark->path->secondary-area, readable center, mobile-first).

## Decisions & standing rules (2026-07-20)

- **Scale** Medium · **Water** east shore + SE river mouth · **Base scope** Claude does procedural
  base, human sculpts hero detail. (Full detail in `implementation-plan.md`.)
- **NEW standing rule — no visible map edges:** never leave a flat fall-off edge; enclose play areas
  with rising hills + distant mountains + far water shore + fog. (Saved to memory.)
- **NEW standing rule — work must land in the repo:** terrain lives in the Studio place file (not
  Rojo-synced), so the reproducible artifact is the **generator script in git**. Capture targets in
  the job; don't leave work "only in the console."

## Progress

- [x] Layout agreed from `MapIdea.png` (zones/coords in implementation-plan.md)
- [x] Base terrain generated & verified (read-back + screenshots): enclosed valley, hills + snow
      mountains all horizons, east water lobe → SE river mouth, warm haze
- [x] Repo artifact: `lobby/build/generate_base_terrain.luau` (re-runnable generator)
- [x] **v2 fix** — continuous height field: removed hard walls (water now has sloped sand beaches;
      runway is graded + tapered into the hills). Verified by eye-level screenshots.
- [x] Runway lengthened to match the water lobe (~390 studs, Z −490..−100); map north edge
      extended (MINZ −600) so hills/mountains still enclose the longer airstrip.
- [x] `implementation-plan.md` written
- [x] **Base terrain ACCEPTED by user (2026-07-20)** — scale, enclosure, runway/water lengths approved
- [x] Atmosphere/lighting pass done & accepted (warm afternoon jungle, muted teal river) →
      `lobby/build/lobby_atmosphere.luau` + STYLEGUIDE §8
- [x] **Greybox placement pass** — 15 groups (plane+pilot, spawn, 4 party pads, gold/small shops,
      dock+stations, boat, welcome sign, 2 watchtowers, runway markings) at agreed coords →
      `lobby/build/greybox_placement.luau`. Verified by screenshots.
- [ ] User review of greybox (scale/spacing tweaks?)
- [ ] Final lobby asset list → assets job

## PIVOT (2026-07-20) — editor-placed lobby, scripts find-by-name

User direction: the lobby is **hand-placed in the editor**, NOT generated at runtime. Scripts must
**find objects by name** (+ attributes/tags) and **attach actions** (prompts/behavior). Terrain-once
and ambient/color scripts are OK. Chose **"align code to the design."** (Saved to memory:
`lobby-editor-placed-not-scripted`.)

Consequence: the runtime lobby-generation scripts (e.g. `StartShopServer` builds a Robux kiosk at
`HubSpawn+offset`; other stations similarly) get **converted to find-by-name + attach**. The greybox
becomes the real editor lobby (named objects) + human hand-builds/refines the art.

Decisions: canonical stations = **code's set**; scope = **lobby stations only** (leave boat/river/
intro gameplay), start with **Robux Shop**.

- [x] Rebuilt greybox as editor lobby → `lobby/build/greybox_placement.luau`. Under `LOBBY_GREYBOX/`:
      **Stations/** (Spawn, PartyPad_Blue/Red/Green/Yellow, SkillTrainer, Bounties, RobuxShop,
      BoatUpgrades — each Model has attribute `Station` + hidden `Anchor` part for the prompt),
      **Displays/** (Leaderboard_TopRuns, Leaderboard_Weekly, WelcomeSign),
      **Scenery/** (Plane+Pilot, Dock, 2 watchtowers, runway markings, crates/barrels/tents/
      campfires/sandbags/foliage). BoatUpgrades placed at the water per user request.
- [x] **REWIRED `StartShopServer` (Robux Shop)** → finds station by attribute `Station="RobuxShop"`,
      attaches prompt to its `Anchor` at runtime (no more HubSpawn kiosk build). Finder validated in
      Edit against all 6 station types. This is the pattern for the rest.
- [x] **CORRECTION:** StartShopServer is a GAME script (`/sync/`) — mistakenly edited, **reverted**.
      Rule saved (memory + GROUND-RULES §1): don't edit scripts across places; GAME `/sync/` vs LOBBY
      `/lobby/sync/`. The grey box in Play = `Hangar` from `LobbyServer` (lobby), not PlaneWreck.
- [x] **Converted the correct LOBBY scripts** (user approved both): `lobby/sync/.../LobbyStations`
      (kiosks → find editor stations by `Station` attr, attach KioskPrompt→OpenPanel) and
      `LobbyServer` (stop generating world/pads/spawn; bind party/countdown/teleport to editor
      `PartyPad_*`; spawn = editor SpawnLocation). Finders validated (4 pads, 4 kiosks, spawn).
- [ ] Rojo-sync the 2 lobby scripts + Play test (grey world gone; prompts + party work).
- [x] **Populated the full lobby asset requirements** (`lobby-asset-list.md`): objects, foliage
      (dense-forest ring ★), stations, pads, displays, props, decals, icons, VFX, ambient audio, SFX,
      music, lighting-ref. Sourcing (where to get each) = the NEXT step.
- [x] Decide sourcing per item — Creator Store first for 3D (decided 2026-07-20).
- [x] **Foliage kit sourced (Creator Store, scanned) — 2026-07-20:** palms ×3 (Vupatu straight/curved,
      LegendaryFrosts), coconut palm (Trexlty), bush/fern pack (DoctorFir `81654645105891`), tall fern,
      canopy trees pack (PSY0PZ, rings the clearing). All ✅ 0-script scanned. Recorded in tracker +
      shared registry (`Assets/registry/models.md`). Rejected ClawWOMinerm pack (hidden script + 3,335 parts).
      **Pending:** user to paste Store IDs for the 3 user-inserted `CAND_*` items.
- [ ] Next foliage: rocks / fallen logs / vines. Then plane, stations, camp props.
- [x] **Asset list promoted out of the job → root [`/ASSETS.md`](../../ASSETS.md) §1 (user, 2026-07-20):**
      it's the always-referenced, always-updated game-wide asset bible (next to GAME.md/STYLEGUIDE.md),
      wired into CLAUDE.md + jungle-style skill. Requirements/status live there; IDs in the shared
      registry. `lobby-asset-list.md` is now a pointer stub.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
