# ASSETS.md — Last River (Jungle) asset bible

**The single, always-referenced list of every asset the game needs and what we actually use.** Game-wide,
living document. Style per the **`jungle-style`** skill (stylized jungle-expedition, chunky/readable,
weathered) + **[STYLEGUIDE.md](STYLEGUIDE.md)**.

> **THE RULE:** consult this before sourcing/building any asset, and **update it whenever an asset is
> used, added, swapped, or retired**. If it's in the game, it's in this file. **Every asset section is a
> table; done rows are green.**

## How this file works (and its relationship to the registry)

- **This file = requirements + decisions + status** (design logic): *what each area needs*, chosen source,
  and whether it's sourced/built/pending.
- **Exact asset IDs / license / scan state live in the shared cross-game registry** →
  [`../roblox.workspace/Assets/registry/`](../roblox.workspace/Assets/registry/) (`models.md`, `meshes.md`,
  `images.md`, `audio.md`, `animations.md`, `ui.md`). **Grep the registry before sourcing anything new.**
- Third-party inserts are **script-scanned before use** (`roblox-assets`; foliage/props must have 0 scripts).
  Rejected assets are logged so we don't re-source them.
- **Localize what we reuse:** approved third-party models are copied into a clean-named library folder in the
  place (e.g. `ServerStorage/AssetLibrary/…`), renamed, anchored — then we **duplicate from the library**.
  Registry records the origin ID *when known* + the library path.

**Status legend:** <span style="color:#2e9c3f">✅ done</span> · <span style="color:#c9911d">⏳ in progress</span> · ▫ queued · <span style="color:#c9911d">⏸ pending (you)</span> · <span style="color:#c93c3c">❌ rejected</span>. **Green = done.**

## Global sourcing plan (decided 2026-07-20)

| Asset type | Source | How |
|---|---|---|
| 3D models / props / foliage / structures | Creator Store (Meshy fallback) | Claude searches → you approve → scan → localize → place |
| Images (decals / art / signage / UI icons) | ChatGPT (you generate) | upload → give `rbxassetid://` → Claude wires (icon IDs also → STYLEGUIDE §7) |
| Audio (ambient / SFX / music) | You (Pixabay etc.) | upload → give IDs |
| VFX (particles / beams / lights) | Build in Studio | Claude authors (no external asset) |
| Party pads · leaderboards · signs · HUD | Build | parts + SurfaceGui/GUI |

Interactive objects stay a **named Model + `Station` attribute + `Anchor` part** so scripts bind to them
(memory: `lobby-editor-placed-not-scripted`).

---

# 1) LOBBY — Jungle Airfield

Everything the lobby needs. Reference `assets/Images/MapIdea.png` + `jungle_example.png`.
**Priority:** **P1** plane · foliage · station buildings · party pads — **P2** camp props · signs ·
leaderboards · lanterns — **P3** fine detail · ground decals · ambient VFX.

## 1.1 Foliage — the jungle floor

> **★ Dense-forest ring:** the grass band between the sand clearing and the mountains must read as dense
> jungle (packed palms/trees + bushes/ferns), denser toward the mountains; sand center + runway kept open.
> **Localized** to `ServerStorage/AssetLibrary/Foliage/` (duplicate from there). **✅ Placed:** 175 models
> evenly ringing the clearing (Grass-only raycast, shuffle-then-place). `FernTall` 39° tilt fixed at master.

