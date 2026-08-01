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
| Vines / hanging | — | — | <span style="color:#2e9c3f">✅ done (dropped)</span> | user decision 2026-07-20: skipped, not needed |
| Grass tuft / clump | 48 | Build | <span style="color:#2e9c3f">✅ built</span> | bladed tufts scattered on the grass ring (`Scenery.Details.GrassTufts`) |

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
| Party pad (launch platform) | 4 (Blue/Red/Green/Yellow) | Build | <span style="color:#2e9c3f">✅ built (v2)</span> | Redesigned from flat discs → raised diamond-plate platform + wood deck, glowing accent center-ring + dark metal `Center` (kept for LobbyServer detection), colored light-beam column, 8 edge lights, rising motes. Station/PadColor/Anchor kept. Group icon <span style="color:#2e9c3f">✅ done</span> — `party` badge added to each pad billboard in that pad's colour by `LobbySignage` (Job #065). |

## 1.5 Water / dock

| Object | Qty | Source | Status | Notes |
|---|---|---|---|---|
| Dock / jetty | 1 | Store (Sxphies `3023220773`) | <span style="color:#2e9c3f">✅ placed</span> | `AssetLibrary/Structures/Dock` at east water; `Pier` part kept for soundscape |
| Winch / mooring post | 1 | Build | <span style="color:#2e9c3f">✅ built</span> | wood post + metal cap + rope, at the dock end (`Scenery.Details.MooringPost`) |
| Boat (moored display) | 1 | cross-ref gameplay | ▫ queued | real boat is BoatServer's; lobby shows it moored (`boat_ideas.png`) |

## 1.6 Structures / scenery

| Object | Qty | Source | Status | Notes |
|---|---|---|---|---|
| Watchtower | 2 | Store (RangerTower `81318418778699`) | <span style="color:#2e9c3f">✅ placed</span> | `AssetLibrary/Structures/RangerTower` @0.7 → `Watchtower_NW/NE` |
| Welcome sign | 1 | Build | <span style="color:#2e9c3f">✅ built</span> | wood + gold trim; SurfaceGui "WELCOME TO JUNGLE AIRFIELD" (Special Elite, cream+stroke) on both faces |
| Leaderboard board | 2 (Top Runs, Weekly) | Build + SurfaceGui | <span style="color:#2e9c3f">✅ built</span> | wood + gold/blue trim; `RankServer` rewired to fill editor `Leaderboard_TopRuns` (find-by-name) with live Top-10; Weekly = "coming soon" placeholder (no weekly data yet) |
| Tents / tarps | 3–4 | Store | <span style="color:#2e9c3f">✅ (2 placed)</span> | olive canvas (see camp props); more optional |
| Cargo netting | 2 | Build | <span style="color:#2e9c3f">✅ built</span> | draped rope nets between posts (`Scenery.Details.CargoNet`) |
| Windsock | 1 | Build | <span style="color:#2e9c3f">✅ built</span> | pole + orange/white bands, by the runway (`Scenery.Details.Windsock`) |
| Path fences / rope barriers | few | Build | <span style="color:#2e9c3f">✅ built</span> | post+rope runs flanking the spawn approach (`Scenery.Details.RopeBarrier`) |
| Directional markers | 1 | Build | <span style="color:#2e9c3f">✅ built</span> | signpost near spawn (PLANE/DOCK/SHOPS arrows). Lanterns still ▫ (need props) |
| Sky / clouds | 1 | Build | <span style="color:#2e9c3f">✅ built</span> | volumetric `Clouds` (cover .58) + `Sky`, warm-tinted |

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
| Campfire | 2 | Build + VFX | <span style="color:#2e9c3f">✅ built</span> | rock pit raised onto sand + crossed logs; Fire/Smoke/embers/light (§1.10) |
| Lantern / tiki torch | 2+ | Store | ▫ queued | warm night light |
| Toolbox / spare tire / cargo pallet / rope / radio | few | Store | ▫ queued | fine detail (P3) |

## 1.8 Ground / decals

| Object | Source | Status | Notes |
|---|---|---|---|
| Airfield star (spawn) | ChatGPT/Flaticon → decal | <span style="color:#c9911d">⏸ pending</span> | painted military star |
| Runway "27" + stripes | user | <span style="color:#2e9c3f">✅ done (user)</span> | airfield/runway done by user |
| Path decals (sand/dirt/tire tracks) | ChatGPT → decal | <span style="color:#c9911d">⏸ pending</span> | curved paths connecting zones (styleguide §24) |

