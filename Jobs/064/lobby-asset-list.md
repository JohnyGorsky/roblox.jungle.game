# Lobby — Required Assets List (Jungle Airfield)

**Project**: `roblox.jungle` · Job #064 · drafted 2026-07-20

**Everything the lobby needs to be finished** — objects, foliage, VFX, audio (ambient + SFX), and
music. Style per the `jungle-style` guide (stylized jungle-expedition, chunky/readable, weathered).

> **Sourcing (where to get each) is the NEXT step** — this doc first captures **WHAT** we need. The
> `Source` columns below are provisional suggestions, not decisions. **Source key:** `Meshy` = custom
> 3D · `Store` = Creator Store · `Flaticon` = UI icon · `Build` = Studio parts/GUI · `ChatGPT` =
> decal/art · `Pixabay` = audio. All final sourcing per `GROUND-RULES §4` + `roblox-assets`.

Every interactive object stays a **named Model + `Station` attribute + `Anchor` part** so scripts bind
to it (memory: lobby-editor-placed-not-scripted).

## Sourcing plan (decided 2026-07-20)
- **3D models / props / foliage / structures → Creator Store** (Roblox assets, free/paid). Claude
  searches + presents candidates (name / creator / id); **you approve**; Claude inserts + **scans for
  scripts** and deletes anything unneeded (`roblox-assets`). Meshy only as fallback if nothing fits.
- **Images — decals, painted airfield star, signage art, UI icons → ChatGPT (you generate)** → upload
  to Roblox → hand Claude the `rbxassetid://` → Claude wires them in.
- **Audio — ambient / SFX / music → you source** (Pixabay etc.) → give Claude the IDs.
- **VFX (particles / beams / lights) → Build in Studio** (Claude authors; no external asset).
- **Party pads · leaderboards · sign text · HUD → Build** (parts + SurfaceGui/GUI).

Chosen assets are recorded in **Sourcing tracker** (bottom) + the shared asset registry.

## Priority
- **P1 (hero / blocks the look):** cargo plane, palm/tree set + bushes (the jungle floor), station buildings, party pads.
- **P2:** camp props (crates/barrels/tents/sandbags), signs, leaderboards, lanterns/torches.
- **P3:** fine detail (ropes, radios, tools, tires), ground decals, ambient VFX/audio.

---

