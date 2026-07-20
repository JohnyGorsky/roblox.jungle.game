# ASSETS.md — Last River (Jungle) asset bible

**The single, always-referenced list of every asset the game needs and what we actually use.** Game-wide,
living document. Style per the **`jungle-style`** skill (stylized jungle-expedition, chunky/readable,
weathered) + **[STYLEGUIDE.md](STYLEGUIDE.md)**.

> **THE RULE:** consult this before sourcing/building any asset, and **update it whenever an asset is
> used, added, swapped, or retired**. If it's in the game, it's in this file.

## How this file works (and its relationship to the registry)

- **This file = requirements + decisions + status** (the design logic): *what each area needs*, the
  chosen source, priority, and whether it's sourced/built/pending.
- **Exact asset IDs / license / scan state live in the shared cross-game registry** →
  [`../roblox.workspace/Assets/registry/`](../roblox.workspace/Assets/registry/) (`models.md`,
  `meshes.md`, `images.md`, `audio.md`, `animations.md`, `ui.md`). **Grep the registry before sourcing
  anything new — we may already own it.** This file links there rather than duplicating IDs.
- Third-party inserts are **script-scanned before use** (`roblox-assets` skill; foliage/props must have
  **0 scripts**). Rejected assets are logged so we don't re-source them.
- **Localize what we reuse:** approved third-party models are copied into a clean-named **library folder
  in the place** (e.g. `ServerStorage/AssetLibrary/Foliage/`), renamed plainly, parts anchored — then we
  **duplicate from the library**. This removes the dependency on the Store *listing* surviving and on
  chasing origin IDs. The registry records the origin ID *when known* + the library path.

**Status legend:** ✅ sourced/built · ⏳ in progress · ▫ queued · ⏸ pending (needs you) · ❌ rejected.

## Global sourcing plan (decided 2026-07-20)
- **3D models / props / foliage / structures → Creator Store** first (Claude searches → presents
  candidates → you approve → Claude inserts + **scans** + deletes junk). **Meshy** only as fallback.
- **Images — decals / painted art / signage / UI icons → ChatGPT (you generate)** → upload → give Claude
  the `rbxassetid://` → Claude wires them in. (UI icon IDs also → `STYLEGUIDE.md §7`.)
- **Audio — ambient / SFX / music → you source** (Pixabay etc.) & upload → give Claude the IDs.
- **VFX (particles / beams / lights) → build in Studio** (Claude authors; no external asset).
- **Party pads · leaderboards · sign text · HUD → build** (parts + SurfaceGui/GUI).

Interactive objects stay a **named Model + `Station` attribute + `Anchor` part** so scripts bind to them
(memory: `lobby-editor-placed-not-scripted`).

---

# 1) LOBBY — Jungle Airfield

Everything the lobby needs to be finished. Reference `assets/Images/MapIdea.png` + `jungle_example.png`.

**Priority:** **P1** cargo plane · palm/tree/bush foliage kit · station buildings · party pads —
**P2** camp props · signs · leaderboards · lanterns/torches — **P3** fine detail · ground decals ·
ambient VFX.

## 1.1 Foliage — the jungle floor
The grass band must read as **dense jungle**, not bare grass — a **kit of variants** placed in clusters
(styleguide: cluster, frame the play area, keep the center readable).

**★ DENSE FOREST requirement (2026-07-20):** the whole grass ring between the sand clearing and the
mountains must read as dense jungle (heavily packed palms/trees + bushes/ferns, like
`jungle_example.png`), denser toward the mountains; the sand play-center stays open. This frames the
lobby and hides the edges. **Placement:** editor-placed by hand and/or a one-time editor scatter helper
(allowed) — never runtime.

**Localized masters:** all approved foliage is copied into a clean-named library
**`ServerStorage/AssetLibrary/Foliage/`** (lobby place). We **duplicate from there** to place/scatter —
no dependency on the Store listing surviving, and no need for the origin Store ID. All parts anchored.

**✅ PLACED (2026-07-20):** greybox trees/bushes replaced with real models + a terrain-following dense
ring scattered around the clearing (Grass-only, denser toward the mountains, sand center + runway kept
open). ~148 models in `Workspace/LOBBY_GREYBOX/Scenery/Foliage`. Bulk uses the light MeshPart models
(PalmCoconut/PalmLowPoly/FernTall); the part-heavy Vupatu palms are used sparingly. **Master fix:**
`FernTall` mesh had a 39° baked tilt — corrected in the library master so it stands upright.

