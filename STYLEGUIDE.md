# STYLEGUIDE.md — Last River (Jungle)

> **The game's single source of truth for look, feel, and design rules** — art direction, colors,
> typography, UI, lighting, materials, and the do/don't rules every GUI, model, effect, and scene is
> built to. It sits *above* the engine skills (`roblox-ui`, `roblox-vfx`, `roblox-audio`, …): those
> say *how* to build in Roblox; this says *what Last River should look and feel like*. Once accepted,
> this guide is promoted into a reusable per-game design skill.

**Sources this guide is built from** (in `assets/Images/`):
- `DesignConcept.txt` — the master art-direction brief.
- `jungle_example.png` — reference render (mood, fidelity, expedition-camp density).
- `GUI_PATTERN.png` — the UI kit (HUD, buttons, popups, form elements, party pads).
- `MapIdea.png` — lobby layout (spawn → plane/party → shops → boat dock).
- `boat_ideas.png` — boat tiers, stations, and upgrade modules.
- `LastRiverLogo.png` — the wordmark (stone + jungle-vine lettering, skull, temple, boat).

**Adopted decisions (2026-07-20, Job #063):**
1. **Detailed-stylized, NOT flat low-poly.** Chunky, readable silhouettes with *detailed weathered
   meshes/materials* and warm cinematic lighting. This supersedes GAME.md's earlier "low-poly"
   wording. Kept shippable by the **mobile-perf budget** in §8/§10/§12.
2. Currencies & skills are **unchanged** — Gold (meta) / Salvage (in-run) / River Score (rank), and
   the existing skill trees, per `GAME.md`. The GUI mockup informs **colors + layout only**.

---

## 1. Purpose & how to use

- **Read this before** creating or restyling any GUI, model, prop, sign, VFX, or scene, and before
  writing any Meshy / Creator-Store sourcing prompt.
- **Match it exactly.** New work should look like it was made by the same hand. If a value you need is
  missing, **ask via the wizard** — don't invent brand values.
- **Relationship to other skills:** this guide is the umbrella. Engine *how-to* lives in `roblox-ui`,
  `roblox-vfx`, `roblox-audio`, `roblox-terrain`, etc. Detailed UI component specs live in §6 here
  and will later become Jungle's GUI-design skill.
- **Every asset passes the world test (§12):** *"Could this realistically exist in a lost jungle
  expedition outpost?"* If no → redesign.

## 2. Design pillars / principles

The identity in words. Every decision is checked against these.

1. **Stylized expedition, not sim, not cartoon.** The target mix is **70% stylized Roblox / 20%
   cinematic adventure / 10% realistic detail.** Adventurous, colorful, slightly mysterious, fun.
2. **Readable at a glance.** Chunky, slightly-exaggerated proportions; every gameplay object has a
   recognizable silhouette from a distance. Never tiny/thin/fiddly.
3. **Everything is weathered & handmade.** Worn, sun-damaged, repaired, improvised. Nothing clean,
   glossy, modern, or perfectly symmetrical.
4. **Warm & inviting.** Warm late-afternoon light; the playable center is bright, the jungle edges
   darken — light guides the player.
5. **Environmental storytelling.** Props explain a place (mechanic bay = engine/tools/oil). Nothing
   is placed randomly.
6. **Mobile-first, performant & quiet.** Scale-based UI, thumb-sized targets, and the perf budget in
   §8/§10 are hard constraints — the cinematic look must still ship on a phone. **In-game the screen
   stays uncluttered**: only mandatory info (health, coins, fuel, ammo) is persistent; everything else
   is closable/collapsible (§6.11).
7. **One coherent world.** Lobby (jungle airfield) and gameplay (jungle river) read as the same
   expedition. Consistency over novelty.
8. **Juicy — every action gives feedback.** This is an **audio-rich, VFX-rich** game. **Every
   meaningful action has a sound** (shoot, reload, melee, hit, enemy attack, engine, docking, UI) and
   the world is alive with **particles/emitters** (water splash when shots hit water, boat wake &
   side waves, engine smoke, muzzle flash, impacts, dust). Feedback is immediate, layered, and
   satisfying — but always within the mobile-perf budget (§8/§10): pooled, capped, distance-LOD'd,
   and culled off-screen. Juice, not noise.

## 3. Art direction

- **Style:** *Stylized Tropical Jungle Expedition Adventure* — Vietnam-era tropical jungle, old
  jungle airfield, military expedition outpost, weathered docks, old propeller aircraft, riverboats,
  jungle ruins, improvised camps.
- **Fidelity:** *stylized, not low-poly.* Detailed meshes + weathered materials, but shapes stay
  **chunky and readable** (see `jungle_example.png`). Avoid both photoreal PBR **and** flat
  low-poly cartoon.
- **Proportions:** slightly exaggerated so objects read from far away. Thicker beams, larger roofs,
  big signs/crates/barrels, chunky machinery, wide stairs, large doorways.
- **Detail density (three tiers — never let small detail overpower gameplay objects):**
  - **L1 Landmark** — aircraft, boat, shops, tower. Big, unmistakable.
  - **L2 Support** — crates, barrels, tables, machinery.
  - **L3 Detail** — small plants, tools, ropes, boxes, small rocks.
- **Vegetation in clusters,** not scattered singletons. Frame the play area; don't bury it:
  `DENSE JUNGLE → sparse transition → props/vegetation → sandy playable area (readable center)`.

## 4. Color palette

All colors as hex + `Color3.fromRGB()`. Use several *slightly different* greens for vegetation — no
single flat green, no neon.

### Jungle (vegetation, canopy, shaded ground)
| Name | Hex | Color3 |
|---|---|---|
| Dark Jungle Green | `#1B341C` | `Color3.fromRGB(27, 52, 28)` |
| Main Jungle Green | `#31552B` | `Color3.fromRGB(49, 85, 43)` |
| Palm Leaf Green | `#47713A` | `Color3.fromRGB(71, 113, 58)` |
| Light Tropical Green | `#6F8E45` | `Color3.fromRGB(111, 142, 69)` |
| Moss Green | `#617044` | `Color3.fromRGB(97, 112, 68)` |

### Sand / Dirt / Airfield (never flat-colored — mix sand, dirt, mud, grass patches, stones, tracks)
| Name | Hex | Color3 |
|---|---|---|
| Main Sand | `#C8A36A` | `Color3.fromRGB(200, 163, 106)` |
| Light Sand | `#D4B77D` | `Color3.fromRGB(212, 183, 125)` |
| Dark Sand / Dirt | `#8A6945` | `Color3.fromRGB(138, 105, 69)` |
| Mud / Earth | `#6A4F32` | `Color3.fromRGB(106, 79, 50)` |
| Dust | `#B89160` | `Color3.fromRGB(184, 145, 96)` |

### Wood (worn, sun-damaged, dirty — varied plank sizes, slightly irregular)
| Name | Hex | Color3 |
|---|---|---|
| Main Weathered Wood | `#72502D` | `Color3.fromRGB(114, 80, 45)` |
| Dark Wood | `#4C3725` | `Color3.fromRGB(76, 55, 37)` |
| Light Weathered Wood | `#967044` | `Color3.fromRGB(150, 112, 68)` |
| Old Wooden Planks | `#806142` | `Color3.fromRGB(128, 97, 66)` |

### Military / Metal (aircraft, boats, fuel drums, crates, machinery, towers — faded, never glossy)
| Name | Hex | Color3 |
|---|---|---|
| Primary Military Olive | `#59613B` | `Color3.fromRGB(89, 97, 59)` |
| Dark Olive | `#3F4930` | `Color3.fromRGB(63, 73, 48)` |
| Faded Army Green | `#737750` | `Color3.fromRGB(115, 119, 80)` |
| Weathered Metal | `#4E5246` | `Color3.fromRGB(78, 82, 70)` |
| Dark Metal | `#353A35` | `Color3.fromRGB(53, 58, 53)` |

### Water (saturated turquoise-blue jungle river — NOT tropical-beach bright blue)
| Name | Hex | Color3 |
|---|---|---|
| Main Tropical River | `#247786` | `Color3.fromRGB(36, 119, 134)` |
| Deep Water | `#195D68` | `Color3.fromRGB(25, 93, 104)` |
| Shallow Water | `#3B9291` | `Color3.fromRGB(59, 146, 145)` |
| Foam | `#D6E2D2` | `Color3.fromRGB(214, 226, 210)` |

### Accents (used sparingly — an accent means *something important*)
| Name | Hex | Color3 | Meaning |
|---|---|---|---|
| Gold | `#D69B22` | `Color3.fromRGB(214, 155, 34)` | Major progression / gold-tier |
| Green | `#4B7A2B` | `Color3.fromRGB(75, 122, 43)` | Boat / mechanical progression · primary buttons · "good" |
| Blue | `#356B9A` | `Color3.fromRGB(53, 107, 154)` | Utilities / smaller skills · secondary buttons |
| Red | `#A84B3C` | `Color3.fromRGB(168, 75, 60)` | Danger / cancel / destructive |
| Yellow | `#D5A12B` | `Color3.fromRGB(213, 161, 43)` | Warning / highlight |
| Cream (text) | `#F3E6C2` | `Color3.fromRGB(243, 230, 194)` | Primary text (never pure white) |
| Dark UI Background | `#24352D` | `Color3.fromRGB(36, 53, 45)` | Panel fill (green-tinted) |
| Dark Navy UI | `#243542` | `Color3.fromRGB(36, 53, 66)` | Alt panel fill / cooler surfaces |

**Party colors** (matchmaking pads — always distinct & never hidden): Blue, Red, Green, Yellow (use
the accent values above).

**Rules:** all colors via `Color3.fromRGB()`; ground/vegetation/wood always use a *mix*, never one
flat tone; accents only where meaningful; text is cream `#F3E6C2` with a dark stroke, not white.

## 5. Typography

Roblox's `FontFace` library covers all of these — no uploads needed; pick them in Studio's font
picker. Roles:

| Role | Font | Notes |
|---|---|---|
| **UI / body / buttons** | **Builder Sans** — `BuilderSansExtraBold` (values/headings), `BuilderSansBold` (buttons/labels), `BuilderSansMedium` (body) | The workhorse. Clean, bold, readable. Use for **all functional UI**. |
| **Headings / poster** | **Oswald** _(alt: Bebas Neue)_ | Condensed, all-caps military-poster punch for big titles (`BOAT UPGRADES`). |
| **World signs (sparingly)** | **Special Elite** | Weathered typewriter — Vietnam-era field-document feel for shop/location signs. |
| **Improvised labels** | **Permanent Marker** | Hand-painted crate/barrel/warning labels — the "handmade camp" touch. |
| **HUD numbers (optional)** | **Roboto Mono** | Instrument/dogtag readout feel for stat values. |

- **Physical/decorative fonts (Oswald poster · Special Elite · Permanent Marker) are for the 3D world
  and hero headings only** — never for small UI text, which stays Builder Sans.
- **Case:** major headings **ALL CAPS** (`BOAT UPGRADES`, `SKILLS`, `PLAY`, `ENGINE`); descriptions
  normal capitalization (`Increase maximum boat speed.`).
- **Color & legibility:** cream `#F3E6C2`; dark stroke/shadow behind important text (`UIStroke`,
  color near `#1B341C`/black, `Transparency` 0–0.4). Never pure white.
- **Size hierarchy (adopted standard — mobile-first):** use `TextScaled = true` inside sized
  containers, capped with a `UITextSizeConstraint`. Reference desktop-equivalent sizes / min:

| Role | Size (cap) | Min (mobile) | Font |
|---|---|---|---|
| Display / hero | 48–64 | 28 | ExtraBold |
| H1 panel / section title (ALL CAPS) | 28–32 | 20 | ExtraBold |
| H2 sub-header | 22–24 | 18 | Bold |
| Button label (ALL CAPS) | 20–24 | 16 | Bold |
| Body | 16–18 | 14 | Medium/Bold |
| Caption / small | 13–14 | 12 | Bold |

## 6. UI / HUD style

**Principle:** the UI matches the physical world — military equipment, expedition crates, metal
plates, wood signs, maps. **No futuristic glass, no heavy gradients.** (Reference: `GUI_PATTERN.png`.)

### 6.1 Panels
- Fill: Dark UI Background `#24352D` (or Dark Navy `#243542` for cooler contexts).
- Border: thick, wood/metal-toned — Old Wooden Planks `#806142` (`UIStroke`, thickness ~2–3).
- Corners: `UICorner` ~8–12 px (rounded rectangle). Small bevel via a subtle inner `UIStroke` or
  gradient; optional faint texture overlay. Title bar strip at top, `X` close button top-right.

### 6.2 Buttons (four variants — all: cream text, dark stroke, thick darker border, rounded, slight bevel)
| Variant | Fill | Use |
|---|---|---|
| **Primary** | Green `#4B7A2B` | Confirm / Play / Buy / positive |
| **Secondary** | Blue `#356B9A` | Neutral / utility / alternate |
| **Gold** | Gold `#D69B22` | Premium / major progression |
| **Danger** | Red `#A84B3C` | Cancel / destructive |

States: **normal** → **hover** (~+8% lightness) → **pressed** (~−10% + slight scale-down tween) →
**disabled** (desaturated ~50%, `Transparency` up). Use consistent `TweenInfo` (see §8 / `roblox-ui`).

### 6.3 Top HUD bar
- **Left cluster:** hamburger menu icon · circular avatar (framed) · `PLAYERNAME` + `LEVEL nn` +
  **XP progress bar** (green fill, dark track, rounded).
- **Right cluster:** **currency chips** — each a dark rounded chip with border: `[icon]  value`, one
  per real currency (Gold / Salvage / River Score per `GAME.md`), followed by a `+` add button.
  _(The mockup's Gold/Cash/Gems chips illustrate **layout + color** only — do not add new currencies.)_

### 6.4 Main-menu & bottom bar
- **Main-menu buttons:** large, labeled, icon + ALL-CAPS text (`PLAY` primary-green, `BOAT UPGRADES`,
  `SKILLS` gold-star, `PARTY` blue, `INVENTORY`).
- **Bottom bar:** compact icon buttons — Shop · Inventory · Skills · Quests · Settings.

### 6.5 Shop / upgrade popup
Title bar + `X`; item preview showing **before → (arrow) → after**; stat list with **`+%` deltas in
green** (`SPEED +25%`); cost row (currency icon + value); **BUY** primary-green button.

### 6.6 Buy / confirm popups
Title (`BUY ITEM` / `CONFIRM PURCHASE`); item image; cost (currency icons + values); Robux price on a
green button (`R$ 199`); **CANCEL** (red) + **BUY** (green) pair.

### 6.7 Notifications (toast)
Dark panel, green accent edge, item icon + bold ALL-CAPS title (`BOAT UPGRADED!`) + normal-case
subtitle (`Engine Level 2`). Slide-in/out tween.

### 6.8 Form elements
- **Checkbox:** square, green check when on. **Toggle:** pill, green when on.
- **Slider:** dark track, **green fill**, cream round handle.
- **Progress bar:** dark track, green fill, `UICorner` rounded, optional value label (cream + stroke).

### 6.9 Party pads
Circular raised pads, wood+metal outer ring, **colored center (Blue / Red / Green / Yellow)**, large
player-group icon, glowing ring + small edge lights. Always large, always unobstructed.

### 6.10 Mobile-first UI rules (hard)
- Positions/sizes in **`UDim2` scale**, not fixed pixels; use `UIScale` /
  `UIAspectRatioConstraint` / `UISizeConstraint`; be **safe-area aware**.
- Tap targets sized for thumbs (min ~44×44 px equiv); `TextScaled` + `UITextSizeConstraint` for
  readable, capped text. No keyboard-only actions.
- **Test every GUI on a phone** (Studio Device Emulator + a real device) before it's done — nothing
  ships that isn't comfortable and readable on a small touchscreen.

### 6.11 HUD minimalism & panel discipline (hard — the "no noise" rule)

The screen must stay **clean and uncluttered while playing.** The player fights the river, not the UI.

- **While playing, show ONLY mandatory at-a-glance info:** health, currencies (coins), fuel, ammo,
  and a minimal role/objective indicator. Nothing else is persistently on screen. No noise.
- **Everything non-essential is opened on demand and is closable / collapsible** — daily tasks, shop,
  skills, quests, inventory, leaderboard, settings, etc. A panel like **Daily Tasks must default to a
  small collapsed chip/tab** during play and expand only when tapped.
- **Every panel has an obvious way out:** a visible `X` (top-right) **and** tap-outside-to-close (and
  a back/close button reachable by thumb on mobile). No dead-end panels.
- **Panels never crowd each other or the core HUD:** opening a full panel dims/closes other open
  panels; a panel must **never cover** health/fuel/ammo. Prefer one primary panel open at a time.
- **Notifications are transient** — toasts auto-dismiss and never block input or stack up.
- Collapsed/expanded state should be obvious (clear collapse/expand affordance) and remembered
  sensibly within a session.

## 7. Iconography

- **Style:** simple, bold, immediately readable, **slightly 3D / embossed**. One consistent set
  across the whole game.
- **Defined vocabulary:** Gear = Engine · Shield = Hull · Fuel pump = Fuel · Crate = Storage ·
  Crossed tools = Equipment · Star = Major (Gold) skill · Wrench = Utility (small) skill ·
  Player group = Party.
- **Concrete icon assets are OUT of scope for this guide.** This section defines the icon *style and
  vocabulary* only. The actual **asset IDs** (and what we need / how many / sourcing) are handled in a
  **separate assets job** and recorded in the asset registry (per `roblox-assets`) — not here.
- **Sourcing (when the assets job runs):** Flaticon (per `GROUND-RULES §4`) → upload → record IDs in
  the registry; or Creator Store search; or Meshy text-to-image. Whatever the source, every icon must
  match the style above and one consistent set.

## 8. Lighting & VFX

**Day (default): warm cinematic jungle.**
- Late-afternoon / warm daylight; slightly warm sun; **soft but visible** shadows.
- Use ambient occlusion, soft directional shadows, **subtle** atmospheric haze, cooler shaded jungle
  vs. warmer open airfield. **Central play areas brighter; jungle edges darker** (guides the player).
- Suggested starting point: `Lighting.Technology = Future`; warm `Ambient`/`OutdoorAmbient`; warm
  directional sun (`ClockTime` ~15–16); subtle `Atmosphere` (low `Density`, warm `Color`/`Decay`);
  **light** `Bloom`; a gentle warm `ColorCorrection`. Tune in Studio, verify by screenshot.
- **Avoid:** extreme orange sunset, pitch-black jungle, photorealistic lighting, heavy bloom
  everywhere.

**Night: warm practical pools of light.**
- Lanterns warm amber; torches warm orange; mechanical equipment small blue/green indicator lights;
  shops warm internal glow. **Small pools of light — do NOT light the whole jungle evenly.**

### VFX — the world is alive (particles & emitters everywhere)

Last River is **VFX-rich**: `ParticleEmitter`, `Beam`, and `Trail` bring the river, boat, and combat
to life. Every impactful action emits something. Stylized shapes, warm/earthy tints, readable — never
a muddy screen of soup.

**Starter emitter vocabulary** _(build these as reusable, pooled templates):_
- **Boat:** engine **smoke/exhaust** (scales with speed & engine tier), **bow wake + side waves**
  (Beam/Trail foam along the hull), **water spray** off the bow in rapids, damage smoke/**fire** when
  the hull is low, sparks on metal hits.
- **Water interaction:** **splash particles when shots (or anything) hit water**, ripples/rings,
  wake trails behind swimming animals, waterfall mist, dock-water lapping.
- **Combat:** muzzle flash + **tracer beam**, bullet **impact** bursts (water / wood / metal / flesh
  variants), shell casings, melee swing arc (Trail), hit sparks, enemy hit/blood puff, death poof.
- **Ambient:** fireflies/motes, drifting fog wisps, dust on land paths, lantern/torch flicker, embers
  from campfires, falling leaves.
- **UI/feedback:** pickup sparkle, upgrade/level-up burst, coin/loot shimmer.

**VFX rules:** one consistent stylized look; tint to the §4 palette; **pool and reuse** emitters
(never `Instance.new` per shot in a loop); `Rate`/`Lifetime` tuned so it reads without flooding;
**LOD by distance** and **cull off-screen**; heaviest effects (fire, big splashes) are budget-capped.

**Mobile perf budget (hard):** prefer baked/static lighting where possible; cap simultaneous dynamic
`PointLight`/`SpotLight` count; cap total concurrent particles and per-effect rates; pool + cull;
test `Future` lighting and a busy combat scene on a **mid phone** before committing (see
`roblox-optimization` and `roblox-vfx`).

## 9. Audio direction

**Principle — every action has a sound.** This is an **audio-rich** game: nothing meaningful happens
silently. Shooting, reloading, empty clip, melee swing & hit, enemy attack/bite/hiss, taking damage,
engine start/idle/throttle, docking, refuel/repair, pickups, purchases, UI taps, level-up — each
fires a sound. Sound is the primary feedback layer paired with the VFX in §8.

- **Tone:** adventurous, tense-but-fun jungle expedition. Diesel/engine grit, jungle ambience,
  animal calls, gunfire, mechanical clanks.
- **Existing assets** (`assets/Objects/…`): boat engine loop / start / on-fire / destroyed, metal
  hits; gun shot / reload / empty clip; alligator hiss, monster bite.
- **Starter SFX map** _(what needs a sound — sourced/recorded in the assets job):_
  - **Weapons:** shot, reload, empty clip, melee swing, melee hit, bullet impact (water/wood/metal/flesh).
  - **Enemies:** aggro/hiss/growl, attack/bite, hurt, death; water thrash for river animals.
  - **Boat:** engine start / idle loop / throttle-up, collision/hit, hull damage groan, on-fire,
    destroyed, horn; **water splash/spray**, docking bump, rope tie/untie.
  - **Resources/UI:** pickup (fuel/ammo/metal/loot), refuel pour, repair, purchase/confirm, error,
    button tap, panel open/close, quest/objective, level-up, revive.
  - **Ambient:** jungle day/night beds, water/river flow, waterfall, wind, campfire, insects/birds.
- **3D/spatial:** engine, animal growls, gunfire, splashes as positioned `AudioEmitter`/`Sound` in
  the world with rolloff (see `roblox-audio`). Mix so nearby/important cues cut through; avoid an
  overlapping wall of sound (cap concurrent one-shots, prioritize).
- **Music:** adventurous, layered/adaptive — calm travel → tense combat → night dread; crossfade.
- **Sourcing:** Pixabay (per `GROUND-RULES §4`); record every SFX/music track in the asset registry
  (handled in the assets job).

## 10. Materials & textures

- **Style:** slightly stylized, **readable at normal camera distance** — visible detail, but *not*
  high-frequency photoreal PBR.
- **Palette of Roblox materials:** Wood / WoodPlanks, Metal, CorrodedMetal, Sand, Ground, Rock,
  Grass, Fabric-like (tarps/canvas). Use **MaterialVariants** for important repeated weathered
  surfaces (worn wood, corroded metal, canvas).
- **Weathering is mandatory:** wood worn/sun-damaged/dirty with varied plank sizes; metal faded, not
  glossy; roofs = corrugated metal / old boards / canvas / tarps / occasional thatch (dark olive,
  weathered brown, faded blue, rusty — never bright modern).
- **Meshy / Creator-Store assets** must be recolored/retextured to this palette and re-checked
  against the world test (§12) before use (per `roblox-assets`).
- **Mobile budget:** moderate texture sizes; reuse MaterialVariants over unique textures; keep tri
  counts sensible for streamed river content (see `roblox-optimization`).

## 11. Naming & conventions

- **Colors** always via `Color3.fromRGB()` (values from §4). No stray hex or `BrickColor`.
- **GUI instances:** `*Frame` (structural), `*Container` (layout wrapper), `*Button`, `*Icon`
  (interactive image), `*Image` (display), `*Text`/`*Label`, `*Bar` (progress). `BorderSizePixel = 0`;
  set `Parent` last. (Aligns with the shared GUI conventions in Defender's `roblox-gui`.)
- **Models/assets:** descriptive, tier-suffixed where progression is visible (`Boat_Engine_L1/L2/L3`,
  `Shop_Gold`, `Sign_BoatUpgrades`). Register every sourced/created asset (per `roblox-assets`).
- **Signs:** dark wood/metal backing, thick border, large bold text, small icon, worn surface —
  color-coded to function (Gold shop = gold border + star; Boat Upgrades = dark-green bg + light-green
  border + gear; Small Skill Shop = dark-blue bg + blue border + wrench). Readable from far away.

## 12. Rules (do / don't)

**Always do**
- Chunky, readable silhouettes; slightly exaggerated proportions.
- Weathered, handmade, repaired, improvised look on everything.
- Mix ground/vegetation/wood tones; several greens; warm guiding light.
- Cluster vegetation; frame (don't bury) play areas; keep the center readable.
- Accents only where they mean something; cream text with dark stroke.
- Mobile-first scale UI + perf budget on every scene; test every GUI on a phone.
- Keep the in-game HUD to mandatory items only (health/coins/fuel/ammo); every other panel is
  closable **and** collapsible, and heavy panels (e.g. daily tasks) default collapsed during play.
- Give every panel an obvious close (`X` + tap-outside); one primary panel open at a time.
- **Give every meaningful action a sound** (shoot/reload/melee/hit/enemy/engine/dock/pickup/UI) and
  matching VFX; use pooled, palette-tinted, distance-LOD'd, budget-capped emitters.
- **World test:** *"Could this exist in a lost jungle expedition outpost?"* — if no, redesign.

**Never do**
- Sci-fi / cyberpunk / holographic / futuristic-glass UI.
- Modern luxury buildings, clean/glossy surfaces, perfect modern geometry, perfect symmetry.
- Photorealistic assets **or** extremely low-poly cartoon assets (we're *between* — detailed-stylized).
- Neon colors everywhere; accents everywhere; heavy gradients/bloom.
- Randomly scattered props; tiny unreadable objects; thin beams/architecture.
- Huge empty flat terrain; vegetation so dense it clogs gameplay zones.
- Pixel-fixed UI that breaks on phones; keyboard-only actions.
- Crowd the play screen with panels/badges; a panel that covers the core HUD; a panel with no obvious
  close; a heavy panel (daily tasks, shop) left expanded during active play.

## 13. References (north-star)

- **Gameplay north-star:** *Dead Rails* (co-op shared-vehicle survival loop) — see `GAME.md`. We
  borrow the loop & fair economy; we differentiate with the **jungle river** theme and this art
  direction.
- **Visual references:** the images in `assets/Images/` (`jungle_example.png`, `GUI_PATTERN.png`,
  `MapIdea.png`, `boat_ideas.png`, `LastRiverLogo.png`) and the full brief in `DesignConcept.txt`.
- **Map composition rule:** every major location = **Landmark → Path → Secondary area**. Players
  should read the map *without a minimap*: Spawn = painted airfield star; Party = aircraft; Boat
  Upgrades = boat + dock; Gold skills = gold-star building; Small skills = blue workshop. Paths curve
  naturally (lighter sand, walkways, lanterns, flags) — never straight/symmetrical.

## 14. Quality checklist

- [ ] Reads as *stylized jungle expedition* — detailed-stylized, not photoreal, not flat low-poly.
- [ ] Chunky, readable silhouette; slightly exaggerated; recognizable from a distance.
- [ ] Weathered/handmade; no clean/glossy/modern/symmetrical surfaces.
- [ ] Colors from §4 via `Color3.fromRGB()`; tones mixed, not flat; no neon.
- [ ] Accents only where meaningful; text cream `#F3E6C2` + dark stroke (not white).
- [ ] Typography: Builder Sans (Bold/ExtraBold); ALL-CAPS headings, normal-case body; sign font only on physical signs.
- [ ] UI matches the world (military/crate/wood/metal), rounded + thick border + slight bevel; no glass/gradients.
- [ ] Mobile-first: `UDim2` scale, safe-area, thumb-sized targets, `TextScaled` + size constraint; tested on a phone.
- [ ] In-game HUD shows only mandatory info (health/coins/fuel/ammo); no crowding/noise.
- [ ] Every panel is closable (`X` + tap-outside) and collapsible; heavy panels default collapsed in play; never covers core HUD.
- [ ] Materials from §10 (+ MaterialVariants for repeats); readable, not high-frequency PBR.
- [ ] Lighting warm/cinematic, play area brighter than jungle; night = warm pools of light.
- [ ] Every meaningful action has a sound (weapon/enemy/boat/resource/UI); cues are 3D & mixed to cut through.
- [ ] Actions/impacts emit VFX (boat wake/smoke, water splash on hits, muzzle/impacts); emitters pooled, tinted, LOD'd.
- [ ] Perf budget respected (dynamic lights + concurrent particles/sounds capped, culled, tri/texture budget) — verify on mobile.
- [ ] Passes the world test (§12); registered in the asset registry if sourced/created.
