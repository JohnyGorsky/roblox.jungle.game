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
- [ ] Convert `StartShopServer` (Robux) → find `Workspace.LOBBY_GREYBOX.Stations.RobuxShop` + attach
      prompt (retire the HubSpawn+offset kiosk build). Pattern for the rest.
- [ ] Then convert BoatUpgrades / SkillTrainer / Bounties / PartyPads similarly.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
