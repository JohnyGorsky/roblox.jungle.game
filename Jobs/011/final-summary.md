# Final Summary — Job #011: Dock tie-up + first jungle camp excursion

**Project**: `roblox.jungle`
**Completed**: 2026-07-18
**Status**: ✅ Completed — loop built & verified (prompt interactions need a Team Test)

## What was implemented

The **first slice of the on-foot excursion pillar**: tie the boat at a dock, a walkable jungle clearing
with a guarded camp inland, loot a crate and carry it back to the boat. Server-authoritative, greybox.

- **Tie / untie** (`DockServer`) — each dock has a **"Tie Boat"** prompt; tying **anchors the boat at the
  dock** so it won't drift off while the crew is ashore, untie releases it (`Tied` attribute). Greybox
  hard-anchor (a soft rope/bob is a refinement).
- **`ExcursionServer`** — at each dock it builds a camp inland (streamed near the boat, once each):
  - **Carves a flat walkable clearing** (`Terrain:FillBlock` grass up to a ground height, hills cleared
    above) so there's somewhere to stand — the travel banks are sloped.
  - **Greybox camp** — huts + a **loot crate** (`Loot` prompt) yielding a resource (Metal).
  - **A guard** (reuses `Panther` stats) that **targets on-foot players**, chases (leashed to the camp),
    and bites (damages the player's HP → the downed system). Tagged so the **weapon can shoot it**.
  - **Loot → carry → deposit:** loot the crate → a crate **welds to the player** (hands full → `Busy`,
    so you can't shoot) → a **"Deposit"** prompt on the boat banks it (`Metal` count on the boat) and
    frees your hands.

## Verification (live via Studio MCP)

- [x] `bash tools/luau-analyze.sh` clean on all scripts.
- [x] Camp builds inland: 2 huts + loot crate (with `LootPrompt`) + a guard; `TiePrompt` on the dock and
      `DepositPrompt` on the boat all present (screenshot shows Tie + Deposit live).
- [x] **Clearing carved flat** — Grass at the ground height, Air above (hills removed).
- [x] **Guard AI** chases and bites an on-foot player (HP 100 → 40 over a few seconds), leashed to camp.
- [~] Tie / Loot / Deposit are **ProximityPrompt** holds — structures + logic in place; the actual
      hold-to-trigger needs a **Team Test** (same as refuel/revive).

## Files changed (roblox.jungle)

- New: `sync/ServerScriptService/Excursion/ExcursionServer.server.luau`.
- Edited: `sync/ServerScriptService/World/DockServer.server.luau` (tie/untie prompt),
  `sync/ServerScriptService/Combat/WeaponServer.server.luau` (weapon can hit `CampGuard` too).
- New: `Jobs/011/*`.

## Notes / follow-ups

- **Not committed** (per the rule).
- **Team Test** the prompt loop end to end: pull up → tie → walk to camp → shoot the guard → loot →
  carry → deposit. Tune camp distance, guard difficulty, carry speed.
- Deferred (next excursion jobs): **dense jungle foliage on all shores**; camp/**village variety** +
  biomes; the **trailer** (cargo capacity + game-pass slots) replacing the plain boat `Metal` count;
  **loot tables**; **metal → repair station** + **ammo consumption** (the sinks for looted resources);
  gated-disembark polish; the "ashore is safer at night" balancing.
- Tunables: `CAMP_INLAND`, `CLEARING_SIZE`, `GUARD_LEASH`, `CAMP_AHEAD`.
