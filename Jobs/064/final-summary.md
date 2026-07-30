# Final Summary — Job #064

**Project**: `roblox.jungle`
**Completed**: 2026-07-30
**Status**: ✅ Completed

## What was implemented

The lobby (Jungle Airfield) went from nothing to a built, dressed, scripted, audible place —
plus the asset spine the rest of the game now hangs off.

**Terrain & atmosphere.** A procedural base-terrain generator produced an enclosed valley: hills and
snow mountains on every horizon, a graded ~390-stud runway, an east water lobe feeding a SE river
mouth. v2 removed the hard walls in favour of a continuous height field (sloped sand beaches, tapered
runway). A warm-afternoon lighting rig (haze, warm colour correction, bloom, sun rays, muted-teal
water) sits on top. Both are re-runnable scripts in the repo, not console one-offs.

**A standing rule came out of this job:** never leave a visible flat map edge — enclose play areas with
rising hills, distant mountains, far water shore and fog.

**The editor-placed pivot.** Mid-job the direction changed: the lobby is hand-built in the editor, and
scripts **find objects by name/attribute and attach behaviour** rather than generating the world at
runtime. `LobbyStations` and `LobbyServer` were converted accordingly (kiosks bind by `Station`
attribute, party logic binds to editor `PartyPad_*`, spawn is the editor SpawnLocation). A second rule
came out of a mistake here: **never edit scripts across places** — GAME `/sync/` and LOBBY
`/lobby/sync/` are separate, confirm scope first.

**Dressing.** 175 foliage models ring the clearing (terrain-following, Grass-only raycast, centre and
runway kept open), from a localised 7-model library. Rocks, mossy logs, camp props, watchtowers, dock,
plane, pilot, party pads, leaderboards, welcome sign, grass tufts, cargo netting, rope barriers,
windsock, signpost. Third-party inserts were script-scanned; one pack was rejected for a hidden script
and 3,335 parts, and the rejections are logged so they aren't re-sourced.

**Audio.** `LobbySoundscape` plays 2D music + jungle ambience + wind, positional water at the dock,
campfire at both fire pits, rope creak at the watchtowers, and cicada one-shots.

**Assets.** The lobby asset list was promoted out of this job into the game-wide
[`/ASSETS.md`](../../ASSETS.md) bible, and every ID landed in the shared registry. In the final pass
(2026-07-30) three asset batches were sourced, uploaded, recorded **and verified in Studio**:

- **11 lobby SFX** — panel open/close, prompt, pad join, leader assigned, teleport whoosh, purchase
  success, fail, upgrade applied, rank stinger, wood + sand footsteps. Uploaded, **not yet wired**.
- **23 UI icons** — the complete lobby icon set (Flaticon), covering every glyph the GUI needs.
- **7 monetization icons** — 4 gold-pack + 3 game-pass thumbnails, live on the Creator Hub.

Verification wasn't taken on trust: all 41 IDs were checked in Studio via `GetProductInfo` (name match
+ asset type), and the gold-pack icon mapping was confirmed against `IconImageAssetId` rather than
read off a screenshot.

### Files changed

- `lobby/build/generate_base_terrain.luau` — re-runnable base terrain (v2 continuous height field)
- `lobby/build/lobby_atmosphere.luau` — warm-afternoon lighting rig
- `lobby/build/greybox_placement.luau` — the editor lobby layout (stations, displays, scenery)
- `lobby/sync/ServerScriptService/LobbyServer.server.luau` — editor-bound pads/spawn; leader sparkle;
  launch VFX
- `lobby/sync/ServerScriptService/LobbyStations.server.luau` — find-by-attribute kiosks → prompts
- `lobby/sync/ServerScriptService/LobbySoundscape.server.luau` — full lobby soundscape
- `lobby/sync/ServerScriptService/Progression/RankServer.server.luau` — editor leaderboard + #1 glow
- `ASSETS.md` — the game-wide asset bible (§1 lobby, §5 UI, §5.1 monetization, §1.9/§1.9b icons & art)
- `STYLEGUIDE.md §8` — lighting/atmosphere reference
- `roblox.workspace/Assets/registry/{audio,images,models}.md` — all IDs, sources, scan state

## Verification

- [x] Terrain read back + screenshotted (enclosure, runway/water lengths) — **accepted by user**
- [x] Atmosphere pass accepted by user
- [x] Foliage placement verified by screenshot — user: "perfect"
- [x] Station finders validated in Edit against all 6 station types (4 pads, 4 kiosks, spawn)
- [x] All 11 SFX IDs verified in Studio (`GetProductInfo` → name match, AssetTypeId 3 = Audio)
- [x] All 23 icon IDs verified (name match, AssetTypeId 1 = Image; thumbnails render → moderation passed)
- [x] All 7 monetization icons verified (gold packs via `IconImageAssetId`, passes via product-info API)

## Carried forward (not done here — deliberate)

These were open when the job closed and move on rather than being quietly dropped:

1. **Rojo-sync the lobby scripts + Play test** — `LobbyServer` / `LobbyStations` / `LobbySoundscape`
   changes need a sync and an in-Play check (prompts, party flow, audio). **User action.**
2. **Save the place** — foliage and editor placements are place-file content and reset if unsaved.
   **User action.**
3. **Wire the 11 SFX** — uploaded and verified, but no script plays them yet → **the new GUI job.**
4. **Wire the 23 icons** — sourced and verified, screens still text-only → **the new GUI job.**
5. **7 upgrade-item renders** (`ASSETS.md §1.9b`) — the 6 boat modules + gold chest. Blocks only the
   Boat-Upgrades panel and buy popup matching the mockup.
6. **Greybox scale/spacing review** — never formally reviewed; superseded in practice by the dressing
   passes the user accepted.