| Library master | Want | Origin | Status | Notes |
|---|---|---|---|---|
| `PalmTall` | ✓ | Store (Vupatu `5031791950`) | <span style="color:#2e9c3f">✅ placed</span> | chunky stylized; matched pair w/ PalmCurved (heavy ~64 parts) |
| `PalmCurved` | ✓ | Store (Vupatu `5031794668`) | <span style="color:#2e9c3f">✅ placed</span> | leaning variant |
| `PalmLowPoly` | ✓ | Store (LegendaryFrosts `1436325105`) | <span style="color:#2e9c3f">✅ placed</span> | darker/thinner (MeshPart, light) |
| `PalmCoconut` | ✓ | Store (Trexlty `18363394399`) | <span style="color:#2e9c3f">✅ placed</span> | 4 meshes, light |
| `BushPack` | 3+ | Store (DoctorFir `81654645105891`) | <span style="color:#2e9c3f">✅ placed</span> | 8 meshes; broadleaf + small + flowers |
| `FernTall` | ✓ | Store (origin unknown) | <span style="color:#2e9c3f">✅ placed</span> | large ground leaf; tilt fixed |
| `JungleTreesPack` | ✓ | Store (PSY0PZ, origin unknown) | <span style="color:#2e9c3f">✅ placed</span> | 102 meshes; pre-arranged; dupe deleted |
| Rocks S/M/L (`RockA/B/C`) | 3 | Store ("rocks 3" `13967717089`) | <span style="color:#2e9c3f">✅ placed</span> | `AssetLibrary/Rocks`; ~24 on floor + Sand shore; embedded |
| Fallen log (`LogMossy`) | 2 | Store (OptOff `18497743057`) | <span style="color:#2e9c3f">✅ placed</span> | `AssetLibrary/Logs`; 6 near tree line; realistic moss |
| Vines / hanging | 1–2 | Store | <span style="color:#c9911d">⏸ deferred</span> | Rotanix `9376334307` clean but skipped; others had scripts |
| Grass tuft / clump | 2 | Build/Store | ▫ queued | editor-scatter in clusters |

<span style="color:#c93c3c">❌ Rejected:</span> *Jungle Trees Pack* (ClawWOMinerm `119737242130790`) — hidden `Script` + 3,335 parts. Do not re-source.

## 1.2 Landmark

| Object | Qty | Source | Status | Notes |
|---|---|---|---|---|
| Cargo plane (olive, big props) | 1 | Meshy (user) | <span style="color:#2e9c3f">✅ placed</span> | `Scenery.Plane` (+ `AssetLibrary/Plane`). 1 MeshPart 53×57. CollisionFidelity = PreciseConvexDecomposition (walk under wings) |
| Pilot NPC | 1 | Meshy (user) | <span style="color:#2e9c3f">✅ placed + rigged</span> | `workspace.Pilot` (+ `AssetLibrary/Characters/Pilot`). 22-bone rig; idle `71254620030056` looped by `PilotIdle.server.luau` |
| Airstrip / runway | 5 tiles | Store (user) | <span style="color:#2e9c3f">✅ placed</span> | Cracked-concrete, tiled corridor (z −154→−485). Master `AssetLibrary/Plane/RunWay` |

## 1.3 Station buildings / kiosks (interactive — name + `Station` attr + `Anchor`)

| Station | Object | Source | Status | Notes |
|---|---|---|---|---|
| `SkillTrainer` | wooden stall + counter + sign | Meshy (user) | <span style="color:#2e9c3f">✅ swapped</span> | user Meshy stall (blue awning + chalkboard); Station attr + Anchor/prompt transferred, grounded, entry sign, localized to `AssetLibrary/Structures/SkillTrainer` |
| `Bounties` | board stand / stall | Meshy (user) | <span style="color:#2e9c3f">✅ swapped</span> | user Meshy object; Station attr + Anchor/prompt transferred, grounded, localized to `AssetLibrary/Structures/Bounties` |
| `RobuxShop` | small kiosk | Meshy (user) | <span style="color:#2e9c3f">✅ swapped</span> | user Meshy hut/kiosk; Station attr + Anchor/prompt transferred, grounded, entry sign, localized to `AssetLibrary/Structures/RobuxShop` |
| `BoatUpgrades` | mechanic rig/bench at the dock | Meshy (user) | <span style="color:#2e9c3f">✅ swapped</span> | user Meshy object; Station attr + Anchor/prompt transferred, grounded, localized to `AssetLibrary/Structures/BoatUpgrades` |
| Sign boards (per station) | 4+ | Build + Flaticon | ▫ queued | wood/metal, icon + ALL-CAPS (styleguide §20) |

## 1.4 Party / launch pads (interactive)

| Object | Qty | Source | Status | Notes |
|---|---|---|---|---|
| Party pad (launch platform) | 4 (Blue/Red/Green/Yellow) | Build | <span style="color:#2e9c3f">✅ built (v2)</span> | Redesigned from flat discs → raised diamond-plate platform + wood deck, glowing accent center-ring + dark metal `Center` (kept for LobbyServer detection), colored light-beam column, 8 edge lights, rising motes. Station/PadColor/Anchor kept. Group icon ⏸ (needs Flaticon). |