## 1.9 UI icons (signs + HUD) — sourcing list (LOBBY scope, drawn up 2026-07-30)

> **This is the shopping list that gates the lobby GUI job.** Derived from the actual lobby screens
> (`GoldHud`, `RobuxShop`, `SkillShop`, `ModulesShop`, `RetentionClient`) + station signs (§1.3) + party
> pads (§1.4), against STYLEGUIDE §6/§7. IDs go to registry `images.md` + STYLEGUIDE §7 when uploaded.

**Two distinct asset classes** (read `assets/Images/GUI_PATTERN.png` — the mockup makes this obvious):
**(a) mono UI glyphs** → Flaticon, tinted in code · **(b) rendered item art** → generated, palette baked in.
They are sourced differently and must not be confused. (b) is listed in §1.9b.

**Picking rules for the glyphs (matter more than the individual choices):**
- **Buy WHITE / MONO, never pre-colored.** In the mockup every glyph is a single-color silhouette — the
  star, gear, wrench, party-group, whole bottom bar. Color comes from **our palette via `ImageColor3`**,
  so a pre-colored icon is locked to someone else's palette and can't be re-tinted cleanly.
- **One pack, one author.** Pick a single Flaticon pack that has *most* of P1, then take every other icon
  from that same author — mixed packs are the #1 way an icon set looks amateur.
- Style per §7: **simple, bold, slightly 3D/embossed**, readable at **32 px** on a phone. Solid shapes,
  no thin outlines, no long shadows, no flat-minimal line art.
- **PNG 512×512, transparent.** Upload in Studio → Asset Manager → Images, then hand me the IDs.
- Flaticon free tier **requires attribution** — if we skip attribution we need the paid plan (GROUND-RULES §4).

**Tints (STYLEGUIDE §4) — one mono set covers the whole mockup:**

| Tint | Hex | Applied to |
|---|---|---|
| Gold | `#D69B22` | star · gold shop sign · gold coin · gold-tier anything |
| Cream | `#F3E6C2` | default glyph on dark panels — gear, wrench, bottom bar, X, hamburger |
| Green | `#4B7A2B` | primary / confirm / positive |
| Blue | `#356B9A` | utility / secondary / small skills |
| Red | `#A84B3C` | cancel / danger |
| Party ×4 | gold · green · blue · red | the four launch pads, one each |

> **Currency trap:** the mockup HUD shows 3 chips (gold coin / green cash / blue gem). Per STYLEGUIDE §6.3
> that illustrates **layout only** — the lobby has **Gold only**. Source **one** currency icon, not three.

### <span style="color:#2e9c3f">✅ ALL 23 SOURCED, UPLOADED & VERIFIED (user, 2026-07-30)</span>

Flaticon set, PNGs in `assets/Images/Icons/`. **IDs → registry
[`images.md`](../roblox.workspace/Assets/registry/images.md) → *Lobby UI icon set*.** All 23 verified in
Studio (`GetProductInfo` → name match, AssetTypeId 1). Nothing left to source for the lobby GUI.

