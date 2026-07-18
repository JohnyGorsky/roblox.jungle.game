# Final Summary — Job #001: Define Jungle (concept, style & production plan)

**Project**: `roblox.jungle`
**Completed**: 2026-07-18
**Status**: ✅ Completed — concept LOCKED (v1.0)

## What was produced

A shared, written foundation for the game before any gameplay code:

1. **[GAME.md](../../GAME.md) v1.0 (concept locked)** — full vision: co-op (~1–6 player) **jungle
   river-run survival**; lobby → reserved gameplay server; **mobile-first**; finite staged campaign
   (endless later); crash-in → ride → dock/scavenge → escalate → reach the end; boat + players at
   stake with revives; swappable role stations; **fuel-hauling** ("keep feeding the boat"); day/night
   that flips where it's safe (day = ride, night = dock & defend); score + leaderboards; a **fair,
   not-pay-to-win 3-tier economy** (in-run cash / persistent meta currency / Robux); limited
   purchasable inventory; a **market analysis**; and a **gap/backlog** of what's not yet covered.
2. **[implementation-plan.md](implementation-plan.md)** — the **production roadmap P0–P10** (each phase
   = a future job) + an **object/asset inventory** mapped to phases, with cross-cutting constraints
   (mobile-first, server-authoritative).
3. **[Planned/](../../Planned/) P0–P10** — one file per roadmap phase, ready to promote to jobs.

## Key decisions locked (via wizard + discussion)

- **Reference/positioning:** modeled on **Dead Rails** (proven co-op vehicle-survival loop); market
  scan shows the **jungle-river cell is open** (closest analog, Dead Sails, cratered/abandoned).
- **Core tension:** boat safest while moving; **fuel forces risky stops**; players haul fuel back.
- Finite staged campaign now, endless later · both boat + players at stake · swappable stations ·
  designated fuel-gated docks · day-ride/night-dock-defend · stylized low-poly · ~4–6 core crew
  (up to ~8) with deck-defenders for extras · score & leaderboards · 3-tier fair economy · paid
  self-revive + scarce bandage revive · limited/purchasable inventory · **mobile-first (hard req)**.

## Research (background agents, sourced)

- **Dead Rails mechanics** — fuel/stop tension, two-currency economy, ~24-class system, bandage +
  45-Robux self-revive, night set-pieces, "feels fair" monetization. (Dev: RCM Games, not Jandel.)
- **Competitor landscape** — land clones saturated; **water/river niche open**; genre sweet spot
  ~4–16 players; differentiate via jungle theme + river mechanics + role depth + mobile + live-ops.

## Files changed

- `roblox.jungle/GAME.md` (v1.0), `Jobs/001/{intake,implementation-plan,final-summary,changelog}.md`,
  `Planned/P0–P10*.md` (11 files).
- `roblox.workspace/GROUND-RULES.md` §4 — added the Studio-MCP asset-sourcing path (Creator Store
  search, in-Studio generation, image upload; Meshy/Pixabay/Flaticon/ChatGPT; propose → approve →
  integrate).

## Open (tracked in GAME.md, resolved per-phase)

Game **name** (TBD), 4th role, solo viability, zone count, animal roster, exact economy/revive
pricing, and the full "Not yet covered" backlog (onboarding, combat/aim, matchmaking, persistence,
anti-cheat, GUI design system, live-ops, go-to-market).

## Next

- **Promote P0** (Set up Jungle project) to the next job and start building — it unblocks everything.
- Not committed (per the rule) — changes await user review + commit.