## 1.5 Water / dock

| Object | Qty | Source | Status | Notes |
|---|---|---|---|---|
| Dock / jetty | 1 | Store (Sxphies `3023220773`) | <span style="color:#2e9c3f">✅ placed</span> | `AssetLibrary/Structures/Dock` at east water; `Pier` part kept for soundscape |
| Winch / mooring post | 1 | Store | ▫ queued | rope tie point |
| Boat (moored display) | 1 | cross-ref gameplay | ▫ queued | real boat is BoatServer's; lobby shows it moored (`boat_ideas.png`) |

## 1.6 Structures / scenery

| Object | Qty | Source | Status | Notes |
|---|---|---|---|---|
| Watchtower | 2 | Store (RangerTower `81318418778699`) | <span style="color:#2e9c3f">✅ placed</span> | `AssetLibrary/Structures/RangerTower` @0.7 → `Watchtower_NW/NE` |
| Welcome sign | 1 | Build | <span style="color:#2e9c3f">✅ built</span> | wood + gold trim; SurfaceGui "WELCOME TO JUNGLE AIRFIELD" (Special Elite, cream+stroke) on both faces |
| Leaderboard board | 2 (Top Runs, Weekly) | Build + SurfaceGui | <span style="color:#2e9c3f">✅ built</span> | wood + gold/blue trim; `RankServer` rewired to fill editor `Leaderboard_TopRuns` (find-by-name) with live Top-10; Weekly = "coming soon" placeholder (no weekly data yet) |
| Tents / tarps | 3–4 | Store | <span style="color:#2e9c3f">✅ (2 placed)</span> | olive canvas (see camp props); more optional |
| Cargo netting | 2 | Store | ▫ queued | strung between posts |
| Windsock | 1 | Store | ▫ queued | airfield flavor (reads wind) |
| Path fences / rope barriers | few | Store | ▫ queued | line the curved sand paths |
| Directional markers / lanterns | few | Build/Store | ▫ queued | guide flow (styleguide §24) |
| Sky / clouds | 1 | Store/Build | ▫ queued | warm `Sky` + `Clouds` to complement Atmosphere |

## 1.7 Camp props (environmental storytelling — cluster meaningfully)

> **✅ Placed:** localized to `AssetLibrary/Props` + placed in `Scenery/CampProps` (25 models, replaced 41
> greybox placeholders). Grounded by raycast. Heavy parts (CrateWood 66, BarrelsSet 62) used sparingly.

| Object | Qty | Source | Status | Notes |
|---|---|---|---|---|
| Wooden crate (`CrateWood`) | 4 clusters | Store (`3335320854`) | <span style="color:#2e9c3f">✅ placed</span> | heavy (66 parts) — sparse use |
| Ammo box (`AmmoBox`) | several | Store (`12523523963`) | <span style="color:#2e9c3f">✅ placed</span> | olive; stacks with crates |
| Barrel (`Barrel`) | 3 groups | Store (`3160087663`) | <span style="color:#2e9c3f">✅ placed</span> | rusty, light |
| Barrels set (`BarrelsSet`) | 1 | Store (`16944361687`) | <span style="color:#2e9c3f">✅ placed</span> | cluster, ~62 parts |
| Tent (`Tent`) | 2 | Store (`7992921193`) | <span style="color:#2e9c3f">✅ placed</span> | olive canvas @0.5 |
| Sandbag wall / barrier | 2 rows | Store (`119411292085005` / `78010383039337`) | <span style="color:#2e9c3f">✅ placed</span> | north line |
| Fuel can | 1 | Store | ▫ queued | handheld |
| Campfire | 1 | Build + VFX | ▫ queued | fire/smoke/embers + light |
| Lantern / tiki torch | 2+ | Store | ▫ queued | warm night light |
| Toolbox / spare tire / cargo pallet / rope / radio | few | Store | ▫ queued | fine detail (P3) |

## 1.8 Ground / decals

| Object | Source | Status | Notes |
|---|---|---|---|
| Airfield star (spawn) | ChatGPT/Flaticon → decal | <span style="color:#c9911d">⏸ pending</span> | painted military star |
| Runway "27" + stripes | Build/decal | ▫ queued | cream markings |
| Path decals (sand/dirt/tire tracks) | ChatGPT → decal | <span style="color:#c9911d">⏸ pending</span> | curved paths connecting zones (styleguide §24) |

