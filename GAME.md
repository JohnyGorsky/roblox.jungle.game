# Last River — game description

*(Working title: **Last River**. Dev/repo name stays `roblox.jungle`.)*

> **v1.0 — concept LOCKED** (Job 001, 2026-07-18). Core concept, market position, and core mechanics
> agreed. Remaining detail is tracked in "Open questions" + "Not yet covered" below and resolved as
> each build phase comes up. High-level vision lives here; the production roadmap + object inventory
> live in [Jobs/001/implementation-plan.md](Jobs/001/implementation-plan.md); queued phases are in
> [Planned/](Planned/).

## One-line pitch

A co-op survival game (~1–6 players): your plane crashes in the jungle, so you take a boat down a
dangerous river — crocodile- and predator-infested — each player working a role, scavenging fuel and
ammo at docks, pushing through escalating zones to reach the end.

## Genre & feel

Co-op **river-run survival / action**. Tense but fun; escalating difficulty; short-to-medium sessions
built around "ride → reach a dock → scavenge → ride further." Stylized **low-poly** art direction.

## Platform & input — **mobile-first** (hard requirement)

The game **must be mobile-ready.** Every control and every GUI is designed for touch first, then
scales up to PC/console:
- **GUI uses scale, not fixed pixels** — `UDim2` scale + `UIAspectRatioConstraint`/`UIScale`, safe-area
  aware; readable and tappable on a phone. No pixel-perfect layouts that break on small screens.
- **Touch controls** — on-screen buttons/joystick for driving, shooting, catching, interacting; tap
  targets sized for thumbs; no keyboard-only actions. PC keys/mouse map onto the same actions.
- **Performance** budget suits mobile (low-poly, sensible draw distance, streaming) — see P8.
- This is a standing constraint on **every** GUI/role/interaction phase, not a one-time task.

## Design reference — Dead Rails (north star)

Our closest comparable is the hit Roblox co-op game **Dead Rails**: a team rides a **train** through
an undead frontier, fuels/defends it, stops at towns to scavenge & buy, earns money, and races to
reach the end. It's a **proven, popular template** — we're deliberately building the same
shared-vehicle co-op survival loop, reskinned and differentiated:

| Dead Rails | Jungle (ours) |
|---|---|
| Train on **rails** (linear track) | **Boat on a river** (river = the "track"; steer within it) |
| Wild-West / **undead** | **Jungle** / crocodiles & predators |
| Coal/fuel to move | **Gasoline** at docks |
| Defend the train | Defend the **boat** (+ players, revive) |
| Stop at **towns** to loot/buy | Stop at **docks** to scavenge/refuel |

**Decision — the river winds; the driver actively steers.** The current funnels you downstream
(semi-on-rails *direction*, so it stays authorable and easy to balance), but the river is **curved,
never a straight lane** — the driver must steer around bends, rocks, and rapids, so the role takes
real skill. Not a straight corridor, not full open-water free-roam.

**Boat handling — physics, not teleport.** The boat moves via **real Roblox physics forces** (thrust +
turning applied as constraints/forces), so it has **momentum, acceleration, and drift** — it feels like
a real engine-driven boat, not "hold W and slide." Turning through the bends should feel weighty and
satisfying. This is a core feel pillar (prototyped in P1).

## Market & competition (why this can win)

Landscape scan (Jul 2026):
- **Land "Dead Rails-likes" are saturated** — Dead Roads (~40M visits), DEADFRONT (~15M), plus
  anime/magic/pets reskins; Dead Rails still leads but is well off its 2025 peak.
- **The water/river cell is wide open.** The closest analog, **Dead Sails** ("Dead Rails but a boat,"
  sea/pirate, 4-player) peaked ~22K concurrent but **cratered to ~50 and looks abandoned** — no healthy
  incumbent to beat.
- **No jungle-themed river-boat game exists.** That exact cell is unoccupied — our clearest opening.