| # | Icon | Uploaded as | Used by |
|---|---|---|---|
| 1 | Close **X** | `close` | every panel header (4 panels) |
| 2 | **Gold coin** | `coin` | `GoldHud` chip, every cost row |
| 3 | **Shop** | `shop` | `RobuxShop` open button, RobuxShop sign |
| 4 | **Star** | `star` | major/Gold skill, `SkillTrainer` sign |
| 5 | **Wrench** | `wrench` | utility skill, `BoatUpgrades` sign |
| 6 | **Player group** | `user_group` | party pads ×4, party UI |
| 7 | **Calendar** | `calendar` | `RetentionClient` WEEKLY |
| 8 | **Checkmark** | `check` | CLAIMED / OWNED / MAX states |
| 9 | **Target / bounty** | `target_bounty` | `Bounties` station sign |
| 10 | **Gear** = engine | `cogwheel_gear` | `motors`, `motor2` |
| 11 | **Shield** = hull | `shield` | `hull`, `hullkit` |
| 12 | **Fuel** | `fuel-station` | `diesel`, `fueltank`, `refuel` |
| 13 | **Crate** = storage | `box_Create` | `cargo`, `trailer` |
| 14 | **Crossed tools** | `tools` | `repair`, generic upgrade |
| 15 | **Boat** | `motorboat` | "Boat" skill group header |
| 16 | **Crew** | `navy_crew` | "Crew" skill group header |
| 17 | **Ship wheel** | `ship-wheel` | `rudder` (Rudder Tuning) |
| 18 | **Medkit** | `first-aid-kit` | `medic` (Combat Medic) |
| 19 | **Gun / turret** | `machine-gun` | `gun`, `gunupgrade` |
| 20 | **Spotlight** | `spotlight` | `searchlight` (Searchlight Rig) |
| 21 | **Money bag** | `money-bag` | `scavenge` (Scavenger's Instinct) |
| 22 | **Trophy** | `winner_trophy` | weekly-objective score reward |
| 23 | **Robux** | `roblox` | R$ price rows |

> **Colour note (changes §1.9's original plan):** the delivered set is **full-colour flat icons**, not the
> mono silhouettes the tint table below assumed. `ImageColor3` multiplies, so tinting these muddies them —
> **the tint table applies to panel/text/button colour, not to these icons.** They carry their own palette
> (bright red medkit/fuel, green check, blue shield) which sits brighter than STYLEGUIDE §4. Handle at
> restyle time: seat each icon on a dark panel chip so it reads as deliberate, or re-export desaturated if
> they fight the muted jungle ground. Decide by eye once the first panel is restyled.

**Already covered — do not re-source:** shop product/pass art (§5.1, 7 IDs live) · loading background (§5) ·
the `LastRiverLogo.png` used by `TeleportGui`.

## 1.9b Upgrade item art — rendered props, NOT flat icons (added 2026-07-30)

> `GUI_PATTERN.png` shows the UPGRADES row as **painted 3-D props**, reused in the shop panel, the
> buy/confirm popup and the "BOAT UPGRADED!" toast. **Flaticon cannot supply these** — they're
> ChatGPT/Meshy renders with the palette baked in.
>
> **Corrected 2026-07-30 against the actual data model** (an earlier draft of this section said 16 renders
> at 3 levels each — wrong on both counts):
> - **Modules are one-time Gold unlocks**, not leveled (`ModuleDefs`: buy once → OWNED). **One render each,
>   no tiers.**
> - **Skills go to level 10** (`SkillDefs.MAX_LEVEL = 10`), so per-level art is impossible. Skills reuse the
>   flat §1.9 icons + `Lv n / 10` + progress bar — which is what `SkillShop` already renders.
> - The mockup's `LEVEL 1 → 2 → 3` illustrates the *upgrade flow*, not a literal 3-tier art requirement.
>
> **Palette to bake in:** Primary Military Olive `#59613B` · Weathered Metal `#4E5246` · Dark Metal `#353A35`
> · brass/gold fittings `#D69B22`. Faded, never glossy (§4 Military/Metal). Transparent PNG, 512×512,
> consistent 3/4 view + light direction across all 7 so they line up in a row.

| Render | For | Status |
|---|---|---|
| Twin Motors Mount (engine) | `motor2` module | ▫ to generate |
| Reinforced Hull (plating) | `hullkit` module | ▫ to generate |
| Searchlight Rig | `searchlight` module | ▫ to generate |
| Extended Fuel Tank | `fueltank` module | ▫ to generate |
| Cargo capacity | `trailer` module | ▫ to generate — **crates/cargo ON the rear deck. NOT a towed barge** (see the note below) |
| Mounted Gun Upgrade (turret) | `gunupgrade` module | ▫ to generate |
| Gold chest | buy-popup art for the 4 gold packs | ▫ to generate |

**7 renders total.** Not blocking the restyle (panels/buttons/type/icons land first); blocks only the
Boat-Upgrades panel and buy popup looking like the mockup.

> ### ⛔ No trailer / towed barge — settled 2026-08-01
> The cargo module's shop art shows **crates and cargo on the boat's own rear `CargoDeck`**, which is
> where cargo actually lives (GAME.md → *Cargo — the rear cargo deck & on-boat stations*). There is no
> towed body: one was built and removed in Job #013 because a roped second assembly was jittery, and the
> decision was reconfirmed in Job #066.
>
> **No separate 3-D trailer/barge mesh is needed on the boat.** The rear deck already represents the
> capacity visually. `assets/Images/Boat/_unused/` holds the barge render that was generated before this
> was settled — do not wire it up.

**Alternative sources** if Flaticon picking drags: the **Creator Store** has free game-icon packs (I can
search + present candidates for approval via Studio MCP, per GROUND-RULES §4), and **ChatGPT** can render a
bespoke embossed set on the palette — the most on-style option, and the one that guarantees a single family.

## 1.10 VFX (particles / beams / lights) — build in Studio

> Mobile budget: pooled, capped, distance-LOD'd, off-screen-culled (STYLEGUIDE §8).

| Effect | Where | Source | Status |
|---|---|---|---|
| Party-pad glow ring / motes | each of 4 pads | Build | <span style="color:#2e9c3f">✅ built</span> | rising accent-tinted glow motes on each pad Center |
| Leader sparkle | leader on a pad | Build | <span style="color:#2e9c3f">✅ built</span> | gold sparkle over occupants[1]'s head, managed in `LobbyServer` |
| Launch effect (light column + dust burst) | pad → teleport | Build | <span style="color:#2e9c3f">✅ built</span> | rising light column + dust burst + flash, fired in `LobbyServer` launch() |
| Campfire (fire+smoke+embers+light) | FirePits | <span style="color:#2e9c3f">✅ built</span> | Fire + Smoke + ember ParticleEmitter + warm PointLight on both `FirePit`s |
| Torch / lantern flame | each torch/lantern | Build | ▫ queued | needs torch/lantern props first |
| Fireflies / motes | jungle edge | Build | <span style="color:#2e9c3f">✅ built</span> | 6 firefly clusters on the grass ring (`AmbientVFX`) |
| Sun-ray dust motes | open airfield | Build | <span style="color:#2e9c3f">✅ built</span> | fine drifting dust field over the clearing (`AmbientVFX`) |
| Water shimmer / ripples / foam | river + dock | Build | <span style="color:#2e9c3f">✅ built (dock foam)</span> | foam/shimmer emitter at the dock shore (`AmbientVFX.DockFoam`); river handled in game place |
| Plane heat-haze / smoke puff | plane | Build | <span style="color:#2e9c3f">✅ built</span> | subtle rising shimmer at both engines |
| Flag / tarp wind sway | flags, tents | Build | ▫ deferred | needs per-frame cloth anim; low value |
| Purchase-confirm burst | on buy / upgrade / claim | Build | <span style="color:#2e9c3f">✅ built</span> | `Components.burst` — colour wash + rising motes, fired on purchase, upgrade and bounty claim (Job #065) |
| Leaderboard #1 glow | Top Runs board | Build | <span style="color:#2e9c3f">✅ built</span> | #1 row = gold plate + glowing UIStroke (`RankServer`) |

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

> **Batch 2 uploaded 2026-07-20, <span style="color:#2e9c3f">ALL WIRED 2026-07-31</span> (Job #065).** IDs in
> registry [`audio.md`](../roblox.workspace/Assets/registry/audio.md) → *Lobby SFX batch 2*; source mp3s in
> `assets/Objects/Ambient/Sound_wave_2/`.
>
> **2D vs positional:** interface cues (panel open/close, purchase, fail, upgrade, claim, click) are 2D and
> play through `ReplicatedStorage.UI.UISound`. **World cues are positional on the object that made them** —
> pad join / leader / countdown / launch on the pad itself (`LobbyServer`), the prompt cue on the station
> (`LobbyStations`), footsteps on the character (`Footsteps.local.luau`) — so a party forming is audible
> across the airfield instead of only in one player's ears.
>
> **No asset id is written in a script.** Every one resolves through `Theme.sound`.

| Sound | Trigger | Status |
|---|---|---|
| UI click / tap (`ui_mouse_click`) | any button | <span style="color:#2e9c3f">✅ wired</span> — `UIClick.local.luau` |
| Panel open / close (`open_close`) | shop / skills / bounties / robux | <span style="color:#2e9c3f">✅ wired</span> |
| Purchase success (`purchase_success`) | buy confirmed | <span style="color:#2e9c3f">✅ wired</span> |
| Purchase fail / error (`failed_or_not_allowed`) | insufficient funds / cancel / not allowed | <span style="color:#2e9c3f">✅ wired</span> |
| Upgrade applied (`upgrade_applied`) | boat/skill upgrade bought | <span style="color:#2e9c3f">✅ wired</span> |
| Pad join / leave (`joined_pad`) | step on/off a party pad | <span style="color:#2e9c3f">✅ wired</span> |
| Leader assigned (`leader_assigned`) | first player on an empty pad | <span style="color:#2e9c3f">✅ wired</span> |
| Countdown tick (`timer_countdown`) | each second of launch countdown | <span style="color:#2e9c3f">✅ wired</span> — `LobbyServer` positional on pad |
| Launch / teleport whoosh (`teleport_woosh`) | party launches | <span style="color:#2e9c3f">✅ wired</span> |
| Prompt appear / hold-complete (`prompt`) | ProximityPrompt | <span style="color:#2e9c3f">✅ wired</span> |
| Footsteps — wood (`footsteps_wood`) | dock / stall decks (material-aware) | <span style="color:#2e9c3f">✅ wired</span> |
| Footsteps — sand (`running_on_sand`) | airfield clearing (material-aware) | <span style="color:#2e9c3f">✅ wired</span> |
| Rank / mission stinger (`rank_completed_or_mission_completed`) | rank-up / mission complete | <span style="color:#2e9c3f">✅ wired</span> |

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
| Loading background art (`LoadingBackground`) | jungle/river key art, `rbxassetid://73636751330777` | <span style="color:#2e9c3f">✅ wired</span> — fallback ID in `LobbyLoading.local.luau` + `GameLoading.local.luau`; overridable by a `ReplicatedFirst.LoadingBackground` ImageLabel |
| Teleport / intro sequence art | plane-crash cold-open visuals | ▫ stub |
| HUD icons / role-suitability icons | per `jungle-style` + STYLEGUIDE | ▫ stub |

## 5.1 Monetization art — product / pass icons (added 2026-07-20)

> Uploaded as **Creator Hub product & pass thumbnails** (create.roblox.com), which also mints a normal
> owned image asset — so each icon **is** usable in-game as `rbxassetid://<icon>` in the shop GUI.
> Source art: `assets/Images/Purchase/` (large source renders; Hub versions are 512×512).
> Product/pass IDs live in `ReplicatedStorage/Progression/MonetizationDefs.luau` (identical copy in both
> trees). Icon IDs verified 2026-07-30 — gold packs via Studio `GetProductInfo(...).IconImageAssetId`
> (all 4 match), passes via the Roblox game-pass product-info API.

**Two ids per product** — they are not interchangeable:
**Hub icon** = what the Roblox store listing shows · **In-game icon** = the transparent PNG the shop GUI
draws. Both verified in Studio (`GetProductInfo` → name + type match).

| File | Product / pass | Type | Product/Pass ID | Hub icon | **In-game (transparent)** | Status |
|---|---|---|---|---|---|---|
| `10.png` | 10 Gold (49 R$) | dev product | `3610663250` | `121862847548970` | **`72255341573939`** | <span style="color:#2e9c3f">✅ live + wired</span> |
| `25.png` | 25 Gold (99 R$) | dev product | `3610663288` | `95542160791148` | **`114957317211525`** | <span style="color:#2e9c3f">✅ live + wired</span> |
| `60.png` | 60 Gold (199 R$) | dev product | `3610663341` | `74400053482366` | **`100983946600429`** | <span style="color:#2e9c3f">✅ live + wired</span> |
| `150.png` | 150 Gold (449 R$) | dev product | `3610663385` | `80233861953394` | **`133943328068949`** | <span style="color:#2e9c3f">✅ live + wired</span> |
| `Boat.png` | Armored Boat (499 R$) | game pass | `1919001295` | `138728521842994` | **`130910653087108`** | <span style="color:#2e9c3f">✅ live + wired</span> |
| `Paint.png` | Boat Paint Pack (99 R$) | game pass | `1919355255` | `70530350071757` | **`82416796032835`** | <span style="color:#2e9c3f">✅ live + wired</span> |
| `Cosmetics.png` | Cosmetic Bundle (249 R$) | game pass | `1918077339` | `130780112255781` | **`95212286807985`** | <span style="color:#2e9c3f">✅ live + wired</span> |

> **Why two:** Creator Hub mattes its thumbnails onto an opaque square/disc, so those ids render as a
> white blob inside the round row badges. The transparent re-uploads (2026-07-31, `*_transparent`) fixed
> it and are what `Theme.productIcon` points at. **Never swap a Hub id into the GUI.**

<span style="color:#2e9c3f">✅ Wired 2026-07-31</span> — the lobby `RobuxShop` shows real store art per row
(Job #065 phase 2). The game-place copy is still text-only (out of scope).

# 6) GLOBAL AUDIO

| Area | Items | Status | Notes |
|---|---|---|---|
| Cross-place music / SFX | combat, per-zone ambience | ▫ stub | existing uploads in registry `audio.md` |