## 1.9 UI icons (signs + HUD) — Flaticon

> One consistent set → IDs go to `STYLEGUIDE.md §7` + registry `images.md`.

| Icon | Use | Source | Status |
|---|---|---|---|
| Gear | engine | Flaticon | <span style="color:#c9911d">⏸ pending</span> |
| Shield | hull | Flaticon | <span style="color:#c9911d">⏸ pending</span> |
| Fuel pump | fuel | Flaticon | <span style="color:#c9911d">⏸ pending</span> |
| Crate | storage | Flaticon | <span style="color:#c9911d">⏸ pending</span> |
| Crossed tools | equipment | Flaticon | <span style="color:#c9911d">⏸ pending</span> |
| Star | gold / major | Flaticon | <span style="color:#c9911d">⏸ pending</span> |
| Wrench | utility | Flaticon | <span style="color:#c9911d">⏸ pending</span> |
| Player-group | party | Flaticon | <span style="color:#c9911d">⏸ pending</span> |

## 1.10 VFX (particles / beams / lights) — build in Studio

> Mobile budget: pooled, capped, distance-LOD'd, off-screen-culled (STYLEGUIDE §8).

| Effect | Where | Source | Status |
|---|---|---|---|
| Party-pad glow ring / motes | each of 4 pads | Build | <span style="color:#2e9c3f">✅ built</span> | rising accent-tinted glow motes on each pad Center |
| Leader sparkle | leader on a pad | Build | ▫ queued |
| Launch effect (light column + dust burst) | pad → teleport | Build | ▫ queued | needs hook into LobbyServer launch |
| Campfire (fire+smoke+embers+light) | FirePits | <span style="color:#2e9c3f">✅ built</span> | Fire + Smoke + ember ParticleEmitter + warm PointLight on both `FirePit`s |
| Torch / lantern flame | each torch/lantern | Build | ▫ queued | needs torch/lantern props first |
| Fireflies / motes | jungle edge | Build | <span style="color:#2e9c3f">✅ built</span> | 6 firefly clusters on the grass ring (`AmbientVFX`) |
| Sun-ray dust motes | open airfield | Build | <span style="color:#2e9c3f">✅ built</span> | fine drifting dust field over the clearing (`AmbientVFX`) |
| Water shimmer / ripples / foam | river + dock | Build | ▫ queued |
| Plane heat-haze / smoke puff | plane | Build | ▫ queued |
| Flag / tarp wind sway | flags, tents | Build | ▫ queued |
| Purchase-confirm burst | on buy | Build | ▫ queued |
| Leaderboard #1 glow | Top Runs board | Build | ▫ queued |

## 1.11 Audio — Ambient (looping beds, mostly spatial)

> IDs → registry [`audio.md`](../roblox.workspace/Assets/registry/audio.md). Wired by
> `lobby/sync/ServerScriptService/LobbySoundscape.server.luau` (needs Rojo sync + Play to hear).

| Sound | Where | Status | Notes |
|---|---|---|---|
| Jungle day ambience 1 & 2 | 2D bed | <span style="color:#2e9c3f">✅ wired</span> | birds + insects loop |
| Wind / breeze | 2D bed | <span style="color:#2e9c3f">✅ wired</span> | light layer |
| Water lapping (`water-splashes`) | @ `Dock.Pier` | <span style="color:#2e9c3f">✅ wired</span> | positional |
| Campfire crackle (`crackle-campfire`) | @ both `FirePit`s | <span style="color:#2e9c3f">✅ wired</span> | positional |
| Cicadas / wildlife | 2D one-shots | <span style="color:#2e9c3f">✅ wired</span> | every ~18–44s |
| Rope creak (`rope_creak`) | @ watchtowers | <span style="color:#2e9c3f">✅ wired</span> | positional loop in `LobbySoundscape` |

## 1.12 Audio — SFX (events / one-shots)