**How we win (attacking the incumbents' weak spots):**
1. **Own the jungle river** — canopy ambushes, rapids, caiman/piranha, fog, hostile tribes, temple
   ruins: things a desert-train or open-ocean game structurally can't do.
2. **River-specific mechanics** — current, branching tributaries (risk/reward), waterfalls/portage,
   rising water, log/dam blockages. Fresh vs "drive straight across flat terrain."
3. **Crisp interdependent roles** — Dead Sails' thin loop failed to retain; make coordination the fun.
4. **Mobile-first** — the genre spreads via mobile/short-form; boat steering suits touch (our pillar).
5. **Live-service + progression** — clones die from *abandonment*; a steady cadence of new stretches,
   events, boats & upgrades is the moat.

> _Cautionary tale:_ Dead Sails proves theme alone isn't enough — a thin loop + no updates kills
> retention. Depth of roles + live ops is where we must not cut corners.

## Structure (two places)

1. **Lobby place** — players gather and **team up (~1–6)**. When ready, the team is **teleported to a
   private reserved gameplay server**.
2. **Gameplay place** — the jungle river journey.

## The run (core loop)

1. **Crash-in** — the plane crashes; players start at a small landing area, regroup, grab first
   supplies, and board the boat.
2. **Ride the river** — the boat travels downriver through **crocodile- and predator-packed** water.
   Players work **roles** (below) to survive.
3. **Reach a dock** — you **can't ride endlessly**: fuel drains, so you must reach the next
   **designated dock** before it runs out, disembark, and **scavenge gasoline, ammo, and items** —
   under threat.
4. **Escalate** — each zone downriver is **harder** (more/tougher animals, tighter resources), and a
   **day/night cycle** makes night sections more dangerous.
5. **Reach the end** — the campaign is a **finite sequence of zones** to a fixed END. (An **endless
   mode** comes in a later version.)

> **Core tension (borrowed from Dead Rails):** the boat is **safest while moving** — attacks intensify
> when you're **stopped** (at a dock, or stranded out of fuel). Since **fuel forces stops**, fuel
> management becomes the central risk/reward decision of every run. Every stop is a deliberate gamble.

## Day / night cycle (flips where it's safe — the run's heartbeat)

- **Day** — the **river is the safe lane**; travel and make progress. Going ashore to scavenge is the
  daytime risk (core tension: stopping = exposure).
- **Night** — the **water turns deadly** (nocturnal predators, low visibility). Race to reach a **dock
  before dark and hold out / fortify on land until dawn**, or gamble on **pushing through** with a
  **searchlight** upgrade. Night is the "hold out and defend" set-piece.

Rhythm: **travel + scavenge by day, survive the night.** Makes the **searchlight** a meaningful upgrade
and turns "reach the next dock before nightfall" into constant fuel/time pressure.

## Player roles (swappable stations)

Players move freely between **stations** on the boat during the run. Manning a station **as your role
gives an efficiency bonus** — a reason to divide the crew, not just everyone doing everything
_(role model refined 2026-07-18)_:

- **Driver** _(one)_ — steers + controls speed; avoids hazards; docks. **Can't shoot while driving.**
- **Gunner** _(one)_ — mans the **mounted gun** (see Weapons); strong, ammo-limited.
- **Repair** _(one)_ — mends the hull at the **repair station**; a dedicated repairer **repairs faster**.
- **Refuel / engineer** _(one)_ — feeds the **fuel station**; a dedicated refueller **refuels faster AND
  the boat burns less fuel** while they man it.
- **Helpers / fighters** _(the rest)_ — defend the deck (gun/sword), fight boarding threats, scavenge,
  haul loot, revive the downed. The versatile bulk of the crew.

**Design principle:** the four specialist seats (drive / gun / repair / refuel) each grant a **bonus at
their station**; everyone else is a flexible fighter. Roles are **swappable mid-run** (swap who drives /
guns / repairs as the situation shifts). Target ~4–6 core crew (see below). _(Bonuses are a P2/role-pass
implementation; the stations themselves already exist.)_

## Weapons & combat _(added 2026-07-18)_

- **Melee (sword) — the default.** A player with no gun carries a **sword**: hit enemies at **very short
  range** only. Always available (your fallback); weak vs. a swarm — you want a gun.
- **Guns are earned, not given.** Players **obtain firearms (pistols, etc.) at camps** during raids.
  Guns fire at range and **consume ammo** (looted). Handheld free-aim (tap/click a target).
- **Mounted gun (gunner station) — the boat's heavy defence.** A **turret the gunner SITS at**:
  - **Limited rotation** — you rotate within an arc (sit, traverse, fire), not a full 360°.
  - **Own aiming camera** — sitting at the gun switches to a gunner view for better aim.
  - **Much stronger** than a handheld gun (the boat's real firepower).
  - **Ammo-fed** — draws from the boat's ammo cargo; loot ammo to keep it firing.
- **Enemy health bars** — a floating HP bar over each enemy so you can read how close it is to dying.
- Damage is **server-authoritative** (range, ammo, who-can-shoot all validated). Roles gate weapons:
  the driver can't shoot; the gunner mans the turret; deck players use gun/sword.

**Player count / scaling _(OPEN)_.** Baseline 1–4, but we may support **more players**. Options if we do:
- **Limited stations + unlimited deck defenders** — only a few control-stations (driver, special guns),
  but *any* extra player rides the deck and fights with a **personal weapon** + helps scavenge. Simple,
  everyone's useful. _(leaning)_
- **Bigger boat, more stations** — scale stations with team size (2 gunners, spotter, etc.).
- **Convoy** — multiple boats for large groups (more systems).

**Target (from market data):** the genre sweet spot is **~4–8 co-op** (Dead Rails 16-server cap but
small squads; Dead Sails 4/expedition). Plan for a **~4–6 core crew** using the *limited-stations +
deck-defenders* model so extras always contribute; larger lobbies/convoy are a later mode.

## The boat — modular & upgradeable (start small → full boat)

**Core progression fantasy (added 2026-07-18):** you **start with a small, basic boat** — a bare hull,
one weak motor, a single seat — and **build it up** into a full, bristling river craft. Upgrades are
**physical, visible modules** bolted onto the boat, so progress is something you *see and feel*, not
just a hidden stat bump:

- **Motors** — add / upgrade engines for more speed & thrust (scales the boat's `THRUST`). More motors
  = faster, and helps clear bigger ramps/jumps.
- **Chairs / stations** — add seats to crew more players and unlock more roles (gunner, spotter…); a
  bigger boat carries a bigger team. (Ties into the swappable-stations model above.)
- **Ramps / hull shape** — parts that let the boat **launch off jumps** and handle rapids better.
- **Armor** — plating that raises **boat HP** and shrugs off animal/hazard damage.
- Plus **guns/mounts**, a **searchlight** (night), **fuel-tank capacity**, **storage** — each a visible
  add-on.

Start = small & humble; end = a full custom boat. The run should feel like it **grows with you**, and
this is the meta economy's main sink. Ties into persistent **boat upgrades** bought with meta currency
in the lobby, and possibly **in-run** module pickups/installs; modular parts also feed boat **variety &
customization** (skins/loadouts). This supersedes the thin "boat variety" backlog line.

_OPEN: which modules are **meta/persistent** (lobby, permanent) vs **in-run** (installed mid-run, reset
after); whether the hull physically scales in size; per-module art (P9, Meshy)._

## World & environment

- **Procedurally-generated voxel terrain (seeded).** The river + banks are **generated by code** as
  Roblox voxel terrain from a seeded winding centerline — chosen in the P1 spike over modular segments
  (which showed tiling gaps at bends) and over hand-sculpting (impractical for a long/random river).
  Organic natural look; a seed reproduces a river (random per run, or a shared "daily" seed for fair
  leaderboards). Built with the `roblox-terrain` verify discipline and **streamed** for the long river
  (generate ahead of the boat, cull behind).
- **A vast jungle; mountains far away.** The playable space is **dense jungle** — trees, bushes,
  foliage — lining the river corridor. The big **rock/snow mountains sit far in the distance** as a
  backdrop (reachable/climbable, but *far*), so the world reads as **vast and open**. You travel the
  river through the jungle; the peaks loom on the horizon — scale and atmosphere, not near walls.
- **Foliage.** Trees/bushes/plants are **scattered procedurally** along the jungle floor (denser near
  the banks), greybox blocks for now → low-poly/Meshy models at the art pass (P9).
- **The river winds — and is WIDE.** A **curved, meandering** river (never straight), but deliberately
  **wide** — a broad channel, not a tight lane — so there's room for **obstacles to dodge** (rocks,
  logs, sandbars, wrecks) and **ramps / jumps** (natural or placed) to launch the boat over hazards or
  gaps. Occasional **narrows/rapids** are pinch-point set-pieces, but the *default* stretch is open and
  roomy. Picking a line through the obstacles and lining up a ramp is core to the driver role. Possible
  **forks** for risk/reward. (Width is a hard input to the terrain generator — see the P1 follow-up job.)
- **Currents.** The river pushes the boat **downstream along the channel**, and current **strength
  varies by section** — calm stretches vs fast **rapids** that fling you along (harder to steer, less
  fuel burn) and slow eddies. A river-specific mechanic land/ocean games can't do.
- **Waterfalls / drops.** Vertical drops as **set-piece moments** — brace, drop, keep control. (Bigger
  feature — targeted at P5, needs multi-level river.)
- **Placeholder first:** early phases greybox the terrain + river to test feel; final flora, water
  detailing, and set-pieces come in the art pass (P9).

## Docks, tying up & jungle excursions (the second core pillar)

_(Added 2026-07-18; refined with the on-foot-raid vision.)_ The river run and the **on-foot jungle raid**
are the game's **two halves**. You can't just hop off anywhere — leaving the boat is a deliberate,
gated act that only happens at docks:

**The excursion loop:**
1. **Reach a dock** (the *only* valid disembark points — seeded along the river).
2. **Tie up the boat** — a hands-on action (rope it to the dock). Only once it's **tied** can the crew
   get out. While tied, the boat sits **anchored** at the dock (safer, but still attackable — someone may
   stay to guard it + the trailer).
3. **Trek into the jungle on foot** — the shores are **dense jungle** (trees, foliage, undergrowth), and
   inland from each dock is a **procedurally generated camp** (later: villages, ruins, hunter camps).
4. **Raid it** — loot **metal / ammo / gasoline / currency**, guarded by land threats (a real fight).
5. **Haul it back**, **untie** the boat, and **drive on**.

**What this needs (terrain & world):**
- **Dense jungle along ALL shores** — the banks aren't bare grass; they're forested (trees/bushes),
  greybox now → low-poly/Meshy foliage at P9. This is a big addition to the Job #005 generator.
- **A walkable jungle pocket at each dock** — the terrain **opens inland** into a larger on-foot area
  (clearing + camp), unlike the tight travel banks. (This is the "wider terrain at landing sites" idea,
  now concretely gated behind docks.)
- **Generated camps** — seeded structures with loot + guards, inland from the dock.

**Design impact:**
- **Docks become the game's hubs**, not fuel pumps — refuel/repair *and* the raid gateway.
- Adds a whole **on-foot pillar** (walking, jungle exploration, land combat) alongside the boat pillar.
- **Core tension:** the boat/trailer sit exposed at the dock while you're inland — and at **night** the
  water's deadly, so you may *want* to be ashore then (flips the day/night calculus).

Ties into: **docks / refuel** (P4), **land threats** (P3/#009), the **trailer + resources** (haul loot
back), **modular boat**, **zones** (P5), and a **generator that grows from one river mode into river +
jungle + camp modes** (extends #005; see `Planned/`).

## Threats, stake & fail/win

- **Both the boat and the players are at stake.** Animals/hazards damage the **boat** (boat HP →
  destroyed = run over) *and* can **down players** (teammates can **revive** the downed).
- **Two threat domains — sea & land — each with a day/night rhythm** _(added 2026-07-18)_:
  - **Sea / river threats** (crocodiles, piranha, river predators) — attack the boat + players **on the
    water**; **peak at NIGHT** (the water turns deadly).
  - **Land threats** (shore predators, hostile tribes at camps/villages) — the danger of **going
    ashore**; most active by **DAY**, when you disembark to scavenge/raid.
  - Threat **strength scales with time of day** (plus distance/zone) — this is what drives the safety
    flip below. Build the threat system **category- (sea/land) and time-of-day-aware from the start.**
- **Where players should be, by time of day — the run's rhythm (remember this):**
  - **DAY → out on the water, travelling.** The river is the safe lane; land excursions are the risk.
  - **NIGHT → sheltered on land at a dock.** The water is deadly; reach a dock before dark and hold
    out / fortify until dawn, or gamble a **searchlight** push-through. (See "Day / night cycle".)
- **Win:** reach the end of the campaign. **Fail:** boat destroyed, whole crew downed, or stranded
  out of fuel. (Exact thresholds TBD.)

## Resources

- **Gasoline** — the boat's fuel. Players **scavenge fuel at docks and physically haul it back to the
  boat** to keep it running (like feeding coal to the Dead Rails train). The tank **drains as you ride**,
  so the crew must keep topping it up between/at stops — run dry and you're **stranded = swarmed**.
  This "keep feeding the boat" chore is a constant, shared crew job.
- **Metal parts / scrap** _(added 2026-07-18)_ — the boat's **repair** material. Boat HP is chipped
  away by animals/hazards; the crew **loots metal** (at docks / land excursions) and spends it to
  **repair the hull** (restore boat HP). Another reason to stop and scavenge; pairs a repair role/station
  with the driver + gunner.
- **Ammo** _(added 2026-07-18 — gates combat)_ — gunners' weapons **consume ammo**; you **loot ammo** to
  keep firing. Run out and you can't shoot back (steer/flee instead) — makes ammo a managed resource, not
  infinite. Scavenged/bought and carried back like fuel.
- The three loot resources — **gasoline (move), metal (repair), ammo (fight)** — are the core scavenge
  economy; docks/camps stock them, and hauling them back is shared crew work.
- Likely also **health/bandages** (revive — see "Threats"), and collectibles for score. _(OPEN)_

## Cargo — the towed trailer & on-boat stations

_(Added 2026-07-18.)_ Loot isn't consumed instantly — it's **stored and hauled, then used at a spot on
the boat** (like feeding the Dead Rails firebox):

- **A towed trailer** — a raft/barge **roped to the boat** (physics `RopeConstraint`) is the crew's
  **cargo hold**. Scavenged **gasoline, metal, ammo** (and loot) go INTO the trailer; it follows the
  boat, can swing/drag as part of the driving feel, and is itself a target threats can attack.
- **Carry capacity is limited** — the trailer holds only so much, forcing "what do we grab?" choices.
  Capacity is **expandable via game pass** (fair, non-P2W **convenience** — more slots, not more power)
  and/or meta upgrades. This is a primary monetization lever.
- **On-boat STATIONS** — you **take a resource from the trailer and use it at a specific station**:
  - **Fuel station** — pour gasoline in to refuel the engine.
  - **Repair station** — spend metal parts to patch the hull (restore boat HP).
  - Gunners draw **ammo** from the shared stock.
  So refuel/repair are **deliberate physical chores at a spot on the boat, under threat** — not instant.
  _(The current greybox refuels straight from the dock — a simplification of this loot → trailer →
  station flow, to be built out.)_

Ties into: **modular boat** (trailer + stations are add-ons), **resources** (gasoline/metal/ammo),
**inventory/capacity** (game-pass slots), **roles** (a hauler/engineer job), and the **dock/excursion**
scavenge loop.

## Progression & replay

- **Score & leaderboards** — distance / zones reached + performance (animals fought, items caught, crew
  survival). Global + friends boards.
- **Run objectives** — optional in-run goals (survive a night, N kills, reach the next dock fast) that
  pay bonus cash + meta currency. Cheap to author, big replay boost (Dead Rails leans on these).
- **Persistent unlocks** — meta currency (below) buys permanent **boat upgrades** and **skills/classes**
  in the lobby; individual runs otherwise start fresh.

## Economy & monetization (must sell — but *fair, not pay-to-win*)

Three-tier model mirroring Dead Rails' proven, well-liked economy:
- **In-run cash** — scavenged/earned during a run, spent at **dock shops** (fuel, ammo, weapons,
  healing, repairs). **Resets each run.**
- **Persistent meta currency** _(name TBD)_ — rare; from **run objectives** + completing runs. Spent in
  the **lobby** on permanent **boat upgrades**, **skills/classes**, and starting gear. **Earnable free.**
- **Robux** — **convenience & cosmetics only**: **paid self-revive**, **extra inventory slots**,
  cosmetics/skins, maybe a starter boat / game pass. Core power stays earnable.

**Revive model** (matches Dead Rails, and your brief): a downed player is revived by a **teammate
holding interact with a bandage** — bandages are **scarce**, so it's a real resource cost. On death,
the paid **self-revive** (Robux, short window) is the monetized safety net. A skill/class may grant a
free revive ability.

> **Design principle:** Dead Rails' monetization works *because it "feels fair."* Paid = convenience +
> cosmetics, never raw power. We hold to that — it's why the model sells long-term.

## Inventory

- Players have an **inventory** of carried items — bandages, fuel cans, ammo, collectibles, scavenged
  loot.
- It's **capacity-limited** (you can't hoard everything), which creates real choices at docks about
  what to grab/keep.
- **Extra inventory space is purchasable** (soft currency and/or Robux) — another monetization lever.
- _OPEN: per-player vs shared boat stash; slot-based vs weight; do fuel/ammo count against it or are
  they separate boat tanks._

## Not yet covered (design/production backlog)

Captured so nothing's forgotten; most resolve inside their build phase. ★ = decide early (foundational).

**Design**
- Onboarding / tutorial (esp. first-time **mobile** players)
- ★ Combat depth: weapon types, **mobile aiming** (auto-aim?), reload, melee
- ★ Enemy roster beyond crocs + a spawn/pacing "director"
- Health / downed-timer / healing model (bandages vs medkits)
- ★ Boat feel: steering model, buoyancy/physics, collisions, camera
- ★ Map authoring: handcrafted vs procedural zones, length, checkpoints
- End-game: what happens after the finish; prestige / replay hook
- Boat variety & customization (stats, skins)

**Systems / tech**
- ★ Matchmaking: party, friends-only vs fill, join/leave/rejoin mid-run
- ★ Reserved-server teleport + data hand-off (lobby → game)
- ★ Persistence: DataStore for meta currency / unlocks / stats + data-loss safety
- ★ Anti-cheat / strict **server authority** (critical — real money involved)
- Cross-server leaderboards; performance/streaming budget for mobile; analytics/KPIs

**Content / art**
- ★ Jungle's own **GUI design system** (its own skill, like Defender's `roblox-gui`)
- Art style guide (low-poly consistency); asset pipeline (Meshy + Creator Store + Pixabay/Flaticon/
  ChatGPT — see `GROUND-RULES.md §4`); music & ambient audio; VFX / game-feel juice

**Live-ops / business**
- Daily rewards, quests/missions, seasons/events (battle pass?)
- Exact Robux product list + pricing; engagement-based payouts
- Compliance: age rating, avoid gambling-like mechanics; accessibility; localization

**Go-to-market**
- ✅ **Name: "Last River"** (working title, locked 2026-07-18). Still need icon/thumbnail — the genre
  spreads via short-form/mobile discovery. (Optional: verify the name isn't taken on Roblox.)
- Trailer / clip-worthy set-pieces

## Open questions (tracked; resolve as we build)

- [ ] Solo play: is 1 player viable (auto-assist idle stations / difficulty scale), or min 2? _(leaning: playable solo, scaled)_
- [ ] The 4th role.
- [ ] Number/length of campaign zones for v1.
- [ ] Which specific animals beyond crocodiles; do they attack boat, players, or both per-type.
- [ ] Exact fail thresholds and revive rules.
- [ ] Economy: one **soft** currency vs **soft + premium (Robux)** split; currency name(s).
- [ ] Revive monetization: fully paid vs limited-free + paid; pricing / cooldown.
- [ ] Which **pre-run upgrades & skills** exist (boat stats, perks).
- [ ] Robux product list (revive packs, cosmetics, unlocks, game pass?).

## Assets needed — **Jungle's own** (the existing Meshy library is Defender's, not for Jungle)

See [Jobs/001/implementation-plan.md](Jobs/001/implementation-plan.md) for the full inventory mapped to
production phases. Broad strokes: jungle river terrain + docks, boat, crashed plane, crocodile & other
animals, low-poly flora/props, fuel/ammo pickups; systems for matchmaking/teleport, boat control,
roles, animal AI, resources, day/night, scoring; lobby + in-run HUD; and jungle/boat/animal audio.
