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
- **Every id the LOBBY place actually uses** → **[LOBBY-ASSET-INVENTORY.md](LOBBY-ASSET-INVENTORY.md)**
  (Job #069). A reuse manifest for the GAME place: 188 live ids + 53 declared in scripts, grouped by
  audio / UI / boat / hero props / store components, with what transfers and what must be re-imported.

> ### ⚠️ This file describes INTENT. The place is the ground truth.
> The Job #068 audit reported **four gaps that did not exist**, every one of them by trusting a row
> here — or the absence of a script reference — instead of looking at the place. **The lobby is
> editor-placed** (memory: `lobby-editor-placed-not-scripted`), so:
> - *"No script references it"* does **not** mean *"it isn't there."* The Weekly board's placeholder
>   and all four station entry signs exist in the editor and are referenced by no script.
> - A row whose notes **omit** something is not evidence the thing is missing.
>
> **Before reporting anything here as missing, check the place.** And when you finish a piece of work,
> update the row — three of those false findings trace to rows that were simply never updated.
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
| `Bounties` | board stand / stall | Meshy (user) | <span style="color:#2e9c3f">✅ swapped</span> | user Meshy object; Station attr + Anchor/prompt transferred, grounded, **entry sign**, localized to `AssetLibrary/Structures/Bounties`. Mesh `119564283624615` — named `Boutnies` *(sic)* in the place |
| `RobuxShop` | small kiosk | Meshy (user) | <span style="color:#2e9c3f">✅ swapped</span> | user Meshy hut/kiosk; Station attr + Anchor/prompt transferred, grounded, entry sign, localized to `AssetLibrary/Structures/RobuxShop` |
| `BoatUpgrades` | mechanic rig/bench at the dock | Meshy (user) | <span style="color:#2e9c3f">✅ swapped</span> | user Meshy object; Station attr + Anchor/prompt transferred, grounded, **entry sign**, localized to `AssetLibrary/Structures/BoatUpgrades`. Mesh `118860073556013` |
| Sign boards (per station) | 4 | Build | <span style="color:#2e9c3f">✅ built (all 4)</span> | Verified in the place by the Job #068 sweep: every station has an `EntrySign` — a `Board` (8×3×0.4, WoodPlanks) on two `Post`s — reading SKILL TRAINER / BOUNTIES / ROBUX SHOP / BOAT UPGRADES |

> **Why the four rows above now all say "entry sign".** Until 2026-08-02 only two of them mentioned it,
> and the Job #068 audit read that asymmetry as a build gap and reported a false finding. All four
> stations had signs the whole time. **A note that omits something is not evidence the thing is
> missing** — keep these rows symmetric.

## 1.4 Party / launch pads (interactive)

| Object | Qty | Source | Status | Notes |
|---|---|---|---|---|
| Party pad (launch platform) | 4 (Blue/Red/Green/Yellow) | Build | <span style="color:#2e9c3f">✅ built (v2)</span> | Redesigned from flat discs → raised diamond-plate platform + wood deck, glowing accent center-ring + dark metal `Center` (kept for LobbyServer detection), colored light-beam column, 8 edge lights, rising motes. Station/PadColor/Anchor kept. Group icon <span style="color:#2e9c3f">✅ done</span> — `party` badge added to each pad billboard in that pad's colour by `LobbySignage` (Job #065). |

## 1.5 Water / dock

| Object | Qty | Source | Status | Notes |
|---|---|---|---|---|
| Dock / jetty | 1 | Store (Sxphies `3023220773`) | <span style="color:#2e9c3f">✅ placed</span> | `AssetLibrary/Structures/Dock` at east water; `Pier` part kept for soundscape |
| Winch / mooring post | 1 | Build | <span style="color:#2e9c3f">✅ built</span> | wood post + metal cap + rope, at the dock end (`Scenery.Details.MooringPost`) |
| Boat (moored display) | 1 per player | Build + Meshy | <span style="color:#2e9c3f">✅ done (Job #066)</span> | `LobbyBoat.server.luau` spawns a STATIC boat per joining player in probed harbour water, showing that player's owned modules — a showroom for the Boat Upgrades shop. Full art (§2). |

## 1.6 Structures / scenery

| Object | Qty | Source | Status | Notes |
|---|---|---|---|---|
| Watchtower | **4** | Store (RangerTower `81318418778699`) | <span style="color:#2e9c3f">✅ placed</span> | `AssetLibrary/Structures/RangerTower` @0.7. **Four towers, all intended** (user, 2026-08-02): NE `(96,−115)`, NW `(−88,−110)`, plus two flanking the southern approach `(34,151)` and `(−63,153)`. ⚠️ **Three of them are named `Watchtower_NW`** — deliberate, left as-is; `LobbySoundscape` finds towers by the `^Watchtower` name **prefix** (Job #069), so duplicate names are harmless. Do not write a find-by-exact-name against these |
| Welcome sign | 1 | Build | <span style="color:#2e9c3f">✅ built</span> | wood + gold trim; SurfaceGui "WELCOME TO JUNGLE AIRFIELD" (Special Elite, cream+stroke) on both faces |
| Leaderboard board | 2 (Top Runs, Weekly) | Build + SurfaceGui | <span style="color:#2e9c3f">✅ built</span> | wood + gold/blue trim; `RankServer` rewired to fill editor `Leaderboard_TopRuns` (find-by-name) with live Top-10. **Weekly = "coming soon" placeholder** — verified present 2026-08-02 (`BoardGui` → "WEEKLY TOP RUNS" + "coming soon"). ⚠️ It is **editor-placed, not scripted**, so grepping the source for `Leaderboard_Weekly` finds only the line that creates the geometry — that is what made the Job #068 audit wrongly report the board as empty. A real weekly board still needs a weekly `OrderedDataStore` + rollover |
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
| Fuel can | 1 | — | <span style="color:#2e9c3f">✅ declined (#069)</span> | P3 tail dropped — the lobby has enough dressing (25 props, 3,810 BaseParts) |
| Campfire | 2 | Build + VFX | <span style="color:#2e9c3f">✅ built</span> | rock pit raised onto sand + crossed logs; Fire/Smoke/embers/light (§1.10) |
| Lantern / tiki torch | 2+ | — | <span style="color:#2e9c3f">✅ declined (#069)</span> | **Deferred to the GAME place.** Their stated purpose is *warm night light*, but the lobby is a **static warm afternoon** (`ClockTime 16.1`, no day/night cycle) — nothing for them to light. The night payoff belongs where the day/night cycle is |
| Toolbox / spare tire / cargo pallet / rope / radio | few | — | <span style="color:#2e9c3f">✅ declined (#069)</span> | P3 fine detail, dropped — pure set dressing on a place already signed off |

## 1.8 Ground / decals

| Object | Source | Status | Notes |
|---|---|---|---|
| Airfield star (spawn) | — | <span style="color:#2e9c3f">✅ done (by design)</span> | **No decal needed.** User ruled 2026-08-02 that the existing cream disc IS the intended spawn marker — the painted military star was dropped. ⚠️ `Spawn.Star` + `Spawn.Pad` still match the `greybox_placement.luau` signature exactly, so a greybox sweep will re-flag them: they are on the **confirmed-intentional list** in `Jobs/068/intake.md` Part E |
| Runway "27" + stripes | user | <span style="color:#2e9c3f">✅ done (user)</span> | airfield/runway done by user — 6 `RunWay` tiles, mesh `114620021340964`, spanning z −154 → −485. The greybox `Scenery.RunwayMarkings` (9 `Dash` + 4 `Threshold`) sits over them and is **kept deliberately** (user, 2026-08-02); it is on the confirmed-intentional list in `Jobs/068/intake.md` Part E, so a greybox sweep will re-flag it |
| Path decals (sand/dirt/tire tracks) | — | <span style="color:#2e9c3f">✅ declined (#069)</span> | Not needed: the terrain already separates the zones (sand clearing, worn track, grass ring, material transitions) and the built directional signpost (§1.6) covers wayfinding. Sat pending 2026-07-20 → 08-02 unmissed. **If new players ever do get lost, the no-art fix is a terrain material change, not a decal** |

## 1.9 UI icons (signs + HUD) — sourcing list (LOBBY scope, drawn up 2026-07-30)

> **This is the shopping list that gates the lobby GUI job.** Derived from the actual lobby screens
> + station signs (§1.3) + party pads (§1.4), against STYLEGUIDE §6/§7. IDs go to registry `images.md`
> + STYLEGUIDE §7 when uploaded.
>
> **Current lobby screens (corrected 2026-08-02).** The original list read
> *`GoldHud`, `RobuxShop`, `SkillShop`, `ModulesShop`, `RetentionClient`* and is now out of date:
> **`GoldHud` was REPLACED by `TopBar`** in Job #065, and four screens were missing. The real set is
> **`TopBar` · `EntryBar` · `RobuxShop` · `SkillShop` · `ModulesShop` · `PaintShop` · `RetentionClient`
> · `AdminClient`** (+ `TeleportGui`, `LobbyLoading`, `UIClick`). All consume `Theme.icon`.

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
| Twin Motors Mount (engine) | `motor2` module | <span style="color:#2e9c3f">✅ `BoatParts.Motor`</span> |
| Reinforced Hull (plating) | `hullkit` module | <span style="color:#2e9c3f">✅ `BoatParts.HullPlate`</span> |
| Searchlight Rig | `searchlight` module | <span style="color:#2e9c3f">✅ `BoatParts.SearchlightMast` + `SearchLightHead`</span> |
| Extended Fuel Tank | `fueltank` module | <span style="color:#2e9c3f">✅ `BoatParts.FuelTank`</span> |
| Cargo capacity | `trailer` module | <span style="color:#2e9c3f">✅ `BoatParts.CargoRacks`</span> — crates ON the rear deck, as specified |
| Mounted Gun Upgrade (turret) | `gunupgrade` module | <span style="color:#2e9c3f">✅ `BoatParts.GunBarrelHeavy`</span> |
| Gold chest | buy-popup art for the 4 gold packs | ▫ to generate — **the only boat/shop art still missing** |

**7 renders total.** Not blocking the restyle (panels/buttons/type/icons land first); blocks only the
Boat-Upgrades panel and buy popup looking like the mockup.

> ### ✅ DECLINED FOR NOW (Job #069, 2026-08-02) — the flat §1.9 glyphs stay
> The shop keeps `Theme.moduleIcon`. Nothing is broken: the glyphs are on-palette and legible at 32 px.
>
> **`rbxthumb://` was tested as a free alternative and rejected on evidence.**
> `rbxthumb://type=Asset&id=<meshId>` *does* work on our uploaded boat meshes — all 7 resolved, and a
> screenshot confirmed real, recognisable geometry (motor, hull plate, cargo racks, ramp). Two things
> ruled it out:
> 1. **Roblox renders the raw mesh UNTEXTURED** — grey/white, no `SurfaceAppearance` — so none of the
>    olive / weathered-metal / brass palette this section wants *baked in* survives.
> 2. **2 of the 7 rendered black/blank.** A mixed set (5 grey renders + 2 coloured glyphs) would also
>    breach §1.9's own *"one pack, one author"* rule.
>
> Partly covered from another angle: **Job #069 added module nameplates to the showroom boat**, so a
> player can walk up and read the real part they own (`TWIN MOTORS MOUNT` on the actual second engine).
>
> To revisit: generate the 7 as specified above, **or** first work out why two mesh thumbnails render
> black — if all 7 rendered cleanly, the free option gets much stronger.

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
| Torch / lantern flame | — | — | <span style="color:#2e9c3f">✅ declined (#069)</span> | Moot — the lantern/torch props it needed were declined for the lobby (§1.7) and deferred to the GAME place |
| Fireflies / motes | jungle edge | Build | <span style="color:#2e9c3f">✅ built</span> | 6 firefly clusters on the grass ring (`AmbientVFX`) |
| Sun-ray dust motes | open airfield | Build | <span style="color:#2e9c3f">✅ built</span> | fine drifting dust field over the clearing (`AmbientVFX`) |
| Water shimmer / ripples / foam | river + dock | Build | <span style="color:#2e9c3f">✅ built (dock foam)</span> | foam/shimmer emitter at the dock shore (`AmbientVFX.DockFoam`); river handled in game place |
| Plane heat-haze / smoke puff | plane | Build | <span style="color:#2e9c3f">✅ built</span> | subtle rising shimmer at both engines |
| Flag / tarp wind sway | flags, tents | — | <span style="color:#2e9c3f">✅ declined (#069)</span> | Deferral confirmed, not forgotten. A per-frame cloth loop over several decorative parts is the continuous cost the mobile budget exists to avoid, for a detail few players consciously notice. **11 of 13 §1.10 VFX are built; these two are the deliberate exceptions** |
| Purchase-confirm burst | on buy / upgrade / claim | Build | <span style="color:#2e9c3f">✅ built</span> | `Components.burst` — colour wash + rising motes, fired on purchase, upgrade and bounty claim (Job #065) |
| Leaderboard #1 glow | Top Runs board | Build | <span style="color:#2e9c3f">✅ built</span> | #1 row = gold plate + glowing UIStroke (`RankServer`) |

## 1.11 Audio — Ambient (looping beds, mostly spatial)

> IDs → registry [`audio.md`](../roblox.workspace/Assets/registry/audio.md). Wired by
> `lobby/sync/ServerScriptService/LobbySoundscape.server.luau` (needs Rojo sync + Play to hear).

| Sound | Where | Status | Notes |
|---|---|---|---|
| Jungle day ambience **1** | 2D bed | <span style="color:#2e9c3f">✅ wired</span> | birds + insects loop (`116462724806689`) |
| Jungle day ambience **2** | 2D bed | <span style="color:#2e9c3f">✅ wired (#069)</span> | `120011248667884`, **layered under bed 1** at vol 0.14 vs 0.22 — deliberately lopsided so it thickens the bed instead of doubling the birdsong. Loop lengths 154.2 s vs 70.2 s are not simple multiples, so the two drift and the bed never audibly repeats. **Volume is the knob: if it ever sounds busy, drop bed 2 first.** Was uploaded-but-unused for months while this row claimed it was wired |
| Wind / breeze | 2D bed | <span style="color:#2e9c3f">✅ wired</span> | light layer |
| Water lapping (`water-splashes`) | @ `Dock.Dock.Pier` | <span style="color:#2e9c3f">✅ wired (fixed #069)</span> | positional. ⚠️ **It never actually played until Job #069** — the lookup was a non-recursive `Dock:FindFirstChild("Pier")`, but the Store dock nests a level deeper, so it returned nil and no sound was ever created while this row read "✅ wired". Now a recursive find; verified in Play as `water×1` |
| Campfire crackle (`crackle-campfire`) | @ both `FirePit`s | <span style="color:#2e9c3f">✅ wired</span> | positional |
| Cicadas / wildlife | 2D one-shots | <span style="color:#f0a020">⚠️ wired, but STACKING</span> | fired as a one-shot every ~18–44 s — but the clip is **71.4 s long** (measured live, Job #073), so each copy is still playing when the next starts and the lobby runs ~2 overlapping cicada loops at all times. Not audibly broken, which is why it went unnoticed, but it is not what the code intends. The GAME place hit the same trap harder and fixed it by making cicadas a **crossfading bed** (§6.1) — the lobby should follow |
| Rope creak (`rope_creak`) | @ **all 4** watchtowers | <span style="color:#2e9c3f">✅ wired (fixed #069)</span> | positional loop in `LobbySoundscape`. ⚠️ **Reached only 2 of the 4 towers until Job #069** — a hardcoded `{ "Watchtower_NW", "Watchtower_NE" }` + `FindFirstChild` returns the FIRST match per name, and three towers share the name. Now scans by `^Watchtower` prefix, so a newly placed tower creaks with no script edit; verified in Play as `rope×4` |

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
| Countdown / launch layer | — | <span style="color:#2e9c3f">✅ declined (#069)</span> | **Not wanted.** The countdown is **3 seconds** (`LobbyConfig.COUNTDOWN`) — a rising layer can't establish itself before the teleport cuts it, so it would only work if the countdown were lengthened, which is a gameplay cost for an audio flourish. The moment is already scored: per-second positional `timer_countdown` + `teleport_woosh`. Cheap revisit needing no new asset: duck the lobby music during the countdown |

## 1.14 Lighting

| Rig | Status | Notes |
|---|---|---|
| Warm-afternoon jungle rig | <span style="color:#2e9c3f">✅ applied</span> | Atmosphere haze (Density 0.40/Haze 2.7), warm `JungleCC`, **two blooms** (`JungleBloom` soft + `JungleBloomHighlight` punch), `JungleSunRays`, muted-teal water. `lobby/build/lobby_atmosphere.luau` / STYLEGUIDE §8. **Save the place or it resets.** |
| ~~Set `Lighting.Technology = Future`~~ | <span style="color:#2e9c3f">✅ n/a (obsolete)</span> | **Corrected 2026-08-02.** Studio no longer exposes a `Technology` dropdown — it is gone from the Lighting panel and unreadable from a script context. The modern controls are `LightingStyle` (**Realistic**), `ShadowSoftness` (**0.2**) and `PrioritizeLightingQuality` (**true**) — verified in the place; that *is* the Future path. **Nothing to set by hand.** |
| Post-effect budget | <span style="color:#2e9c3f">✅ 4 active passes</span> | Job #069 deleted a stray `SunRays` (Intensity **0.01** — invisible, but still a full-screen pass) and adopted the working stray `Bloom` into the rig as `JungleBloomHighlight`. **Every enabled `PostEffect` is a full-screen pass**; `lobby_atmosphere.luau` now warns on any unauthored one, because the two strays went unnoticed for several jobs |

### Open questions (lobby)

| # | Question |
|---|---|
| 1 | Enough palm/tree variety for the density? (current: 4 palms + trees pack + bush pack + fern) |
| 2 | Editor hand-place vs one-time scatter helper for future foliage? |
| 3 | Boat model — lobby display here, or fully in the boat/gameplay job? |

---

# 2) BOAT

**Art done (Job #066, 2026-08-01).** 15 meshes, ChatGPT concept renders → Meshy image-to-3D. Source images
in `assets/Images/Boat/`, GLBs in `assets/Images/Boat/Objects/`, mesh + texture ids in registry
[`meshes.md`](../roblox.workspace/Assets/registry/meshes.md).

**How the art attaches — read before touching boat visuals.** Meshes are **skins over greybox hosts**, not
replacements. `Hull` stays a plain box: it is the `PrimaryPart`, carries the tuned density that makes the
boat float, and hosts the `Root` attachment every thrust/turn force uses. Each mesh is welded on as a
`CanCollide = false`, `Massless = true` child, so **art can never retune physics**. The mapping lives in
`ReplicatedStorage.Boat.BoatParts` (byte-identical in both trees) — changing a model is one id in one file.

| Part | Mesh | Status | Notes |
|---|---|---|---|
| `Hull` | `Hull` | <span style="color:#2e9c3f">✅ wired</span> | 32 × 14 — the mesh's exact natural ratio, so zero stretch |
| `CargoDeck` | `CargoDeck` | <span style="color:#2e9c3f">✅ wired</span> | rear deck; **this is the cargo area — there is no trailer** |
| `DriverSeat` | `DriverSeat` | <span style="color:#2e9c3f">✅ wired</span> | seat + console + wheel; stays a `VehicleSeat` |
| `Motor` · `Motor2` | `Motor` | <span style="color:#2e9c3f">✅ wired</span> | base engine (new in #066); `motor2` reuses the same mesh, mounted to port. ⚠️ **Job #067 fix:** `motor2`'s def was `library = nil`, so the 150-Gold Twin Motors module rendered as a raw dark greybox slab beside a fully modelled engine |
| `GunBase` · `GunBarrel` · `GunSeat` | 3 meshes | <span style="color:#2e9c3f">✅ wired</span> | barrel rides **on** the mount; seat 5 studs aft |
| `BowLightHead` | `BowLight` | <span style="color:#2e9c3f">✅ wired</span> | on the centreline — off-centre it hangs past the bow taper |
| Crew seats ×4 | reuses `GunSeat` | <span style="color:#2e9c3f">✅ wired</span> | real `Seat`s in game so passengers aren't thrown off |
| `HullPlate` | `HullPlate` | <span style="color:#2e9c3f">✅ wired</span> | **tiled ×4 per flank** — a full-length strip smears and overhangs the taper. **Job #074: the Armored Boat PASS now uses this mesh too** (it was the last bare-Part slab on the boat — see the note below the table) |
| `FuelTankModule` · `SearchlightHead` | 2 meshes | <span style="color:#2e9c3f">✅ wired</span> | appear only when their module is owned |
| `GunBarrelHeavy` | `GunBarrelHeavy` | <span style="color:#2e9c3f">✅ wired</span> | **swaps** the base barrel (never two barrels) |
| Fuel · Repair · Medic stations | 3 meshes | <span style="color:#2e9c3f">✅ wired</span> | medic is game-place only |
| Searchlight **mast** | `SearchlightMast` | <span style="color:#2e9c3f">✅ wired</span> | **Job #067.** Now a chunky riveted **pedestal** (1.7 x 4.53) — a 0.8-stud pole reconstructs badly in Meshy, which is why it was a plain box before. Also **moved to PORT beside the helm**: on the centreline it stood *inside* the gun barrel |
| Cargo Racks (`trailer`) | `CargoRacks` | <span style="color:#2e9c3f">✅ wired</span> | **Job #067.** 7.5 x 2.80 x 4.92 on the **aft half** of the rear deck; the three role stations moved forward to `backZ - 2.5` to make room. `cargoRackPieces` is the greybox fallback if the mesh is ever missing |
| `RampBow` | `RampBow` | <span style="color:#2e9c3f">✅ wired</span> | **Job #067** `ramps` module. ⚠️ Imported with a **square footprint** (4.21 x 1.20 x 4.21), so at 6 wide it is also 6 deep — it rides LOW on the foredeck (y 1.74…3.45) and passes **under** the gun base (y 3.8…5.8) rather than in front of it. Paintable |
| Cargo trailer / barge | — | <span style="color:#c93c3c">❌ not needed</span> | no towed body; cargo is the rear deck (GAME.md) |
| Boat SFX — **engine** | `boat_engine_starts` `105048345579705` + `speed_boat_loop` `74719520771875` | <span style="color:#2e9c3f">✅ uploaded + wired (#073)</span> | **The LIVE engine.** One-shot when a player takes the helm, then a loop whose `Volume` **and** `PlaybackSpeed` track the boat's real work. Positional on the stern `Motor` part, so the crew hears it from the right place. Wired **client-side** (`StarterPlayerScripts/Boat/BoatEngineSound.local.luau`) because the note changes every frame and driving that from the server would replicate 2 property writes/frame to every client for nothing. Drive value = `max(speed/30, throttle × 0.55)` — the key gives instant response, real hull speed takes over as it gets going. Falls quiet after 1.2 s stopped with no throttle, and resumes **without** re-cranking the starter |
| Boat SFX — rest | on-fire, destroyed, metal hit | <span style="color:#c93c3c">❌ not uploaded</span> | local mp3s only, in `assets/Objects/Boat/Sounds/` |

> ⚠️ **Imported into the LOBBY place only.** `ServerStorage` is place content and Rojo doesn't sync meshes,
> so the GAME place needs the same GLBs imported under the same names before its boat shows any art.

> **Job #074 — the Armored Boat pass finally uses `HullPlate` (todo 0045).** The pass had kept its Job
> #027 geometry through every art job: one bare `0.8 × 2.4 × 22` Part per side at hull-local x ±7.4,
> **Y 0.3**, `DiamondPlate`, **no skin**. That was the "dark slab sticking out under the hull". Three
> faults at once, and the third is the instructive one:
>
> 1. x ±7.4 against a 14-wide (half-width 7) *modelled, curved* hull left 0.4 studs — it poked through.
> 2. Y 0.3 is box-centre, near the waterline. The hull BOX is 3 tall but the mesh rises to ~4.5 with its
>    keel on the box bottom — the exact mistake Job #066 fixed for the hullkit by lifting it to Y 2.2.
> 3. **No `skinId` → no `Skin_hullPlate` child → `BoatPaint` could not see it.** Paint matches on skin
>    NAME, so an unskinned part is *structurally* unpaintable. It was guaranteed to stay greybox grey
>    next to a navy hull, not unlucky.
>
> Both plate sets now go through one `plateBelt()` helper. The pass reads as the heavier of the two by
> **wrapping further** — the same 4-segment flank run plus two bow shoulders yawed 25° inboard to follow
> the taper — never by being taller or thicker, which would stretch the mesh and reintroduce the smeared
> detail the tiling exists to prevent. **`ArmoredProw` is gone**: the hull grew 22 → 32 long in #066, so
> its z −11 was nowhere near the bow, and it fought the 8 × 8 `RampBow` for the space.
>
> **Owning the hullkit AND the pass builds ONE set of plates** (the pass's). Two sets at the same x/Y
> would z-fight. Stats are unaffected — hullkit's `MaxHP 150` and the pass's ×1.2 both still apply.
> Verified in Play with both owned: 10 plates, 0 `HullPlate*`, `paint: navy (12 parts)`, and every
> plate's skin colour equal to `Skin_hull`'s.

### Hull liveries (Boat Paint Pack) — **needs no new textures**

Job #067. Six liveries (olive free + 5 with the pass) recolour the **hull and its armour plates only** —
never the deck, engines, seats or stations.

**They are not new art, and must not be commissioned as such.** A livery reuses the existing PBR maps:

- Every boat mesh imported with a full `SurfaceAppearance` (ColorMap + Normal + Roughness + Metalness).
  An **opaque ColorMap completely overrides `BasePart.Color`**, so a naive tint is invisible.
- **`SurfaceAppearance.ColorMap` cannot be written by a game script** — *"lacking capability Plugin"*, the
  same gate as `MeshId` and `CollisionFidelity`. It *does* work from the Studio command bar, so testing it
  there proves nothing.
- So each paintable library mesh carries a **second, authoring-time appearance** named `PaintablePBR`:
  identical but with an empty ColorMap. At runtime a livery just destroys the one it doesn't want.
  Normal/Roughness/Metalness survive, so the repainted hull keeps every rivet, dent and wear patch.

> 🔧 **After importing the boat meshes into a place** (including the GAME place), run once in Studio and
> **save**: `local BP = require(game.ReplicatedStorage.Boat.BoatParts) print(BP.preparePaintLibrary())`
> Skipping it doesn't break anything — liveries just render flat, and the server warns once.

# 3) RIVER / WORLD

| Area | Items | Status |
|---|---|---|
| **River foliage — 3 bands** | reuse the §1.1 set, banded by distance from the water | **planned — Job #076** · see §3.4 |
| Obstacles | rocks, logs, sandbars, wreck debris | **Job #076** — `RockA/B/C` + `LogMossy` replace the greybox boxes. **Job #079** adds a 4th type, `LogJam` (Meshy) — a floating debris tangle, slow 0.72 / dmg 16, between `Log` and `Rock` |
| **Dock camps / trading villages** | tents, crates, sandbags, stilt huts, campfire | **planned — Job #077** · see §3.5 |
| Set-pieces | waterfalls, ramps, dam blockages | ▫ stub — **`LogJam` (#079) covers "dam blockages"** as a river obstacle; waterfalls and ramps remain open, and neither is Meshy work (terrain + VFX / a design decision) |
| Camp night practicals | lantern fixtures on the perimeter | <span style="color:#2e9c3f">✅ done (#079)</span> — `Lantern` (Meshy) on the sandbag line; see §3.6 |
| Docks / piers (river) | reuse `AssetLibrary/Structures/Dock` | **Job #077** — replaces `DockServer`'s plank Deck |
| Zone dressing / day-night set-pieces | per-zone props + lighting | ▫ stub |
| **GAME-place ambient rig** | lighting + water + soundscape | <span style="color:#2e9c3f">✅ done (#073)</span> — see §3.1 |
| **GAME-place Robux kiosk** | the crash-site shop hut | <span style="color:#2e9c3f">✅ done (#074)</span> — see §3.3 |

## 3.1 GAME place ambient — lighting, water, soundscape (Job #073)

Before #073 the GAME place ran **stock Roblox lighting** (`Ambient`/`OutdoorAmbient` both grey
`(70,70,70)`, no `ColorCorrection` at all, `GeographicLatitude 0`, grey Atmosphere with `Glare 0/Haze 0`,
`Terrain.WaterReflectance` **1** — a mirror river) and had **no ambient audio whatsoever**
(`SoundService` with zero children).

The lobby's look was ported over, but **day/night-aware** rather than baked, because the game runs a real
clock and the lobby is frozen at 16:10.

| Piece | Where | Status | Notes |
|---|---|---|---|
| Lighting / atmosphere / water rig | `sync/ReplicatedStorage/World/AtmosphereRig.luau` | <span style="color:#2e9c3f">✅ done</span> | **The values live here, in ONE module**, not baked into the place — so no "save the place or it resets" debt. Day palette is the lobby's accepted values verbatim; dawn / morning / dusk / night are keyframes lerped off `ClockTime`. Driven by `sync/ServerScriptService/World/AtmosphereServer.server.luau` |
| Edit-time bake | same module | <span style="color:#2e9c3f">✅ done</span> | So the editor isn't grey while building: `print(require(game.ReplicatedStorage.World.AtmosphereRig).apply(16.1))` in the command bar, then set `ClockTime` by hand (the module never writes it — `DayNightServer` owns it) |
| `Lighting.LightingStyle = Realistic` | **set BY HAND in Studio** | <span style="color:#2e9c3f">✅ done 2026-08-02</span> | **The one value a script cannot deliver** — refused even from the privileged command bar, same capability gate as the old `Technology`. Set by hand and the place saved; verified live (`Enum.LightingStyle.Realistic`, `ShadowSoftness 0.2`, `PrioritizeLightingQuality true`). `apply()` still reports it in a `REFUSED:` list every run, so **if the place is ever reset or re-created, this must be set by hand again** |
| Post-effect budget | `Lighting` | <span style="color:#2e9c3f">✅ 4 active passes</span> | Same budget as the lobby. The game place shipped with **the same two strays Job #069 removed from the lobby** — a `Bloom` byte-identical to `JungleBloomHighlight`, and a `SunRays` at Intensity **0.01**. The rig **adopts and renames** them rather than adding alongside, which would have left 6 passes with 2 doing nothing. Drift check ported too |
| Water | `Terrain` | <span style="color:#2e9c3f">✅ done</span> | `WaterColor (24,78,86)`, `Transparency 0.30`, **`Reflectance 0.03`** (was `1`), `WaveSize 0.15`, `WaveSpeed 10` |
| Ambient soundscape | `sync/ServerScriptService/World/GameSoundscape.server.luau` | <span style="color:#2e9c3f">✅ done</span> | 4 crossfading 2D beds + positional dock water + the two phase stingers. See §6 |
| Day/night clock re-pace | `sync/ServerScriptService/World/DayNightServer.server.luau` | <span style="color:#2e9c3f">✅ done</span> | Was a uniform 24 h per 4 real minutes from 08:00 → night fell **1 min 50 s** into a ~12 min run, three cycles per run. Now starts **06:30** with a **non-linear** clock: 13 daylight hours over 480 s, 11 night hours over 180 s → night falls **462 s** in. ⚠️ `EnemyServer` scales spawn rate + bite damage off `Phase`, so these two constants are a **balance** lever |
| Night practicals (fire pit, lanterns) | — | <span style="color:#c93c3c">❌ not built</span> | **0 `Light` objects exist in the whole game Workspace.** So the night palette is deliberately lifted higher than it should be, just to keep the camp navigable — global ambient doing a job that belongs to practicals. → `Planned/camp-night-practicals.md`, which must also bring the palette back down |

## 3.2 Weapon audio — <span style="color:#2e9c3f">✅ ALL WIRED (Job #079)</span>

| Sound | rbxassetid | Status | Notes |
|---|---|---|---|
| `gun_shot` | `138178318678571` | <span style="color:#2e9c3f">✅ **wired** (Job #079)</span> | **Deliberately deferred.** Uploaded while Job #073 (ambient) was open; the user's call was *"Do not add sound yet, because this will be seperate task, just list it in file."* It belongs with the weapon/turret work — `sync/ServerScriptService/Combat/GunServer.server.luau` and `WeaponServer` — not with an ambient job. Wants to be **positional on the barrel**, with a fire-rate-aware cooldown so sustained fire doesn't stack one `Sound` per bullet |

**Wired by Job #117:** `rifle_shoot` **`138005496001979`** — the M16. ⚠️ **3.888 s of SUSTAINED
AUTO-FIRE**, not a single shot (measured live via `Sound.TimeLength`, Studio 2026-08-25 — *not* inferred
from the file name). It is therefore played **once per burst and `:Stop()`ed at burst end**, never
restarted per bullet: at `burstInterval` 0.10 s that would relaunch a 3.9 s clip 20 times inside 2 s,
which is the cicada-stacking mistake below. The M16 reuses the shared `empty_gun` dry-fire click.

**Wired by Job #118 — the Bazooka, six clips.** All lengths **measured** with `Sound.TimeLength` in
Studio after `IsLoaded`, never inferred from a filename (that rule exists because of the M16 above).

| Clip | ID | Measured | Role |
|---|---|---|---|
| `bazooka_shoot` | `135920240434402` | **5.094 s** | fire variant A — a long take with a rolling tail |
| `bazoka_shoot` | `122026452986070` | **1.440 s** | fire variant B — short and punchy |
| `rocket_whistle` | `138261119768443` | **3.840 s** | starts at t = 0.16 s so it **ends on the blast** |
| `rocket_loop` | `73214531471418` | **1.848 s** | looped on the moving rocket |
| `rocket_impact` | `73027674412530` | **2.112 s** | the blast heard from a distance — 3D at the impact point |
| `rocket_impact_near` | `108549200090609` | **4.776 s** | the blast on top of you — **played 2D**, and debounced |

> ⚠️ **The two fire takes are spelled differently on purpose** (`bazooka_` / `bazoka_`) — that is how the
> user named the files. `WeaponServer.cueRandom` picks one at random per shot.
>
> 🔴 **`impact` and `impactNear` cannot both be positional Sounds.** A 3D Sound has no per-listener
> branch, so making both positional would play **both** to everyone at different volumes. Each client
> picks exactly one from its own camera distance (~70 studs), which is what lets six players hear one
> explosion correctly from six positions.
>
> ⚠️ `impactNear` is **4.776 s against a 5 s reload**, so a player shelling their own feet on cooldown
> would keep it almost continuously running and a crew would stack it — the cicada failure in miniature.
> It is debounced in `RocketFx`.
>
> ⚠️ The rocket's clips are listed in `WeaponAssets.ROCKET` but **played from
> `StarterPlayerScripts/Combat/RocketFx.local.luau`, which holds its own copy of the four ids** — the
> client cannot read ServerStorage. Same constraint that put `ItemDefs.HOLD_ANIM` in ReplicatedStorage.
> Keep the two in step.
>
> ⚠️ **The Bazooka has no `empty` dry-fire click, deliberately** — a launcher with no rocket loaded has
> no firing pin to click. The reticle goes red and the UI `emptyClick` plays instead.

**Also wired by Job #079:** `empty_gun` `75733077651437` (dry-fire, was already in inventory) ·
`shotgun fire high quality` `129597576449946` + `shotgun-pump` `113837896417526` (Creator Store, free) ·
and the axe set reused from roblox.defender — `AxeSwing` `210946558`, `AxeChop` `8936215056`,
`Equip` `2304904662`. Torch reuses `crackle-campfire` `113774133604878`.

> ⚠️ **One Sound per weapon, restarted — never an instance per shot.** The pistol fires every 0.22 s and
> the shotgun clip is 3.21 s long; creating a `Sound` per bullet is the stacking mistake
> `GameSoundscape`'s header documents about the cicadas.

> Still unuploaded weapon/boat audio, local mp3s only: `assets/Objects/Boat/Sounds/boat_on_fire.mp3`,
> `boat_destroyed.mp3`, `metal_hit_1_sec.mp3`. Alligator SFX exist in `assets/Objects/Monsters/`.

## 3.3 GAME place station buildings (Job #074)

The game place now uses the **same station convention as the lobby** (§1.3): an editor-placed Model with
a `Station` attribute and an invisible `Anchor` part that hosts the prompt. Job #074 is the first thing
in the game tree to read that attribute.

| Station | Object | Source | Status | Notes |
|---|---|---|---|---|
| `RobuxShop` | small kiosk hut | Meshy (user) | <span style="color:#2e9c3f">✅ placed + wired</span> | **The same mesh as the lobby's** — `81119390187013`, registry `meshes.md` (named `RobuxhShop` *(sic)* in both places). Editor-placed at `Workspace.SpawnBase.Stands.RobuxShop` with `Anchor` + `EntrySign`. Replaced the green 4×5×2 greybox block `StartShopServer` used to spawn |

> ⚠️ **`CollisionFidelity` was `Box` on import** and had to be set to `PreciseConvexDecomposition`
> (Job #074). On a 15 × 18.8 × 20 mesh, `Box` is an invisible 20-stud cube — the counter and the space
> under the eaves are sealed, so you cannot walk up to the shop. Measured after the fix: the collision
> surface now sits **3.5–6.9 studs inside** the old box on all four sides.
>
> **This is an authoring-time property — a runtime script cannot write it, and it only persists if the
> place is SAVED.** Any future station mesh dropped into the game place needs the same treatment; see the
> `meshy-collision-fidelity` rule.


## 3.4 River foliage — the three bands (Job #076, planned 2026-08-05)

**No new assets needed.** The §1.1 set is sufficient — the hand-built starting area is the target look and
is built entirely from it. Each bank splits into three bands by distance from the water.

| Band | Inland | Models | Why |
|---|---|---|---|
| **1 — shore** | 0–35 | `PalmCoconut` (**4 meshes** — the hero palm) · `BushPack` (8) · `FernTall` (1) · `PalmLowPoly` (3) · `LogMossy` (1) · `RockA/B/C` (1) | the cheap models carry the look |
| **1 — alley** | waterline | `PalmCurved` ⚠️ **63 parts**, SPARSE (~1 per 80 studs per bank) | leans out over the channel; sparse is what makes 63 parts affordable |
| **2 — mid** | 35–110 | `PalmTall` ⚠️ **65 parts**, sparse · `PalmCoconut` · `FernTall` · rocks | individual trees you can see between |
| **3 — back** | 110–220 | `JungleTreesPack` ⚠️ **112 instances, 218 studs long** — TILED, not scattered | a solid canopy wall that hides the mountain seam |

**Terrain materials** (all built-in `Enum.Material`, no assets): riverbed **Sand** (currently Grass —
wrong), shore strip **Sand** fading inland, jungle floor **Grass + LeafyGrass** mixed by noise; Rock above
y=26 and Snow above y=40 unchanged.

> ⚠️ **Budget: ~5,560 live instances** in the 1020-stud streaming window, against ~1,630 for today's
> greybox. `PalmCurved` + `PalmTall` are **2,875 of that — over half the budget from ~45 objects.** If a
> real device complains they are the first lever, and swapping them for MeshPart palms later is one line
> per band-table entry. That is why we deliberately did NOT source replacements now.

## 3.6 Camp night practicals + the river log jam (Job #079 — ✅ BUILT & VERIFIED 2026-08-16)

Two Meshy models, imported to `ServerStorage.AssetLibrary.Props`, both **1 BasePart**.

| Model | Where it is used | Scale | Notes |
|---|---|---|---|
| `Lantern` | `CampAmbience` perimeter practicals — 2 per camp | **0.63** → 2.39 studs | ships at 3.80 studs, three-quarters of a player's height |
| `LogJam` | `RiverBootstrap.OBSTACLES` — 4th obstacle type | stretched to the trigger | floats, `submerge 0.45`, slow **0.72** / damage **16** |

### The camps had lights with nothing making the light

Job #077 lit each camp with three `PointLight`s on **invisible 1×1×1 anchors floating 4.5 studs up**.
The `Lantern` gives the two perimeter ones a real fixture, with the light at the glass (`lanternFlame
0.55` up the model). The hut's interior light is **deliberately left bare** — it hangs 6 studs up inside
a hut with no surface to stand a lantern on, and a lantern floating under a roof looks worse than an
unexplained glow. It wants a modelled hook or rafter first.

### 🔴 The bug this shipped with, and the rule that follows from it

The perimeter practicals reuse `LAYOUT.sandbags[1]` and `[3]` — the **same x/z as two sandbag walls** —
so the lantern has to sit on TOP of the wall (on the ground it would be inside the barricade).

The first version computed that height as a constant: `groundY + 5.30`, from `SandbagWall`'s measured
5.60 height less `prop`'s 0.30 sink. **Every lantern floated exactly 1.0 stud.** The arithmetic was
right and the inputs were wrong — `prop` seats each sandbag on its OWN `groundAt(x, z)` raycast, while
`params.groundY` is the ground under the **campfire**. Carved camp floors are not flat, so the two
disagree by a stud.

> ⚠️ **Do not reintroduce a mount-height constant.** `CampAmbience.mountFor` finds the actual
> `SandbagWall` at the slot and measures its top, falling back to a terrain raycast at that x/z when the
> camp has no sandbags (`kind.sandbags = false`). Verified: 4/4 fixtures seated, worst gap **0.000**.

This is the same footprint-vs-point mistake `FoliageDefs` documents at length, in a new disguise: *don't
predict where another system put something — go and measure it.*

### ⚠️ Verifying anything at a camp: streaming follows the CHARACTER, not the camera

Three screenshots during this job showed "no lantern" and were **all invalid**. `StreamingEnabled` is on,
and moving only the client camera to the camp leaves the client with **0 BaseParts** for that whole
landing site — the replication focus is the character, 2,000 studs away at the spawn base. The camp
still *appeared* to render, which is what made it convincing.

> **Move the character, wait, then confirm the client actually has the parts** (`939` for a landing site)
> before trusting any in-game screenshot. `WorldToViewportPoint` reporting "onScreen, clear line of
> sight" does **not** mean the thing exists client-side.

Also worth knowing: teleporting the player into a camp gets them downed by the guards within seconds,
and the "YOU ARE DOWN" panel sits exactly over the middle of the screen. Stand ~120 studs off — outside
the 55-stud guard leash, inside the streaming radius.

## 3.5 Dock camps & trading villages (Job #077 — ✅ BUILT & VERIFIED 2026-08-15)

<span style="color:#2e9c3f">✅ **All shipped.**</span> Greybox retired: `Hut` blocks → `Tent` (⚠️ scaled **0.42** —
it ships at 43×13×34 and reads as a giant tarp at 1.0) + `BahayKubo5`/`BahayKubo1` stilt huts ·
`LootCrate` → `Barrel` (bulk) + `CrateWood` (ONE hero per camp) · kind-crates → `AmmoBox` ·
the 8-block `TradingPost` → `BahayKubo7` · floating `BillboardGui` shop sign → a physical WoodPlanks
board on posts with a `SurfaceGui` on both faces (the billboard was `AlwaysOnTop` and rendered through
the terrain) · `GoldNugget` Neon cube → the real mesh (⚠️ it is a bare **MeshPart**, not a Model) ·
`CarriedCrate` → a scaled `Barrel` · `DockServer` plank Deck → `Dock` (the old `Deck` survives as an
INVISIBLE anchor so `TieSpot`/rope/prompt geometry is unchanged) · `SandbagWall` ×3 as cover ·
`RangerTower` at each landing. ⚠️ **Job #119: TWO per landing now** — `CampDefs.KIND.deep.tower` was turned on so the
deep camp has a tower for the RocketMan to stand on; the near camp keeps its (unmanned) one as the
silhouette you see from the water. Both towers carry an `AmmoBox` salvage chest (45–70) on their
`InnerPlace` pad. That is **+257 parts per live landing site** (tower 128 + soldier 85 + 2 chests 44).

**Measured cost: 880 BaseParts per landing site.** Part counts are BasePart counts — do NOT re-derive
them from `#model:GetDescendants()`, which runs 2–6× higher (`AmmoBox` is 22 parts but 140 descendants;
`RangerTower` 128 vs 356). Camp clearing ring = ~80 cheap trees (`PalmCoconut`/`PalmLowPoly`/`BushPack`/
`FernTall`), NOT `JungleTreesPack` — at 218 studs long it cannot fit a 400-stud basin that also holds
two camps.

### NEW — jungle river-village huts (sourced 2026-08-05)

Creator Store, **all four by one author** (`Houseplant_Leaf`) so the set reads as one style. Filipino
*Bahay Kubo* stilt houses — a hut raised on posts is what a river-village trading post looks like.
**Licence:** free, *"credits would be highly appreciated"* → attribution, not a requirement.
**Localized** to `ServerStorage.AssetLibrary.Structures` (GAME place).

| Model | rbxassetid | Instances | Size | Use |
|---|---|---|---|---|
| `BahayKubo5` | 10019841237 | **13** | 29.6×22.4×34.0 | **best value** — default camp hut; also in the Job #108 village mix |
| `BahayKubo2` | 6811407916 | 18 | 24.7×16.1×21.8 | Job #108 outlying village hut (was unused before it) |
| `BahayKubo1` | 6808910590 | 22 | 19.8×16.2×27.0 | deep-camp hut + Job #108 outlying village hut |
| `BahayKubo7` | 10031256291 | ⚠️ **95** | 40.2×25.8×50.2 | ⚠️ **unused since Job #107** swapped the trading post to `RobuxShop` |

**⚠️ ALL FOUR ARE STILT HOUSES — AND THEY COME WITH THEIR OWN STAIRS.** The interior floor sits **3.5
studs** above the model's base on `BahayKubo1`/`BahayKubo2` and **4.6** on `BahayKubo5`, which is above
the ~2-stud ledge a Humanoid climbs for free — but each model ships a **built-in staircase** at its one
entrance, and walking up it is a normal walk (measured biggest single step: Kubo1 **0.87**, Kubo2
**1.00**, Kubo5 **1.00**). **Build nothing at the door.**

> 🔴 Job #108 assumed the opposite without checking, and bolted two wooden treads on beside the real
> staircase. Reported as *"2 strange blocks [that] block the entrance"* and removed in Job #109. If you
> are about to add an entrance aid to one of these, measure first — the model already has one.

What DOES matter is the **yaw**: #1 and #2 have exactly one way in, so a random rotation can aim it at
the jungle wall. `CampDefs.VILLAGE.entrance` carries the floor rise and the STAIR bearing per model —
`BahayKubo1` **212°**, `BahayKubo2` **208°**, `BahayKubo5` **160°**, where 0° = the model's +X and the
angle increases toward +Z.

⚠️ Do not confuse the stair bearing with the *widest clear arc*, which is what #108 measured and called
a door. They differ by 152° on `BahayKubo5` (160 vs 312). Re-measure with the probe recorded in
`Jobs/109/implementation-plan.md` — cast LOW (roof eaves read as a 9–11-stud "step") and sample from at
least 32 studs out (at 18, `BahayKubo5` is still standing on its own deck and every bearing reads flat).

**SECURITY scan: 0 scripts, 0 remotes, 0 tools, 0 ClickDetectors** in all four.

> ⚠️ **Lesson worth keeping: the flag is not the scan.** `insert_asset` returned **`sandboxed: true` for
> #5 and #7** and `false` for #1/#2 — which reads like a script warning — yet a full descendant scan found
> nothing executable in any of them. The flag varies between assets and does not substitute for scanning.
> Full detail in registry `models.md`.

Cleaned on insert: stray publisher `Camera` deleted from each · **`CollisionFidelity` →
`PreciseConvexDecomposition` on 15 instances** (they shipped `Default`, which seals the underside of a
house on stilts — defeating the entire point of building on stilts) · all forced `Anchored`.

### NEW — `GoldNugget` (Meshy, imported 2026-08-05)

`ServerStorage.AssetLibrary.Props.GoldNugget` — MeshPart `rbxassetid://101010123909666`, PBR via
`SurfaceAppearance`, **0 scripts**. Replaces a 2×2×2 **Neon** cube.

Import hygiene applied: `Anchored = true` (it shipped unanchored) · `CanCollide = false` (matches the
greybox — it is collected by ProximityPrompt) · **resized 1.40 → 2.00 studs** on the long axis, because a
1.4-stud object lying in terrain grass is hard to spot and this is a rare pickup you are meant to notice.

> **`CollisionFidelity = Box` — a deliberate exception to our standing Meshy rule.** That rule
> (`PreciseConvexDecomposition`) exists so players can walk under wings and through gaps in large imported
> geometry. This is a 2-stud pebble with collision **off**, so precise geometry would be memory spent on a
> hull nothing can ever touch.
>
> ⚠️ **Gotcha found doing it:** setting `Size` on a MeshPart **re-derives its collision geometry and
> reverts `CollisionFidelity`**. Resize FIRST, then set fidelity, then verify by re-reading — the first
> attempt silently reverted to `Default`.

### Campfire — BUILD, do not source  <span style="color:#2e9c3f">✅ built</span>

The re-dressed camps need a fire and the GAME place has none (the built campfire in §1 is the LOBBY's).
**Every Creator Store result was the same spam-uploaded "realistic campfire"** — and "realistic" is the
wrong register for our stylized look. Rebuild the lobby's recipe instead: `RockA/B/C` ring + crossed
`LogMossy` + Fire/Smoke/embers/PointLight. Assets we already own and scanned, on-palette, no attribution,
and identical to the lobby by construction.

## 3.7 END ZONE — the extraction airfield (Jobs #110 / #111, 2026-08-23)

The river's destination at **z 18000–18900**, `Workspace.EndBase`. Job #110 copied the hand-sculpted
START basin there under a 180° rotation `(x,y,z) → (−x, y, 18000−z)`; the user then re-sculpted it and
built an airfield extraction on it. **Every model here is a REUSE of something already sourced for the
lobby** — no new sourcing was needed.

| Asset | Count | Source | Status | Notes |
|---|---|---|---|---|
| Cargo plane | 1 | reuse — §1.2 `Cargo plane` | <span style="color:#2e9c3f">✅ placed</span> | `EndBase.Objects.Plane.Plane`, 88×34×95 at (446,34,18306), yaw −9° to match the strip |
| Airstrip / runway | 3 tiles | reuse — §1.2 `Airstrip / runway`, mesh `114620021340964` | <span style="color:#2e9c3f">✅ placed</span> | `EndBase.Objects.RunWay` ×3 at x 403 / 488 / 573, slab top y ≈ 21 |
| Watchtower | 3 | reuse — Store `RangerTower 81318418778699` | <span style="color:#2e9c3f">✅ placed</span> | `EndBase.Objects.RangerTower` ×3, all seated on grade |
| Camp dressing (tents, sandbags ×48, crates, barrels, rocks, logs, foliage) | — | reuse — carried over in the §1.7 / 3.x sets | <span style="color:#2e9c3f">✅ placed</span> | Rotated copies of the crash-site camp; the copy stripped `SpawnLocation`, `Plane`, `Dock.BoatPlace`, `Dock.PlacePlace` |
| **Extraction pad** | 1 | **BUILD — generated at runtime** | <span style="color:#2e9c3f">✅ built</span> | `Workspace.ExtractionPad`, built by `EndZone/EscapeServer`. A part-for-part replica of the lobby launch pad (§1.4) measured off `PartyPad_Yellow`, recoloured **gold** (STYLEGUIDE §4 = progression), with a 14×34 beacon column instead of the lobby's 5×3.6 — it is the only wayfinding in the end zone and must read from the dock 219 studs away |
| `Escape` marker | 1 | editor-placed (user) | <span style="color:#2e9c3f">✅ placed</span> | `EndBase.Objects.Plane.Escape` — invisible 4×1×2 nub at (390,21.6,18299). **Found BY NAME** by `EscapeServer`; the pad is generated onto it. Moving it moves the extraction |
| **Generator** | 3 placed + 1 template | user Meshy/Store import | <span style="color:#2e9c3f">✅ placed + WIRED (Job #115)</span> | `EndBase.Bunker.Generator1/2/3`; template at `AssetLibrary/Structures/Generator`. One 8.96×8×5.31 MeshPart per model (`Generator3` is the same asset at **half scale**, up on a tower at y 63.5). **DESTRUCTIBLE** — 150 HP, electricity + hum while alive, smoke + "DISABLED" once dead. Found BY NAME (`Generator*`) under Workspace by `World/GeneratorServer`; anything tagged `Generator` is wired too, so a later job can spawn more |
| Generator audio | 2 | user uploads 2026-08-25 | <span style="color:#2e9c3f">✅ wired (Job #115)</span> | `eletricity_going` **90617779140381** (3.94 s) — looped positional idle **and**, restarted + cut at 0.5 s, the hit zap; `generator_dead` **119782619832290** (1.10 s) — one-shot on death. Both resolved through `World/Generators.luau`'s own `SFX` table (the `GameSoundscape` convention), never inline |
| **Bunker** | 1 placed + 1 template | user Meshy/Store import | <span style="color:#2e9c3f">✅ placed + WIRED (Job #116)</span> | `EndBase.Bunker.Bunker` — shell MeshPart 36.89×25×38.48 at (268,30.5,18362), interior floor y 22.10, ceiling 33.61. Template at `AssetLibrary/Structures/Bunker`, which already carries **all five markers**, so a spawned bunker needs no editor work. ⚠️ **Three nested instances are called `Bunker`** (Folder → Model → MeshPart) — `World/BunkerServer` therefore finds it by STRUCTURE (*a Model with a `BunkerDoors` Model child*), never by name |
| **BunkerDoors** | 1 placed + 1 template | user Meshy/Store import | <span style="color:#2e9c3f">✅ placed + WIRED (Job #116)</span> | `EndBase.Bunker.Bunker.BunkerDoors` — 17×13.36×7.07, closed pivot y **22.167** (the pivot is the door's BOTTOM edge, not its centre). Slides **13.86 studs** down over 10 s into the shell base and the terrain beneath it. ⚠️ The template at `AssetLibrary/Structures/BunkerDoors` is the same asset at **DOUBLE** size (34×26.73×14.14) — every offset in `Bunkers.luau` is derived from `GetBoundingBox`, never typed |
| Bunker markers | 5 | editor-placed (user) | <span style="color:#2e9c3f">✅ placed</span> | Invisible 2×0.5×1 nubs inside the `Bunker` model. **Wired (Job #116):** `LightLocation` (274.8,38.7,18350.6) → status lamp; `ChestLocation` (273.3,22.2,18365.6) → the hoard. **Not yet used:** `KeyPadLocation`, `NumberLocation` — reserved for a future keypad-code mechanic. Found BY NAME, so moving one moves the thing it carries |
| **Bunker status lamp** | 1 | **BUILD — generated at runtime** | <span style="color:#2e9c3f">✅ built (Job #116)</span> | Neon bulb + dark housing + bracket + `PointLight` (range 14), built onto `LightLocation` by `World/Bunkers.luau`. **RED pulsing while locked (0.7 s), GREEN once open (1.7 s)** — the pulse runs CLIENT-side (`UI/BunkerClient`) off one `Open` attribute, because a server tween would replicate two changing properties every frame forever. ⚠️ The bulb's standoff from the marker is **measured, not typed** (2.00 studs here): seated flush it sits under the bunker's roof lip and is invisible from the door. ⚠️ NOT tagged `NightLight` — it is a status readout and must read at noon |
| **Bunker hoard** | 1 chest + 1 share/player | reuse — `AssetLibrary/Props` | <span style="color:#2e9c3f">✅ built (Job #116)</span> | Spawned when the doors start down. `GoldChest` as the hero prop + one `GoldNugget` per crew member, each reserved to a `UserId`, labelled *"X's share"*, tagged `Lootable` (so `LootGlow` finds them in the dark) and worth **3 Gold + 150 Salvage**. A warm gold `PointLight` over the hoard — a windowless bunker is dark at NOON, so it is not a `NightLight`. 🔴 **`GoldChest` has a BAKED `GetScale() == 6.0`** and `Model:ScaleTo` is ABSOLUTE, so Job #079's `ScaleTo(0.65)` gives an 11%-size toy here — the chest is sized as a fraction of the room's measured headroom instead |
| Bunker alarm | 1 | user upload 2026-08-25 | <span style="color:#2e9c3f">✅ wired (Job #116)</span> | `alarm` **103190295733089** (**8.05 s**, measured) — one-shot at the doors the instant they start down, volume 0.85, 300-stud tail so the crew hears it from the furthest generator (155 studs). Deliberately NOT looped: 8.05 s under a 10 s slide would restart two seconds before the doors land |

⚠️ **Do not rename `Escape` or `EndBase`.** `EscapeServer` halts with a warning if either goes missing,
and the run then has no win condition at all.

⚠️ **The generators are found by the `Generator` NAME PREFIX, not by path** (Job #115). Renaming one to
something that does not start with `Generator` silently un-wires it — no HP, no bar, no sound, and it
stops being shootable. Adding a fourth is just placing a copy named `Generator4`.

⚠️ The end-zone camp is a rotated copy of the crash site, so it currently reads as *the same camp again*.
Re-dressing it to feel like a destination rather than a repeat is open work.

# 4) ENEMIES / CHARACTERS

**Job #078 is the live job.** Prompts + Pixabay search terms for every row below are in
[`Jobs/078/asset-shopping-list.md`](Jobs/078/asset-shopping-list.md). Ids go into
`sync/ServerScriptService/Enemies/EnemyAssets.luau` — the ONE place a creature id is written.

> ✅ **Wiring is already done (Job #078).** `EnemyRig` builds every creature — river threats *and* camp
> guards, which previously had their own greybox path with **no eyes**. Everything degrades: no model →
> greybox, no animation id → no animation, no sound id → silence. So these can be filled in one at a
> time without breaking anything.
>
> ⚠️ Every sourced model needs **`EyeLeft`/`EyeRight` Attachments** on the head (the Job 039 glowing-eye
> system is attachment-aware) and must face **-Z** (or set `yawOffset = 180`). Models go in
> `ServerStorage.AssetLibrary` named **exactly** as the creature, and that path is **not Rojo-synced** —
> save the place or they vanish.

## 4.1 Creature models — Meshy

| Creature | In-game size | Model | Rig | Status |
|---|---|---|---|---|
| **Crocodile** (sea) | 6×3×16 | <span style="color:#2e9c3f">✅ `Aligator` MeshPart `83415039015970`</span> | **none needed** — water creature | <span style="color:#2e9c3f">✅ DONE</span> — model, 5 sounds, procedural water motion, wake + splash, eyes |
| **Wolf** (land, riverbank — *was Panther*) | 5×4×11 | <span style="color:#2e9c3f">✅ reused from **roblox.defender**</span> | procedural joint swing | <span style="color:#2e9c3f">✅ DONE</span> — rig + 2 bundled sounds, 0 credits |
| **Bandit** (every `CampGuard`) | 5×4×11 | <span style="color:#2e9c3f">✅ `WesternBandit` from **roblox.defender**</span> | R15, Defender's animation ids | <span style="color:#2e9c3f">✅ DONE</span> — rig + 6 bundled sounds, 0 credits |
| **Piranha** (sea) | 2×1.2×4 | <span style="color:#2e9c3f">✅ Meshy, imported</span> | **none needed** — water creature | <span style="color:#2e9c3f">✅ model done</span> · **deliberately SILENT** (see below) |
| **RiverHippo** (sea) | 8×5×12 | <span style="color:#2e9c3f">✅ Meshy, imported</span> | **none needed** — water creature | <span style="color:#2e9c3f">✅ DONE</span> — shares the Crocodile's 5 sounds |
| **Boar** (land) | 4×3×7 | <span style="color:#2e9c3f">✅ reused from **roblox.defender**</span> | procedural joint swing | <span style="color:#2e9c3f">✅ DONE</span> — rig + 3 bundled sounds, 0 credits |
| **RocketMan** (land, camp watchtower) | 4×5.8×3 | <span style="color:#2e9c3f">✅ `ArmySoldier` — Store **11927692797** (free, 0 scripts)</span> | R15, 15 Motor6D — owned clip ids, **no idle clip on purpose** | <span style="color:#2e9c3f">✅ DONE (Job #119)</span> — stripped 122→85 parts (a 37-part M4 removed), holds the Bazooka, 2 alternating melee swings, Bandit's 5 sounds. ⚠️ **`fire` animation slot is EMPTY** — wants a standing shoulder-fire R15 clip |
| Anaconda | TBD | Meshy M6 | slither + strike | ▫ later — **new enemy, needs stats + spawn rules first** |

Concept art on disk: `assets/Enemies/{Crocodile,Hippo,Anaconda,Puma}.png`. ⚠️ There is art for **Puma**
and **Anaconda** but the code has **Panther** and no snake; and there is **no art** for Piranha or Boar.

## 4.2 Creature sounds — Pixabay (5 per creature) — <span style="color:#2e9c3f">Crocodile ✅ complete</span>

Keys are `idle` / `aggro` / `attack` / `hurt` / `death`. ⚠️ Roblox audio moderation is unpredictable —
`night_starts` was rejected **twice** in Job #073, so grab a second choice for anything critical.

| Asset | Status | Notes |
|---|---|---|
| `croc_idle` | <span style="color:#2e9c3f">✅ 137066735880685</span> | gator hiss, 5.04 s — fires every 10–22 s while NOT chasing |
| `croc_aggro` | <span style="color:#2e9c3f">✅ 108958436464973</span> | 1.59 s — widest rolloff of the set, must carry over the engine |
| `croc_attack` | <span style="color:#2e9c3f">✅ 94063943857259</span> | 2.09 s — generic monster bite; swappable for an `alligator bite` clip |
| `croc_hurt` / `panther_hurt` | <span style="color:#2e9c3f">✅ 137192983266942</span> | generic `animal-hurt`, **shared** by both creatures |
| `croc_death` / `panther_death` | <span style="color:#2e9c3f">✅ 120708334083507</span> | generic `animal-die`, **shared** by both creatures |
| Boar ×3 bundled | <span style="color:#2e9c3f">✅ pig-noticed_me / pig-attack / pig-killed</span> | came with the Defender rig |
| Wolf ×2 bundled | <span style="color:#2e9c3f">✅ `Sound` 1989743206 (aggro) · `Growl` 4064886644 (attack)</span> | came with the Defender rig; hurt/death share the generic pair |
| Bandit ×5 bundled | <span style="color:#2e9c3f">✅ EnemySpottedPlayer / EnemyScream1-3 / Laugh1</span> | came with the Defender rig — no uploads needed |
| RiverHippo ×5 | <span style="color:#2e9c3f">✅ shares the Crocodile set</span> | wider rolloff — a hippo should carry further than a croc |
| Piranha | <span style="color:#2e9c3f">✅ none, by design</span> | ~6 alive at once → any cue plays 6× (the cicada-stacking mistake). `boat_hit` already covers being bitten. |
| Piranha / Hippo / Boar / Anaconda sets | ▫ later | |

⚠️ **The Creator Store is useless for these** — searching `crocodile growl hiss` returned *"Sandstorm
part 2"* and a piano sample; `animal roar attack` returned a football chant. Pixabay + upload is the
route, as it was for all existing Jungle audio.

## 4.3 Other

| Area | Items | Status | Notes |
|---|---|---|---|
| Player torch / lamp | carried light item | ▫ stub | night survival |

# 5) UI / HUD (global)

| Area | Items | Status |
|---|---|---|
| Loading screens | lobby + game (built in code) | <span style="color:#2e9c3f">✅ built</span> |
| Loading background art (`LoadingBackground`) | jungle/river key art, `rbxassetid://73636751330777` | <span style="color:#2e9c3f">✅ wired</span> — fallback ID in `LobbyLoading.local.luau` + `GameLoading.local.luau`; overridable by a `ReplicatedFirst.LoadingBackground` ImageLabel |
| Teleport / intro sequence art | plane-crash cold-open visuals | ▫ stub |
| HUD icons / role-suitability icons | per `jungle-style` + STYLEGUIDE | ▫ stub |
| **Design system (`Theme` / `Components` / `UISound` / `UIBus`)** | now in **BOTH** trees | <span style="color:#2e9c3f">✅ ported to the game place (#074)</span> — see the note below |

> **The design system exists twice, byte-identical by contract (Job #074).**
> `lobby/sync/ReplicatedStorage/UI/` and `sync/ReplicatedStorage/UI/` — 4 files, ~1380 lines. `Theme`'s
> own header had always said *"the byte-identical `sync/` copy is added when the game place is
> restyled"*; #074 needed it for the Robux shop and did exactly that.
>
> **Same arrangement as `MonetizationDefs` / `BoatParts` / `BoatPaint`:** two separate Rojo trees, no
> shared package layer, so the copies are kept in step by hand. **Edit one, copy it to the other in the
> same commit.** The drift check is `diff -r lobby/sync/ReplicatedStorage/UI sync/ReplicatedStorage/UI`
> — it must print nothing. Nothing was given a per-file "this is a copy" header precisely so that check
> stays noise-free.
>
> ⚠️ Only the game's `RobuxShop` consumes it so far. The other 15 game HUD scripts are still hand-rolled
> greybox on raw `Color3`/`Enum.Font` — restyling them is its own job, but it no longer needs a port
> first.

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
| `Cosmetics.png` | ~~Cosmetic Bundle (249 R$)~~ | game pass | `1918077339` | `130780112255781` | `95212286807985` | <span style="color:#b0472f">⛔ REMOVED from the in-game shop (Job #067)</span> |
| `SelfRevive` | Self Revive (20 R$) | dev product | `3612677893` | — | **`131281323216251`** | <span style="color:#2e9c3f">✅ live + wired</span> |
| — | Extra Inventory Slots (149 R$) | game pass | `1935044952` | `130798210334331` | **`130798210334331`** *(same id — this Hub upload has alpha)* | <span style="color:#2e9c3f">✅ live + wired</span> |
| `RobloxPassM16.png` | **Lifetime M16 (150 R$)** | game pass | `1954603618` | `118709115773836` | **`99770814546746`** *(the pass store image, user-supplied)* | <span style="color:#2e9c3f">✅ live + wired (Job #117)</span> |
| — | **M16 (one run, 30 R$)** | dev product | `3709767395` | — | **none — uses `Theme.icon.rifle` `87494055704448`** | <span style="color:#2e9c3f">✅ live + wired (Job #117)</span> |
| `RobloxPassBazooka.png` | **Lifetime Bazooka (250 R$)** | game pass | `1956512376` | `78985801749301` | **none — uses `Theme.icon.bazooka` `76642882799637`** | <span style="color:#2e9c3f">✅ live + wired (Job #118)</span> |
| — | **Bazooka (one run, 80 R$)** | dev product | `3709767468` | — | **none — uses `Theme.icon.rocketAmmo` `100284588876499`** | <span style="color:#2e9c3f">✅ live + wired (Job #118)</span> |

> 🔴 **The M16 rows are split on purpose: the PASS row shows the product artwork, the ONE-RUN row shows
> the weapon.** Set by the user after comparing both on screen (2026-08-25): *"For Lifetime use pass icon,
> and one time use rifle icon"*. The two rows sit adjacent and both titles start with "M16", so they have
> to be tellable apart at badge size, and two variations on a gun did not do that.
>
> ⚠️ **Three different images are in play for this one pass — do not substitute them for each other.**
> `RobloxPassM16.png` → `118709115773836` is the **source art** (1254×1254, RGB, **no alpha**, read from the
> PNG's own IHDR) and is for the Hub listing only. `99770814546746` is the **store image the user supplied
> for in-game use**, and is what `Theme.productIcon.m16Lifetime` points at. `87494055704448`
> (`assault-rifle`) is the **glyph**, used by the one-run row and the hotbar.
>
> `Theme.icon.rifleAmmo` (`bullet`, `134307949592665`) is consequently **registered but unused** — kept as
> the natural glyph for an M16 ammo row if the trading post ever sells rifle rounds.
>
> ✅ **The Bazooka is wired as of Job #118 (2026-08-25)** — it had been live on the Hub and connected to
> nothing since the M16 shipped, which meant the 250 R$ pass was buyable from the experience store page
> and delivered nothing. That is closed. And Job #117's bet paid off: `RunGrants` really was generic, so
> the whole selling half was **two data rows** (`RunGrants` + `GamePasses`) plus one key in
> `ProfileConfig.RUN_GRANT_KEYS` — neither shop file, `MonetizationServer` nor `RifleGrant` changed a line.
>
> 🔴 **NEITHER BAZOOKA ROW USES THE HUB ART IN-GAME, AND THAT IS DELIBERATE.**
> `RobloxPassBazooka.png` → `78985801749301` is **1254×1254 RGB with NO alpha** (PNG IHDR colour type 2,
> read from the file), exactly like `RobloxPassM16.png`. The M16 pass row only got a clean round badge
> because the user supplied a *second*, transparent store image; **no such image exists for the Bazooka**,
> so pointing `productIcon` at the Hub art would render a white square inside the circular badge.
>
> Instead the two rows are split **by meaning**, which also solves the "two adjacent rows both starting
> with Bazooka" problem the M16 rows had: the **lifetime** row shows the launcher (`bazooka`) because you
> are buying the weapon forever, and the **one-run** row shows a single rocket (`rocketAmmo`) because you
> are buying one run's ammunition. *If you would rather the pass row show your artwork, the fix is a
> transparent (RGBA) re-upload of that same PNG plus a `Theme.productIcon.bazookaLifetime` entry — not a
> different icon.*

> **Why two:** Creator Hub mattes its thumbnails onto an opaque square/disc, so those ids render as a
> white blob inside the round row badges. The transparent re-uploads (2026-07-31, `*_transparent`) fixed
> it and are what `Theme.productIcon` points at. **Never swap a Hub id into the GUI.**

<span style="color:#2e9c3f">✅ Wired 2026-07-31</span> — the lobby `RobuxShop` shows real store art per row
(Job #065 phase 2). <span style="color:#2e9c3f">✅ **And the GAME place since Job #074**</span> — the
game-place shop was rebuilt on the same design system and now draws the same 7 in-game icons. Verified
live: 7 rows, 7 with art, ids matching this table exactly.

> **Job #074 also closed a money-facing gap in the game place.** Its shop was the Job #046 original and
> had never received Job #069, so it had **no OWNED state** (an owner of the 499 R$ Armored Boat still
> saw a live buy button) and printed the **hardcoded def price** while all three passes run **managed
> pricing** on the Hub. Both are now the lobby's behaviour. Verified in Play: all three passes read
> `OWNED`, gold packs stay live (repeatable dev products — "owned" is meaningless for them).

> **Job #067 changes.**
> · **Cosmetic Bundle** is no longer sold in-game — it was live and delivered nothing (no trails, no wake
>   FX, no emote; nothing read `Owns_cosmeticBundle`). Its ids stay recorded here in case the three
>   features are ever built. **The Creator Hub listing is unlisted by hand, separately.**
> · **Self Revive** created 2026-08-01 and wired to the DOWNED overlay.
> · **Extra Inventory Slots** created 2026-08-02 (`1935044952`, 149 R$) and wired. It is the **one row that
>   uses its Hub id in-game**, and that is fine here — *verified in Play*, this upload carries alpha and
>   renders correctly in the round badge. So "never swap a Hub id into the GUI" is really *"check the
>   matte first"*: the 2026-07-20 batch was matted, this one isn't.
> · **Boat Paint Pack finally does something** (Job #067): 6 hull liveries. It needs **no new art** —
>   liveries are a runtime tint over the existing PBR maps, not new textures. See §2.

## 5.2 In-run HUD icon set — **SOURCING LIST, Job #075** (added 2026-08-02)

The game place's HUD was rebuilt on the design system in Job #075. The **lobby's 23-icon set (§1.9)
already covers most of it** — all five role glyphs (wheel/gun/fuel/tools/medkit), gold, hull, crate,
check, close, trophy, boat, shop, robux — so this list is only the icons with **no honest substitute**.

> **⚠️ Same Flaticon author as the §1.9 set.** *"One pack, one author — mixed packs are the #1 way an
> icon set looks amateur."* Find one of the existing 23 on Flaticon, open the author, take these from
> their catalogue. Full-colour flat, matching the delivered set.

**Placeholders are live and tracked in code.** Each key below exists in `Theme.icon` with an empty id,
and `Components.iconId` substitutes the fallback in the right-hand column so the HUD renders at the
correct size and reads correctly in a screenshot. `Theme.reportPendingIcons()` prints the outstanding
list on every Studio start. **To land one: paste the id into `Theme.icon`, then delete its row from
`Theme.iconPending` AND `Theme.iconFallback`** — in *both* trees (`sync/` and `lobby/sync/` are
byte-identical by contract).

| # | Icon | Search terms | Used by | Placeholder | Priority |
|---|---|---|---|---|---|
| 1 | Scrap / salvage pile | `scrap metal`, `junk`, `salvage` | Salvage chip (`CurrencyHud`), admin grant | `crate` | **required** |
| 2 | Metal plate / girder | `metal plate`, `steel beam`, `iron` | cargo chip (`HudClient`) | `tools` | **required** |
| 3 | Ammo box / bullets | `ammo box`, `bullets`, `ammunition` | cargo chip, dock shop, gunner readout | `gun` | **required** |
| 4 | Heart | `heart`, `health`, `life` | player health bar (`HealthHud`) | `medkit` | **required** |
| 5 | Machete / sword | `machete`, `sword`, `blade` | hotbar slot — Sword | `tools` | **required** |
| 6 | Pistol | `pistol`, `handgun`, `revolver` | hotbar slot, dock shop | `gun` | **required** |
| 7 | Bandage | `bandage`, `plaster`, `first aid` | bandage chip, dock shop | `medkit` | **required** |
| 8 | Checkered / finish flag | `finish flag`, `checkered flag`, `goal` | END marker on the river bar | `bounty` | **required** |
| 9 | Warning triangle | `warning`, `alert`, `caution` | boat-under-attack strip | `bounty` | **required** |
| 10 | Sun | `sun`, `daytime` | DAWN banner | `star` | **required** |
| 11 | Moon | `moon`, `night` | NIGHTFALL banner | `star` | **required** |
| 12 | Skull | `skull`, `death`, `danger` | downed overlay, spectate tag, crew-lost result | `crew` | **required** |
| 13 | Shotgun | `shotgun` | hotbar slot, dock shop | `gun` | optional |
| 14 | Rope / knot | `rope`, `knot`, `mooring` | untie / cast-off button | `tools` | optional |
| 15 | Map pin | `map pin`, `location marker` | dock pin on the river bar, zone banner | `fuel` | optional |
| 16 | Clipboard | `clipboard`, `checklist`, `tasks` | objectives tray header | `check` | optional |

**Needs no asset:** the steer/throttle glyphs `◀ ▶ ▲ ▼` render in Builder Sans.

## 5.2b Trading-post ammo icons — ✅ DELIVERED 2026-08-23 (Job #104)

The dock/village trading post sells handheld ammo now (Job #104), so the two gun-ammo rows needed their
own glyphs. **User supplied both the same day, uploaded from `assets/Images/`.** Verified in Studio via
`GetProductInfo` (name match + AssetTypeId 1 = Image). IDs → registry `images.md` → *Trading-post ammo
icons*; `Theme.icon` keys are `pistolAmmo` / `shotgunAmmo`.

| Icon | Uploaded as | Theme key | Used by |
|---|---|---|---|
| Revolver cylinder / clip | `clip` | `pistolAmmo` | "Pistol Ammo" shop row |
| Two shotgun shells | `bullets` | `shotgunAmmo` | "Shotgun Ammo" shop row |

⚠️ **Not** `ammoBox` — that crate is the boat turret's ammo (cargo chip, gunner readout, "Turret Ammo"
row). The two pools are separate and must not share a glyph; conflating them is the reported bug.

## 5.2c M16 weapon set — ✅ DELIVERED 2026-08-25 (Job #117)

All five files supplied by the user in `assets/Enemies/M16/` and uploaded the same day. The first weapon in
the game sold for Robux.

| File | Uploaded as | Type | ID | Wired as |
|---|---|---|---|---|
| `Rifle.glb` | `Scene` | Model | `84134973846203` | → `ServerStorage.AssetLibrary.Weapons.M16` (see below) |
| — | `output_unwrapped` | Mesh | `101680702520520` | the MeshPart inside that model |
| `rifle_shoot.mp3` | `rifle_shoot` | Audio | `138005496001979` | `WeaponAssets.ART.M16.sound.fire` — see §3.2 |
| `assault-rifle.png` | `assault-rifle` | Image | `87494055704448` | `Theme.icon.rifle` — hotbar slot + the **"M16 (one run)"** shop row |
| `bullet.png` | `bullet` | Image | `134307949592665` | `Theme.icon.rifleAmmo` — **registered, currently unused** (see §5.1) |
| `RobloxPassM16.png` | `RobloxPassM16` | Image | `118709115773836` | Creator Hub pass listing **source art only** (§5.1) |
| — | `Developer Product Image Asset` | Image | `99770814546746` | `Theme.productIcon.m16Lifetime` — the in-game **"Lifetime M16"** row |

**Placed in the GAME place 2026-08-25**, scanned (**0 scripts**), Meshy `Scene` wrapper deleted, matched to
the other two guns (`CollisionFidelity = Box`, `RenderFidelity = Automatic` — a held item has
`CanCollide`/`CanQuery` false, so precise collision geometry is never consulted and would only cost memory).
⚠️ `AssetLibrary` is **not Rojo-synced** — save the place or it vanishes.

> **Orientation and scale were MEASURED, not guessed** — `WeaponAssets`' header records three separate
> occasions when guessing these was wrong. Method: `AssetService:CreateEditableMeshAsync` on the mesh, then
> all **29 264 vertices** bucketed into 12 slices along the long axis. Butt plate at −X (height 0.052),
> tallest slice mid-body at 0.117 (carry handle over magazine + grip), front sight post bump at +0.132, and
> the muzzle tapering to **0.0094 at +X**. So the barrel runs along **X, muzzle at +X** — the same
> convention as the Pistol and Shotgun, but *asserted for this mesh* rather than inherited.
> Source `0.3512 × 0.1200 × 0.0286` → `scale = 14.237` for a 5.00-stud held rifle (the Shotgun is 4.80; a
> rifle should be longer than a sawn-off). The full slice table is in `WeaponAssets.ART.M16`.

## 5.2d Bazooka weapon set — ✅ DELIVERED 2026-08-25 (Job #118)

All eleven files supplied by the user in `assets/Enemies/Bazooka/` and uploaded the same day. The second
weapon sold for Robux, and the **first projectile weapon in the game**.

| File | Uploaded as | Type | ID | Wired as |
|---|---|---|---|---|
| `RocketLauncher.glb` | `Scene` | Model | `77785381227207` | → `ServerStorage.AssetLibrary.Weapons.Bazooka` |
| — | `output_unwrapped` | Mesh | `135181183468020` | the MeshPart inside that model |
| `Rocket.glb` | `Scene` | Model | `132252898028958` | → `ServerStorage.AssetLibrary.Weapons.Rocket` — the **projectile** |
| — | `output_unwrapped` | Mesh | `87692913599759` | the MeshPart inside that model |
| `bazooka_shoot.mp3` | `bazooka_shoot` | Audio | `135920240434402` | `WeaponAssets.ART.Bazooka.sound.fire` — §3.2 |
| `bazoka_shoot.mp3` | `bazoka_shoot` | Audio | `122026452986070` | `…sound.fire2` — §3.2 |
| `rocket_whistle.mp3` | `rocket_whistle` | Audio | `138261119768443` | `WeaponAssets.ROCKET.whistle` — §3.2 |
| `rocket_loop.mp3` | `rocket_loop` | Audio | `73214531471418` | `WeaponAssets.ROCKET.loop` — §3.2 |
| `rocket_impact.mp3` | `rocket_impact` | Audio | `73027674412530` | `WeaponAssets.ROCKET.impact` — §3.2 |
| `rocket_impact_near.mp3` | `rocket_impact_near` | Audio | `108549200090609` | `WeaponAssets.ROCKET.impactNear` — §3.2 |
| `bazooka_icon.png` | `bazooka_icon` | Image | `76642882799637` | `Theme.icon.bazooka` — hotbar slot + the **"Lifetime Bazooka"** shop row |
| `missile.png` | `missile` | Image | `100284588876499` | `Theme.icon.rocketAmmo` — the **"Bazooka (one run)"** shop row |
| `RobloxPassBazooka.png` | `RobloxPassBazooka` | Image | `78985801749301` | Creator Hub pass listing **source art only** — see §5.1 |

**Placed in the GAME place 2026-08-25**, both scanned (**0 scripts** — MeshPart + SurfaceAppearance only),
Meshy `Scene` wrappers deleted, matched to the other guns (`CollisionFidelity = Box`,
`RenderFidelity = Automatic`, `Anchored`, `CanCollide`/`CanQuery`/`CanTouch` false).
⚠️ `AssetLibrary` is **not Rojo-synced** — save the place or both vanish.

> 🔴 **THE WRAPPER DELETION IS NOT COSMETIC.** `InventoryService` indexes only children of
> `AssetLibrary.Weapons` that `IsA("BasePart")`, so a Meshy `Model` wrapper is **skipped in silence** and the
> weapon falls back to the grey greybox box — which, on a 250 R$ purchase, looks like a broken purchase
> rather than a missing unwrap step. Job #118 added a startup `warn` in `InventoryService` that names any
> weapon whose `WeaponAssets.model` has no usable library entry, and says whether it found a wrapper.
>
> ⚠️ **`Rocket` is in `AssetLibrary.Weapons` but is NOT a held weapon** — it is the projectile. The server
> republishes a clone into `ReplicatedStorage.CombatArt.Rocket` at startup, because the projectile is drawn
> **client-side** and no client can read ServerStorage.

> **Orientation was measured TWO ways and they agree**, because `WeaponAssets`' header records three
> separate occasions when guessing it was wrong.
> 1. `AssetService:CreateEditableMeshAsync`, all vertices bucketed into 12 slices along the long axis —
>    **3 859** for the launcher, **14 216** for the rocket. The launcher is tall-and-thin at −X (sight and
>    pistol grip, height 0.062→0.087 against a 0.029 thickness) and round at +X (the tube, flaring to its
>    widest 0.0627 at the very end). The rocket's widest slice by far is at −X (0.258 — the fin span) and it
>    is a plain round body toward +X.
> 2. Both rendered side-on against a matte backdrop with neon axis markers and read off the capture: the
>    launcher's grip and trigger hang toward **−Y**, its open tube is at **+X**; the rocket's fins are at
>    **−X** and its nose at **+X**.
>
> So **muzzle and nose both at +X, +Y up** — the same convention as the other three guns, but *asserted for
> these meshes*. Launcher source `1.1716 × 0.4800 × 0.2507` → `scale = 5.548` for a **6.50-stud** held
> weapon (deliberately longer than the M16's 5.00 and the Shotgun's 4.80 — a shoulder-fired launcher that
> reads the same size as a rifle reads as a mistake). The projectile is scaled at runtime to **4.00 studs**
> from its own live size, so a re-import at a different scale cannot silently produce a 40-stud rocket.

## 5.3 In-run HUD sounds — **SOURCING LIST, Job #075** (added 2026-08-02)

Source: **Pixabay**. Short and dry, **no music tails** — these fire during gameplay, often while the
engine loop and an ambience bed are already playing.

Same placeholder contract as the icons: the keys exist in `Theme.sound` with empty ids, every call site
is already wired, and `UISound` treats an empty id as a silent no-op (distinct from an unknown key,
which still warns loudly). `Theme.reportPendingSounds()` lists the outstanding ones on Studio start.

| # | Key | Search terms | Fires when | Length / feel |
|---|---|---|---|---|
| 1 | `lowFuel` | `warning beep`, `low fuel alert`, `soft beep` | fuel crosses below 20% | ~0.5 s, one beep — **not** a loop |
| 2 | `lowHull` | `metal stress`, `hull damage`, `klaxon` | hull below 30%; boat attacked while ashore | ~1 s, metallic groan |
| 3 | `downed` | `body fall thud`, `injured breath`, `collapse` | you go down | ~1 s, low and heavy |
| 4 | `revived` | `recovery`, `heal swell`, `revive` | you get back up | ~1 s, rising |
| 5 | `runLost` | `defeat sting`, `game over somber`, `failure` | crew wiped | ~2 s, descending |

**Keys that already have an id** — mostly reuse rather than re-sourcing (⚠️ *the three `defender` rows are
pending the user's OK; they are generic SFX and the registry exists so we reuse before re-sourcing*). The
last row is not a reuse: it's a fresh upload delivered mid-job.

| Theme key | Registry asset | Project | Used for |
|---|---|---|---|
| `pickup` | `item_drop` `125050168809089` | defender | loot picked up |
| `hurt` | `player_attacked` `117259006391295` | defender | you take damage |
| `runWin` | `level_completed` `138409734628557` | defender | run won |
| `zoneEnter` | `battle_starts` `79506043370965` | **jungle** | zone-crossing banner |
| `dayBreak` | `morning_starts` `88638394432005` | **jungle** | DAWN banner |
| `nightFall` | `night_starts_2` `75443344927115` | **jungle** | NIGHTFALL banner |
| `emptyClick` | **`empty_gun` `75733077651437`** | **jungle** | dry trigger click — no ammo (turret + handheld). ✅ **delivered 2026-08-05**, verified playable (0.392 s) |

Already correct, no action: `rank_completed…` (objective done) · `upgrade_applied` (station manned) ·
`ui_mouse_click` (equip / slot tap) · `open_close` (objectives tray) · `purchase_success` / `failed`.



# 6) GLOBAL AUDIO

| Area | Items | Status | Notes |
|---|---|---|---|
| Cross-place music / SFX | combat, per-zone ambience | ▫ stub | existing uploads in registry `audio.md` |

## 6.1 GAME place soundscape (Job #073)

Wired by `sync/ServerScriptService/World/GameSoundscape.server.luau`. Ids live in ONE table at the top of
that script — **no asset id inline**, same rule as `PlaneServer` and the lobby's `Theme.sound`. Buses:
`GameMusic` / `GameAmbient` / `GameSFX` `SoundGroup`s.

**No looping music bed by design** — `lobby_intro_music` stays the lobby's signature. The run is scored by
the jungle plus two stingers on the day/night flip.

**It holds silent until `Workspace.IntroWake`** and fades in over 2 s as the crew comes round, so birdsong
never plays under the plane cabin or over the loading mask (the bug Job #072 shipped once).

| Sound | Role | Day vol | Night vol | Status |
|---|---|---|---|---|
| `Jungle day ambience 1` | 2D bed — birds + insects | 0.22 | 0.06 | <span style="color:#2e9c3f">✅ wired</span> |
| `Jungle day ambience 2` | 2D bed — thickener (deliberately lopsided under bed 1, per lobby #069) | 0.14 | 0.03 | <span style="color:#2e9c3f">✅ wired</span> |
| `wind-breeze` | 2D bed — comes forward at night to carry what the birds were carrying | 0.15 | 0.20 | <span style="color:#2e9c3f">✅ wired</span> |
| `cicadas` | 2D bed — **takes over at night; this is what makes night read as night** | 0.04 | 0.34 | <span style="color:#2e9c3f">✅ wired</span> |
| `water-splashes` | positional @ `SpawnBase.Dock.BoatPlace` | 0.5 | 0.5 | <span style="color:#2e9c3f">✅ wired</span> |
| `morning_starts` `88638394432005` | 2D stinger on `Phase` → day | — | — | <span style="color:#2e9c3f">✅ wired + plays</span> — unused since #064 until now. **Re-uploaded 2026-08-02**; old id `98066971477923` is dead |
| `night_starts_2` `75443344927115` | 2D stinger on `Phase` → night | — | — | <span style="color:#2e9c3f">✅ wired + plays</span> (11.0 s). **Took three assets:** `99602574849976` and its re-upload `95532390211599` (same mp3) were both blocked by audio moderation while sibling `morning_starts` re-uploaded cleanly — so the problem was the **audio file**, and the fix was different source audio, not a third upload. → TODO 0044 (resolved) |
| `battle_starts` | combat stinger | — | — | <span style="color:#c93c3c">❌ not wired, on purpose</span> — `EnemyServer` is a continuous trickle spawner with no wave/encounter/aggro-start concept, so there is no moment to fire on. → `Planned/combat-encounter-stinger.md` |

> ⚠️ **`cicadas` is a crossfading BED here, not a one-shot — and the lobby has a latent bug because of it.**
> The clip is **71.4 s long** (read live in Play). `LobbySoundscape` fires it as an "occasional one-shot"
> every 18–44 s, so each copy is still playing when the next starts — the lobby is already stacking ~2.
> The original plan for this place (one-shots every 6–16 s at night) would have layered **six or seven**
> concurrent 71-second cicada loops into a wall of noise. One crossfading bed cannot stack, costs one
> `Sound` instead of N, and is what a night jungle actually sounds like.
> **The lobby still has the stacking** — different place, not touched from here.

> ⚠️ **The dock water anchor is `Dock.BoatPlace`, not a `Pier`.** The lobby finds its anchor with
> `Dock:FindFirstChild("Pier", true)`; that cannot work in the game place, whose dock model is 60-odd parts
> **every one of which is literally named `Part`**. `BoatPlace` is the one stable, named, editor-placed part
> on the waterline (it is what `BoatServer` moors to, #072) — move it in the editor and the sound follows.
