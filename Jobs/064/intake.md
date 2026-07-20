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
- [x] `implementation-plan.md` written
- [ ] User walks the base & confirms scale/spots
- [ ] Asset placement pass (markers → props)
- [ ] Final lobby asset list → assets job

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
