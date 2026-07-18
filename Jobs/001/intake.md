# Job #001: Define Roblox Jungle — concept, style & production plan

**Project**: `roblox.jungle`
**Created**: 2026-07-18
**Status**: Requirements Gathering (intake)
**Type**: Discovery / design (collaborative)

## Goal

Describe the game **as it is / will be** so we have a shared, written foundation before building
anything. This job produces the description and the plan — not gameplay code.

## Deliverables

1. **`GAME.md`** (fleshed out) — the game vision:
   - Core concept & genre (what *is* Jungle?)
   - Visual style / art direction / mood
   - Core loop (what a player does minute-to-minute)
   - Mechanics — current (what exists) + planned
   - Target audience / session feel
2. **Production roadmap** — the ordered steps/phases to build the game, each of which becomes its own
   future job (e.g. "core movement", "first map", "enemy pass", "GUI/HUD", "economy").
3. **Object/asset inventory** — what will be needed: maps/terrain, models (characters, enemies, props),
   GUIs, scripts/systems, sounds — flagged by source (build in code / sculpt terrain / Meshy /
   already in inventory / Creator Store).

## What we already know (from the live Studio session + inventory, 2026-07-18)

- The place is **"Jungle run"** (universeId 10520080584) — currently near-empty: baseplate + spawn,
  no scripts synced to disk yet (the `sync/` folder doesn't exist — a "set up Jungle" job comes next).
- The account already has a **library of Meshy.ai models** usable as assets (knight, healing potion,
  cursed/glowing orbs, trees, skull, leaves, character rigs + an attack animation, several "Scene"
  models) — I can list/insert these directly via the Studio MCP.
- I can read/build/sculpt/playtest the live place directly via MCP.

## Open questions to resolve (via discussion — wizard)

- [ ] Core concept & genre (the name "Jungle run" hints at a runner/obby — confirm or redirect).
- [ ] Visual style (realistic vs stylized/low-poly vs cartoony) and mood.
- [ ] Single-player vs multiplayer; session length / target feel.
- [ ] How much do we reuse from Defender's systems/patterns vs build fresh.
- [ ] Monetization / progression, if any.

## Process

Discuss → capture answers into `GAME.md` → draft the production roadmap + object inventory in
`implementation-plan.md` → agree → this job closes with `final-summary.md` (+ `changelog.md`), and the
roadmap items get promoted to `Planned/` and future jobs.

## Checklist

- [ ] Concept & style agreed
- [ ] GAME.md written
- [ ] Production roadmap drafted
- [ ] Object/asset inventory drafted
- [ ] Plan agreed → summary + changelog