| Library master | Want | Origin | Status | Notes |
|---|---|---|---|---|
| `PalmTall` | ✓ | Store (Vupatu `5031791950`) | ✅ | chunky stylized; matched pair w/ PalmCurved |
| `PalmCurved` | ✓ | Store (Vupatu `5031794668`) | ✅ | leaning variant |
| `PalmLowPoly` | ✓ | Store (LegendaryFrosts `1436325105`) | ✅ | darker/thinner silhouette variant |
| `PalmCoconut` | ✓ | Store (Trexlty `18363394399`) | ✅ | 4 meshes |
| `BushPack` | 3+ | Store (DoctorFir `81654645105891`) | ✅ | 8 meshes; broadleaf + small foliage + flowers |
| `FernTall` | ✓ | Store (origin ID unknown) | ✅ | localized master; large ground leaf |
| `JungleTreesPack` | ✓ | Store (PSY0PZ, origin ID unknown) | ✅ | 102 meshes; pre-arranged, rings the clearing. Dupe deleted. |
| Rocks (S/M/L) | 3 | Store | ⏳ next search | shoreline + jungle floor |
| Fallen log / roots | 2 | Store | ⏳ next search | environmental storytelling |
| Vines / hanging | 1–2 | Store | ⏳ next search | drape on towers/trees |
| Grass tuft / clump | 2 | Build/Store | ▫ | editor-scatter in clusters |

❌ **Rejected:** *Jungle Trees Pack* (ClawWOMinerm `119737242130790`) — hidden `Script` + 3,335 parts;
deleted per scan rule. Do not re-source.

## 1.2 Landmark
| Object | Qty | Source | Status | Notes |
|---|---|---|---|---|
| Cargo plane (1940s–70s, olive, big props) | 1 | Meshy | ▫ P1 | parked/half-crashed; `Scenery.Plane`. A crashed-plane Meshy asset already exists in `assets/Objects/Plane/` |
| Pilot NPC | 1 | Meshy (roblox-chars) | ▫ | stands by the plane; talk-to-start flavor |

## 1.3 Station buildings / kiosks (interactive — name + `Station` attr + `Anchor`)
| Station | Object | Source | Status | Notes |
|---|---|---|---|---|
| `SkillTrainer` | wooden stall + counter + sign | Store/Build | ▫ | blue accent |
| `Bounties` | board stand / stall | Store/Build | ▫ | gold accent |
| `RobuxShop` | small kiosk | Store/Build | ▫ | green; prompt wired ✅ |
| `BoatUpgrades` | mechanic rig/bench at the dock | Store/Build | ▫ | green; at the water |
| Sign boards (per station) | 4+ | Build + Flaticon | ▫ | wood/metal, thick border, icon + ALL-CAPS (styleguide §20) |

## 1.4 Party / launch pads (interactive)
| Object | Qty | Source | Status | Notes |
|---|---|---|---|---|
| Party pad (wood+metal ring, glowing center, group icon) | 4 (Blue/Red/Green/Yellow) | Build + Flaticon | ▫ | `PartyPad_*`; edge lights; never obscured |

## 1.5 Water / dock
| Object | Qty | Source | Status | Notes |
|---|---|---|---|---|
| Dock / jetty (planks + posts) | 1 | Store/Build | ▫ | east shore |
| Winch / mooring post | 1 | Store | ▫ | rope tie point |
| Boat (moored display) | 1 | cross-ref gameplay | ▫ | real boat is BoatServer's (own job); lobby shows it moored — see `boat_ideas.png` (3 tiers) |

## 1.6 Structures / scenery
| Object | Qty | Source | Status | Notes |
|---|---|---|---|---|
| Watchtower | 2 | Store/Build | ▫ | legs + platform + tarp roof |
| Welcome sign | 1 | Build | ▫ | "WELCOME TO JUNGLE AIRFIELD", stencil font |
| Leaderboard board | 2 (Top Runs, Weekly) | Build + SurfaceGui | ▫ | wood/metal, gold/blue trim; live text |
| Tents / tarps | 3–4 | Store | ▫ | canvas, olive |
| Cargo netting | 2 | Store | ▫ | strung between posts |
| Windsock | 1 | Store | ▫ | airfield flavor (reads wind) |
| Path fences / rope barriers | few | Store | ▫ | line the curved sand paths |
| Directional path markers / lanterns | few | Build/Store | ▫ | guide flow (styleguide §24) |
| Sky / clouds | 1 | Store/Build | ▫ | warm `Sky` + `Clouds` to complement Atmosphere |

## 1.7 Camp props (environmental storytelling — cluster meaningfully)
Wooden crate ×3 · metal military crate ×2 · oil barrel/fuel drum ×2 · fuel can · sandbags · campfire
(Build+VFX) · lantern/hanging lamp ×2 · tiki torch · toolbox/wrenches ×2 · spare tire · cargo pallet ×2 ·
rope coil/radio/small table ×3. **Source:** Store · **Status:** ▫ P2–P3.

