# Implementation Plan — Job #011: Dock tie-up + first jungle camp

**Project**: `roblox.jungle`
**Created**: 2026-07-18
**Status**: ✅ Completed (2026-07-18)

## Goal
Stand up the **first vertical slice of the on-foot excursion pillar**: tie the boat at a dock, walk
inland to a greybox camp, loot it (guarded), carry the loot back. Greybox; server-authoritative.

## Slice scope (tight, verifiable)
1. **Tie / untie the boat** — add a **"Tie Boat"** ProximityPrompt to the dock. Tying **holds the boat at
   the dock** (anchor it, or an `AlignPosition`/rope to the deck) so it won't drift off while you're
   ashore; **"Untie"** releases it. A `Tied` state on the boat. (Rope visual = greybox line for now.)
2. **A walkable clearing at the dock** — carve a **flat terrain patch** inland from the dock (roblox-
   terrain) so there's somewhere to stand and build the camp (the travel banks are sloped hills).
3. **A greybox camp** — a few blocks (huts/crates) + **one guard** (reuse the `Panther`, leashed to the
   camp) placed in the clearing.
4. **Loot + carry-back** — a **lootable crate** (ProximityPrompt "Loot") yields a resource (e.g. Metal);
   the player **carries it** (weld to the character) and **deposits** it back at the boat (a drop-off
   prompt / touch) → adds to a boat/trailer resource count.

## Approach notes
- New scripts under `sync/ServerScriptService/Excursion/` (tie logic, camp+loot). Reuse `EnemyServer`
  patterns for the guard, `DockServer` for the dock the camp attaches to.
- Keep it **seeded/deterministic** (camp positions from `RiverData`, like docks) for fairness/replay.
- Server-authoritative: tie state, loot grant, deposit all validated on the server.

## Deferred (later excursion jobs)
Dense jungle foliage on all shores; camp/village variety + biomes; real **trailer cargo + capacity
(+ game-pass slots)**; loot tables + rarity; on-foot combat depth; the day/night "ashore at night is
safer" balancing; gated disembark polish.

## Success test
- [ ] Tie the boat at a dock → it holds there; untie → it's free again.
- [ ] Walk into the clearing to a greybox camp with a guard.
- [ ] Loot a crate → carry it → deposit at the boat → resource count goes up.
- [ ] All server-side; analyzer clean.

## Open questions to confirm before/while building
- **Tie hold** — anchor the boat outright, or rope it (physics) so it bobs at the dock? (Lean: soft
  anchor/AlignPosition so it stays but still floats.)
- **Loot unit** — carry a physical crate (one at a time, slow, Dead-Rails-like) vs an instant inventory
  bump? (Lean: carry one crate to seed the "haul" feel.)
- Does this slice put loot into a **trailer** (build a stub trailer now) or a simple **boat resource
  count** (defer the trailer)? (Lean: boat count now, trailer as its own job.)