## 1. Foliage — the jungle floor  ← (addresses jungle_example.png: grass filled with trees + bushes)
The grass band must read as **dense jungle**, not bare grass. We need a **kit of variants** placed in
clusters (styleguide: cluster, don't scatter singles; frame the play area, keep the center readable).

| Object | Variants | Source | Notes |
|---|---|---|---|
| Palm tree | 3–4 (tall/leaning/short/coconut) | Meshy / Store | Hero jungle silhouette; low-poly-ish, chunky fronds |
| Jungle broadleaf tree | 2–3 | Meshy / Store | Fills canopy behind palms |
| Bush / shrub | 3 (small/med/flowering) | Meshy / Store | The "small bushes" from the reference |
| Fern / large leaf | 2–3 | Meshy / Store | Ground cover near banks/paths |
| Grass tuft / clump | 2 | Build/Store | Editor-scatter in clusters (terrain decoration only renders near camera — §10) |
| Vines / hanging | 1–2 | Meshy / Store | Drape on towers/trees for atmosphere |
| Rock (S/M/L) | 3 | Meshy / Store | Shoreline + jungle floor |
| Fallen log / roots | 2 | Meshy / Store | Environmental storytelling |

**Placement approach:** editor-placed. Once the tree/bush models exist, place by hand **and/or** a
one-time editor **scatter helper** (like the terrain-once script — allowed) that drops the models in
clusters. Not runtime.

**★ DENSE FOREST in the grass band (user requirement, 2026-07-20).** The whole **grass ring between
the sand clearing and the mountains** (the red-outlined zone in the user's screenshot) must read as
**dense jungle** — heavily packed palms/trees + small bushes/ferns, like `jungle_example.png` — NOT
sparse. Denser toward the mountain edge; the sand play-center stays open/readable. This is what frames
the lobby and hides the edges. Needs the tree/bush kit above first (assets job), then a dense scatter.

## 2. Landmark
| Object | Qty | Source | Notes |
|---|---|---|---|
| Cargo plane (1940s–70s, olive, big props) | 1 | Meshy | Parked/half-crashed; the "arrive by air" landmark (`Scenery.Plane`) |
| Pilot NPC | 1 | Meshy (roblox-chars) | Stands by the plane; talk-to-start flavor |

## 3. Station buildings / kiosks (interactive — keep names + `Station` attr + `Anchor`)
| Station | Object | Source | Notes |
|---|---|---|---|
| `SkillTrainer` | Wooden stall + counter + sign | Meshy/Build | Blue accent |
| `Bounties` | Board stand / stall | Meshy/Build | Gold accent |
| `RobuxShop` | Small kiosk | Meshy/Build | Green accent (prompt wired ✅) |
| `BoatUpgrades` | Mechanic rig/bench at the dock | Meshy/Build | Green; at the water |
| Sign boards (per station) | 4+ | Build + Flaticon | Wood/metal backing, thick border, icon + ALL-CAPS (styleguide §20) |

## 4. Party / launch pads (interactive)
| Object | Qty | Source | Notes |
|---|---|---|---|
| Party pad (wood+metal ring, colored glowing center, player-group icon) | 4 (Blue/Red/Green/Yellow) | Build + Flaticon | `PartyPad_*`; edge lights; never obscured |

## 5. Water / dock
| Object | Qty | Source | Notes |
|---|---|---|---|
| Dock / jetty (planks + posts) | 1 | Meshy/Build | East shore |
| Winch / mooring post | 1 | Meshy/Store | Rope tie point |
| Boat (moored display) | 1 | **cross-ref gameplay** | The real boat is BoatServer's (own job); lobby shows it moored — see `boat_ideas.png` (3 tiers) |

## 6. Structures / scenery
| Object | Qty/Variants | Source | Notes |
|---|---|---|---|
| Watchtower | 2 | Meshy/Build | Legs + platform + tarp roof |
| Welcome sign | 1 | Build | "WELCOME TO JUNGLE AIRFIELD", stencil font |
| Leaderboard board | 2 (Top Runs, Weekly) | Build + SurfaceGui | Wood/metal, gold/blue trim; live text via SurfaceGui |
| Tents / tarps | 3–4 | Meshy/Store | Canvas, olive |
| Cargo netting | 2 | Meshy/Store | Strung between posts |
| Windsock | 1 | Meshy/Store | Airfield flavor (also reads wind direction) |
| Path fences / rope barriers | few | Meshy/Store | Line the curved sand paths |
| Directional path markers / lanterns | few | Build/Store | Guide flow between zones (styleguide §24) |
| Sky / clouds | 1 | Store/Build | Warm `Sky` + `Clouds` to complement the Atmosphere |

## 7. Camp props (environmental storytelling — cluster meaningfully)
| Object | Variants | Source | Notes |
|---|---|---|---|
| Wooden crate | 3 | Meshy/Store | Stacks near shops/dock |
| Metal military crate | 2 | Meshy/Store | Olive, weathered |
| Oil barrel / fuel drum | 2 | Meshy/Store | Rust; fuel theme |
| Fuel can | 1 | Meshy/Store | Handheld |
| Sandbags (stack) | 1 | Meshy/Build | Defensive dressing |
| Campfire | 1 | Build + VFX | Fire/smoke particles + light |
| Lantern / hanging lamp | 2 | Meshy/Store | Warm light source (night) |
| Tiki torch (path-lining) | 1 | Meshy/Store | Warm light; lines paths |
| Toolbox / wrenches | 2 | Meshy/Store | At Boat Upgrades / mechanic |
| Spare tire | 1 | Meshy/Store | Clutter |
| Cargo pallet / supply box | 2 | Meshy/Store | Clutter |
| Rope coil / radio / small table | 3 | Meshy/Store | Fine detail (P3) |

## 8. Ground / decals
| Object | Qty | Source | Notes |
|---|---|---|---|
| Airfield star (spawn) | 1 | ChatGPT/Flaticon → decal | Painted military star |
| Runway "27" + stripes | 1 set | Build/decal | Cream markings |
| Path decals (sand/dirt/tire tracks) | 2–3 | ChatGPT → decal | Curved paths connecting zones (styleguide §24) |

## 9. Icons (UI, for signs + HUD) — Flaticon
Gear (engine) · Shield (hull) · Fuel pump (fuel) · Crate (storage) · Crossed tools (equipment) ·
Star (gold/major) · Wrench (utility) · Player-group (party). One consistent set → record IDs in
`STYLEGUIDE.md §7` + the asset registry.

## 10. VFX (particles / beams / lights)
| Effect | Where | Notes |
|---|---|---|
| Party-pad glow ring | each of 4 pads | Colored beam/particle ring; gentle pulse; brighter when occupied |
| Leader sparkle | leader on a pad | Small sparkle over the ★ leader |
| Launch effect | pad, countdown → teleport | Rising light column + dust burst / swirl on launch |
| Campfire | campfire prop | Fire + smoke + embers + warm PointLight |
| Torch / lantern flame | each torch/lantern | Small flame + warm PointLight (pools of light) |
| Fireflies / motes | jungle edge | Drifting glow particles (ambient life) |
| Sun-ray dust motes | open airfield | Fine floating dust catching the light |
| Water shimmer / ripples / foam | river + dock | Surface sparkle, gentle ripples, dock foam |
| Plane heat-haze / smoke puff | plane (optional) | Subtle idle flavor |
| Flag / tarp wind sway | flags, tents | Cloth movement |
| Purchase confirm burst | on buy | Gold/coin sparkle at the kiosk / HUD |
| Leaderboard #1 glow | Top Runs board | Subtle highlight on the top entry |

Mobile budget: pooled, capped, distance-LOD'd, off-screen-culled (STYLEGUIDE §8).

## 11. Audio — Ambient (looping beds, mostly spatial)
| Sound | Notes |
|---|---|
| Jungle day ambience | birds + insects bed (2D loop) |
| Wind / breeze | light layer over the ambience |
| Water lapping | positional at the dock/shore |
| Campfire crackle | positional at the campfire |
| Cicadas / distant wildlife calls | occasional layered one-shots |
| Flag / rope creak | subtle positional near towers & signs |

## 12. Audio — SFX (events / one-shots)
| Sound | Trigger |
|---|---|
| UI click / tap | any button |
| Panel open / close | shop / skills / bounties / robux |
| Purchase success | buy confirmed |
| Purchase fail / error | insufficient funds / cancel |
| Upgrade applied | boat/skill upgrade bought |
| Pad join (step-on) / leave | player steps on / off a party pad |
| Leader assigned | first player on an empty pad |
| Countdown tick | each second of the launch countdown |
| Launch / teleport whoosh | party launches |
| Prompt appear / hold-complete | ProximityPrompt shown / held |
| Footsteps — sand vs wood/dock | material-aware (optional; engine default ok) |
| Rank / reward stinger | leaderboard or rank change (if surfaced) |

## 13. Music
| Track | Notes |
|---|---|
| Lobby theme (loop) | adventurous but chill jungle-expedition; not tense; seamless loop |
| Countdown / launch layer (optional) | subtle intensity lift while a pad counts down |

## 14. Lighting (already applied — reference, not to re-source)
Warm-afternoon rig live (STYLEGUIDE §8 / `lobby/build/lobby_atmosphere.luau`): Atmosphere haze, warm
ColorCorrection, Bloom, SunRays, muted-teal water. Warm lantern/torch pools if a night lobby is ever
added. (Set `Lighting.Technology = Future` in Studio.)

---

### Open questions for the assets pass
- [ ] Meshy vs Creator Store per item (I'll draft Meshy prompts for the hero set: plane, palms, boat).
- [ ] How many palm/tree variants is "enough" for the density we want (start 4 palms + 3 trees + 3 bushes)?
- [ ] Editor hand-place vs one-time scatter helper for foliage?
- [ ] Boat model: handled here (lobby display) or fully in the boat/gameplay job?

## Sourcing tracker
Chosen assets as we go (Store = approved + scanned; ChatGPT/You = pending your upload/IDs).

| Asset | Source | Status | Asset ID / notes |
|---|---|---|---|
| Palm — Tall Straight | Store (Vupatu) | ✅ APPROVED + scanned (2026-07-20) | `5031791950` |
| Palm — Curved | Store (Vupatu) | ✅ APPROVED + scanned | `5031794668` — matched pair |
| Palm — Low-Poly | Store (LegendaryFrosts) | ✅ APPROVED + scanned | `1436325105` — darker variant |
| Coconut Palm | Store (Trexlty) | ✅ APPROVED + scanned | `CAND_PalmCoconut_Trexlty` — **ID pending (user to paste)** |
| Bush/fern/ground-cover pack | Store (DoctorFir) | ✅ APPROVED + scanned | `81654645105891` — Tropical Plant Pack (8 meshes) |
| Tall fern / large leaf | Store | ✅ APPROVED + scanned | `CAND_FernTall` — **ID pending (user to paste)** |
| Canopy trees pack | Store (PSY0PZ) | ✅ APPROVED + scanned | `CAND_TreesFoliagePack_PSY0PZ` — 102 meshes, rings clearing; **ID pending**. Dupe deleted. |
| Rocks / logs / vines | Store | ⏳ next search | — |
| Cargo plane | Store→Meshy | queued | — |
| Crates / barrels / props | Store | queued | — |
| Watchtower / tents | Store | queued | — |
| Airfield star / path decals | ChatGPT (you) | pending | — |
| UI icons ×8 | ChatGPT (you) | pending | — |
| Ambient / SFX / music | You (Pixabay) | pending | — |
| Party pads / leaderboards / VFX | Build | Claude builds | — |

> **REJECTED:** Jungle Trees Pack (ClawWOMinerm `119737242130790`) — hidden `Script` + 3,335 parts; deleted per scan rule.