| Sound | Trigger | Status |
|---|---|---|
| UI click / tap (`ui_mouse_click`) | any button | <span style="color:#2e9c3f">✅ wired</span> — `UIClick.local.luau` |
| Panel open / close | shop / skills / bounties / robux | <span style="color:#c9911d">⏸ pending</span> |
| Purchase success | buy confirmed | <span style="color:#c9911d">⏸ pending</span> |
| Purchase fail / error | insufficient funds / cancel | <span style="color:#c9911d">⏸ pending</span> |
| Upgrade applied | boat/skill upgrade bought | <span style="color:#c9911d">⏸ pending</span> |
| Pad join / leave | step on/off a party pad | <span style="color:#c9911d">⏸ pending</span> |
| Leader assigned | first player on an empty pad | <span style="color:#c9911d">⏸ pending</span> |
| Countdown tick (`timer_countdown`) | each second of launch countdown | <span style="color:#2e9c3f">✅ wired</span> — `LobbyServer` positional on pad |
| Launch / teleport whoosh | party launches | <span style="color:#c9911d">⏸ pending</span> |
| Prompt appear / hold-complete | ProximityPrompt | <span style="color:#c9911d">⏸ pending</span> |
| Footsteps — sand vs wood | material-aware (optional) | <span style="color:#c9911d">⏸ pending</span> |
| Rank / reward stinger | leaderboard / rank change | <span style="color:#c9911d">⏸ pending</span> |

## 1.13 Music

> IDs → registry `audio.md`. `morning_starts` / `night_starts` / `battle_starts` belong to the GAME place
> (day-night/combat), not the static-afternoon lobby.

| Track | Where | Status | Notes |
|---|---|---|---|
| Lobby theme (`lobby_intro_music`) | 2D loop | <span style="color:#2e9c3f">✅ wired</span> | in `LobbySoundscape` |
| Countdown / launch layer | on pad countdown | <span style="color:#c9911d">⏸ pending</span> | optional, not yet uploaded |

## 1.14 Lighting

| Rig | Status | Notes |
|---|---|---|
| Warm-afternoon jungle rig | <span style="color:#2e9c3f">✅ applied</span> | Atmosphere haze (Density 0.40/Haze 2.7), warm ColorCorrection, Bloom, SunRays, muted-teal water. `lobby/build/lobby_atmosphere.luau` / STYLEGUIDE §8. Set `Lighting.Technology = Future` in Studio. **Save the place or it resets.** |

### Open questions (lobby)

| # | Question |
|---|---|
| 1 | Enough palm/tree variety for the density? (current: 4 palms + trees pack + bush pack + fern) |
| 2 | Editor hand-place vs one-time scatter helper for future foliage? |
| 3 | Boat model — lobby display here, or fully in the boat/gameplay job? |

---

# 2) BOAT

| Area | Items | Status | Notes |
|---|---|---|---|
| Boat visuals | hull / motor / searchlight / upgrade-module parts | ▫ stub | populate as boat/gameplay job sources them |
| Boat SFX | engine loop, start, on-fire, destroyed, metal hit | <span style="color:#2e9c3f">✅ some exist</span> | in `assets/Objects/Boat/Sounds/` |

# 3) RIVER / WORLD

| Area | Items | Status |
|---|---|---|
| Obstacles | rocks, logs, sandbars, wreck debris | ▫ stub |
| Set-pieces | waterfalls, ramps, dam blockages | ▫ stub |
| Docks / piers (river) | reuse `AssetLibrary/Structures/Dock` | ▫ stub |
| Zone dressing / day-night set-pieces | per-zone props + lighting | ▫ stub |

# 4) ENEMIES / CHARACTERS

| Area | Items | Status | Notes |
|---|---|---|---|
| Sea + land enemies | Meshy via `roblox-chars` | ▫ stub | glowing-eyes treatment planned |
| Alligator | model + SFX | <span style="color:#2e9c3f">✅ SFX exist</span> | in `assets/Objects/Monsters/` |
| Player torch / lamp | carried light item | ▫ stub | night survival |

# 5) UI / HUD (global)

| Area | Items | Status |
|---|---|---|
| Loading screens | lobby + game (built in code) | <span style="color:#2e9c3f">✅ built</span> |
| Teleport / intro sequence art | plane-crash cold-open visuals | ▫ stub |
| HUD icons / role-suitability icons | per `jungle-style` + STYLEGUIDE | ▫ stub |

# 6) GLOBAL AUDIO

| Area | Items | Status | Notes |
|---|---|---|---|
| Cross-place music / SFX | combat, per-zone ambience | ▫ stub | existing uploads in registry `audio.md` |