## 1.8 Ground / decals
| Object | Source | Status | Notes |
|---|---|---|---|
| Airfield star (spawn) | ChatGPT/Flaticon → decal | ⏸ | painted military star |
| Runway "27" + stripes | Build/decal | ▫ | cream markings |
| Path decals (sand/dirt/tire tracks) | ChatGPT → decal | ⏸ | curved paths connecting zones (styleguide §24) |

## 1.9 UI icons (signs + HUD) — Flaticon
Gear (engine) · Shield (hull) · Fuel pump (fuel) · Crate (storage) · Crossed tools (equipment) · Star
(gold/major) · Wrench (utility) · Player-group (party). One consistent set → IDs go to `STYLEGUIDE.md §7`
+ registry `images.md`. **Status:** ⏸ pending your generation/upload.

## 1.10 VFX (particles / beams / lights) — build in Studio
Party-pad glow ring (×4) · leader sparkle · launch effect (light column + dust burst) · campfire
(fire+smoke+embers+light) · torch/lantern flame · fireflies/motes · sun-ray dust motes · water
shimmer/ripples/foam · plane heat-haze · flag/tarp wind sway · purchase-confirm burst · leaderboard #1
glow. **Status:** ▫ Claude builds. Mobile budget: pooled, capped, distance-LOD'd, off-screen-culled
(STYLEGUIDE §8).

## 1.11 Audio — Ambient (looping beds, mostly spatial) — ✅ UPLOADED + ✅ IMPLEMENTED
IDs → registry [`audio.md`](../roblox.workspace/Assets/registry/audio.md) (Jungle section).
Jungle day ambience 1 & 2 · wind/breeze · water lapping (`water-splashes`) · campfire crackle
(`crackle-campfire`) · cicadas/wildlife. ⏸ Flag/rope creak — not yet uploaded.
**Wired by** `lobby/sync/ServerScriptService/LobbySoundscape.server.luau`: 2D ambience+wind beds,
positional water @ `Dock.Pier`, positional campfire @ both `FirePit`s, cicada one-shots every ~18–44s.
(Needs Rojo sync + Play to hear.)

## 1.12 Audio — SFX (events / one-shots) — ⏸ pending upload
UI click/tap · panel open/close · purchase success · purchase fail · upgrade applied · pad join/leave ·
leader assigned · countdown tick · launch/teleport whoosh · prompt appear/hold-complete · footsteps
(sand vs wood) · rank/reward stinger.

## 1.13 Music — ✅ UPLOADED · lobby theme ✅ IMPLEMENTED
IDs → registry `audio.md`. Lobby theme (`lobby_intro_music`) ✅ wired 2D in `LobbySoundscape`.
`morning_starts` / `night_starts` / `battle_starts` are day-night/combat cues for the GAME place (not the
static-afternoon lobby). ⏸ Countdown/launch layer — optional, not yet uploaded.

## 1.14 Lighting — ✅ APPLIED (reference, not to re-source)
Warm-afternoon rig live (STYLEGUIDE §8 / `lobby/build/lobby_atmosphere.luau`): Atmosphere haze, warm
ColorCorrection, Bloom, SunRays, muted-teal water. Set `Lighting.Technology = Future` in Studio.

### Open questions (lobby assets pass)
- [ ] How many palm/tree variants is "enough" for the density (current kit: 4 palms + trees pack + bush pack + fern)?
- [ ] Editor hand-place vs one-time scatter helper for the dense foliage?
- [ ] Boat model: lobby display here, or fully in the boat/gameplay job?

---

# 2) BOAT
_Stub — populate as the boat/gameplay job sources assets._ Hull/motor/searchlight/upgrade-module visuals,
boat SFX (engine loop, start, on-fire, destroyed, metal hit — some already in `assets/Objects/Boat/Sounds/`).

# 3) RIVER / WORLD
_Stub._ River obstacles (rocks, logs, sandbars, wreck debris), set-pieces (waterfalls, ramps, dam
blockages), docks/piers, zone dressing, day/night set-pieces.

# 4) ENEMIES / CHARACTERS
_Stub._ Sea + land enemies (Meshy via `roblox-chars`), glowing-eyes treatment, alligator (SFX exist in
`assets/Objects/Monsters/`), player-carried torch/lamp.

# 5) UI / HUD (global)
_Stub._ Loading screen art, teleport/intro sequence art, HUD icons, role-suitability icons. Design system
= `jungle-style` + STYLEGUIDE.

# 6) GLOBAL AUDIO
_Stub._ Cross-place music/SFX beyond the lobby (combat, ambience per zone). Existing uploads catalogued in
registry `audio.md`.
