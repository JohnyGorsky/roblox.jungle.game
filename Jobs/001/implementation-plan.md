# Implementation Plan — Job #001: Define Jungle (roadmap + object inventory)

**Project**: `roblox.jungle`
**Created**: 2026-07-18
**Status**: Planning (awaiting go-ahead)

This job is design, not gameplay code. Its "implementation" = the **production roadmap** and the
**object/asset inventory**. Each roadmap phase becomes its own future job.

## Decisions locked (via wizard)

- Core: 1–4 player co-op **river-run survival**; lobby → reserved gameplay server.
- Structure: **finite staged campaign now**, endless mode later.
- Stake: **both boat + players** (boat HP; players can be downed + revived).
- Roles: **swappable stations** (driver / gunner / catcher / 4th TBD).
- Stops: **designated docks**, gated by fuel.
- Style: stylized **low-poly**. Replay: **score & leaderboards**.

## Production roadmap (each phase = a future job)

Ordered so we always have something playable, building the **fun core first**, art/polish last.

- **P0 — Set up Jungle project (tech prerequisite).** Create the on-disk `sync/` structure +
  `default.project.json` (so Studio Sync stops erroring), the `luau-analyze` wrapper + sourcemap, and
  fill in the `jungle-project` skill (architecture, sync table already recorded). *Must come first.*
- **P1 — Boat + river vertical slice.** One short river stretch (water + banks), a **boat controller**
  (drive/steer/throttle), camera. Goal: driving the boat feels good. *This is the make-or-break feel test.*
- **P2 — Role stations.** Swappable driver/gunner/catcher stations; seat/station interaction; works
  for 1–4 players.
- **P3 — Threats & combat.** Crocodile + first animal **AI/spawning**, **gunner** shooting, **boat HP**
  + **player down/revive** (revive built with a **paid hook**, monetized in P8). Danger becomes real.
- **P4 — Resources, inventory & docks.** **Fuel** + **ammo** systems, **limited inventory** (bandages/
  loot/pickups), **designated docks**, disembark → scavenge encounter → refuel/rearm. Closes the core loop.
- **P5 — Campaign zones & escalation.** Sequence of zones/checkpoints to a fixed **end**, difficulty
  ramp, **day/night cycle**.
- **P6 — Lobby & matchmaking.** Lobby place, **team-up UI (1–4)**, **reserved-server teleport** to the
  gameplay place, and the **pre-run upgrade/shop area** (lobby/crash). (Can stub earlier; full version here.)
- **P7 — HUD, scoring & leaderboards.** In-run HUD (fuel/ammo/health/roles/distance), results screen,
  **global + friends leaderboards** (DataStore).
- **P8 — Economy, upgrades, inventory & monetization.** Soft + premium currency, pre-run **boat/skill
  upgrade shop**, **limited inventory** + purchasable slots, **paid revive** wiring, Robux
  products/cosmetics, DataStore persistence.
- **P9 — Art & polish pass.** Low-poly asset production (boat, plane, crocs, flora, props), sound, VFX,
  lighting/atmosphere, mobile performance budget.
- **P10 (later) — Endless mode.**

> Order rationale: P1–P4 prove the game is fun with placeholder blocks before we invest in art (P9),
> economy (P8), or full matchmaking (P6). We playtest each phase live via the Studio MCP.

## Cross-cutting constraints (apply to every phase)

- **Mobile-first** (hard requirement) — every control and GUI is touch-first and **scale-based**
  (`UDim2` scale, `UIAspectRatioConstraint`/`UIScale`, safe-area aware), then maps to PC/console.
  No keyboard-only actions; no fixed-pixel layouts. Enforced on P2 (roles/input), P6, P7, P8 GUIs.
- **Server-authoritative** — currency, inventory, revives, and scoring are validated server-side
  (never trust the client), per the shared `roblox-dev` rules. Critical since real money is involved.

## Object / asset inventory (Jungle's own — NOT Defender's Meshy library)

Source key: 🧱 build in code · ⛰️ sculpt terrain · 🎨 low-poly model (Studio/Blender or `generate_mesh`) ·
🛒 Creator Store · 🔊 audio (Pixabay).

### Terrain / maps — ⛰️/🎨
- River water + banks per zone; rapids/rocks (P1, P5)
- Crash-site landing area (P5)
- Designated docks / scavenge areas (P4)
- Lobby environment (P6)

### Models — 🎨
- **Boat** (with station positions) — P1
- Crashed **plane** — P5
- **Crocodile** + other animals (each: model + anims) — P3
- Jungle flora/props: trees, vines, rocks, foliage — P1/P8
- Pickups: **fuel cans, ammo crates**, item/collectible props — P4
- Dock structures — P4

### Systems (code) — 🧱
- Boat controller (drive/steer/throttle/dock) — P1
- Role/station system (swap, per-station input) — P2
- Animal AI + spawning (river & bank) — P3
- Combat: gunner weapon, boat HP, player down/revive — P3
- Resource system: fuel drain, ammo, refuel/rearm at docks — P4
- **Inventory system**: limited slots, carried items, purchasable extra space — P4 (purchase in P8)
- Zone/campaign progression + difficulty ramp — P5
- Day/night cycle — P5
- Matchmaking + `TeleportService` reserved servers — P6
- Scoring + leaderboards (DataStore) — P7
- **Economy**: soft + premium currency, earn/spend, DataStore persistence — P8
- **Monetization**: pre-run upgrade shop, paid revive, Robux products/cosmetics — P8

### GUI — 🧱🎨 (all **mobile-first / scale-based**)
- Lobby / team-up screen — P6
- Pre-run **upgrade & shop** screen — P6/P8
- **Touch controls** (drive joystick, shoot/catch/interact buttons) — P2 (per role)
- In-run **HUD**: fuel, ammo, boat HP, player states, roles, distance, inventory — P7
- **Inventory / shop** UI, **revive** prompt — P4/P8
- Results / score screen — P7

### Sound — 🔊
- Boat engine, water; animal SFX; ambient jungle; night/tension cues — P8 (hooks earlier)

## What I need from you (to finish this job)

- [ ] Confirm the concept in `GAME.md` v0.2 reads right (edit freely / tell me changes).
- [ ] Approve the roadmap **order** (esp. doing P1 boat-feel before art/matchmaking).
- [ ] Any of the `GAME.md` open questions you already have an answer for (4th role, solo play, # of
      zones) — otherwise we resolve them when their phase comes up.

## On completion

- Promote each roadmap phase (P0–P8) to a file in `Planned/`.
- Close this job with `final-summary.md` + `changelog.md`.
- Start **P0 (Set up Jungle project)** as the next job.
