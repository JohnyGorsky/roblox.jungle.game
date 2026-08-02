# Final Summary — Job #068

**Project**: `roblox.jungle`
**Completed**: 2026-08-02
**Status**: ✅ Completed — **audit only, no code or place changes** (fixes went to Job #069)

## What this job was

A full coverage check of the **LOBBY place** (Jungle Airfield) against `ASSETS.md` §1 and `GAME.md`:
is everything implemented, are all purchases covered end to end, is any greybox left — with every gap
marked REQUIRED or OPTIONAL.

Delivered in two passes: a **desk audit** (all 48 files under `lobby/`, plus the game tree where a
lobby purchase is applied there) and a **live greybox sweep** run read-only via Studio MCP against the
open place.

## Outcome

**7 required gaps reported. 3 were real. 4 were wrong.** Plus **3 more found only by the live sweep**,
including one genuinely broken feature no amount of file reading would have caught.

| Gap | Verdict |
|---|---|
| **A1** `RobuxShop` shows a buy button for passes already owned | ✅ real → fixed in #069 |
| **A2** Cosmetic Bundle still buyable on the Creator Hub | ✅ real → **user set it Offsale** |
| **D1** `LobbyConfig.PAD_COUNT = 3` dead and wrong (4 pads) | ✅ real → fixed in #069 |
| **E2** dock water sound never attaches *(sweep-only)* | ✅ real → fixed in #069 |
| **E3** rope creak reached 2 of 4 watchtowers *(sweep-only)* | ✅ real → fixed in #069 |
| **B1** `Leaderboard_Weekly` is an empty board | ❌ **wrong** — placeholder exists, editor-placed |
| **B2** Bounties + BoatUpgrades lack an entry sign | ❌ **wrong** — all 4 stations have one |
| **B3** spawn "airfield star" is greybox | ❌ **by design** — the cream disc is the intended marker |
| **E1** `RunwayMarkings` + `Spawn.Pad` are greybox leftovers | ❌ **by design** (user ruling) |

### Purchases — better than expected

All 5 live items are sold, have Hub ids, working receipt/ownership paths and real effects. **No
sold-but-unimplemented item, and no promised-but-unsold item** — the Job #067 class of bug does not
recur. The only defects were the missing owned state (A1) and the lingering Hub listing (A2).

Bonus: the user's Hub screenshot verified all three pass prices match `MonetizationDefs` (149/99/499).

### Greybox — the lobby is ~95% clean

Of **3,810 BaseParts** under `LOBBY_GREYBOX`, the greybox signature survived in three places, and all
three turned out to be intended design. Confirmed **gone**: the greybox plane (13 parts), pilot (3),
both stalls (18), kiosk, bench, dock + `Winch`, every camp prop, the neon `Flame` parts, all 30
foliage clumps, greybox towers. `LOBBY_BLOCKOUT` absent.

Also verified: `preparePaintLibrary()` **has** been run (18 MeshParts, 3 `PaintablePBR`), so Boat Paint
liveries render properly rather than flat.

## The lesson worth keeping

**Every one of the four false findings came from the same mistake: inferring the world from the source
tree.** The lobby is explicitly editor-placed (memory: `lobby-editor-placed-not-scripted`), so
*"no script references it"* and *"it isn't there"* are different claims — and for B1 and B2 the second
was false. B3 and E1 came from trusting stale `ASSETS.md` status rows.

Two durable guards were added rather than just noting this:

1. **A standing warning at the top of `ASSETS.md`** — *"This file describes INTENT. The place is the
   ground truth"* — naming both traps explicitly.
2. **A confirmed-intentional list** in Part E of the intake. `Spawn.Star`, `Spawn.Pad` and
   `RunwayMarkings` are byte-identical to the greybox originals, so **any future sweep will re-flag
   them**. Signature-matching finds *unchanged* parts, not *unwanted* ones — the sweep can only ever
   produce candidates for a human ruling.

## Files changed

**None in `lobby/` or the place** — this job was audit-only, by design. Output was documentation and
the work queue:

- `Jobs/068/intake.md` — the full audit (Parts A–E), decisions, and the corrected findings
- `todo/0019`–`0041` — 19 gaps filed; `0016`, `0018`, `0021`, `0022`, `0024`, `0035`, `0036` reconciled

## Verification

- [x] Desk audit — all 48 `lobby/` files read; purchase paths traced into the game tree
- [x] Live greybox sweep — read-only `execute_luau`, no writes, no deletions
- [x] Five load-bearing greybox parts confirmed intact (`PartyPad_*.Center`, `Dock.Pier`, both
      `FirePit`s, `Leaderboard_TopRuns.Board`, watchtower model names) — nothing recommended for deletion
- [x] All false findings withdrawn in-place with the reasoning recorded, not silently deleted
- [ ] `Lighting.Technology = Future` — **NOT verified**; unreadable from the MCP context
      (*"lacking capability RobloxScript"*). Left open as `todo/0040` for an eyeball check.

## Outstanding

| Item | Owner |
|---|---|
| `Lighting.Technology` eyeball check + save the place (`todo/0040`) | **user** |
| 11 optional todos — `0039` (doubled `Bloom`/`SunRays`) is the only one with a real perf cost | queued |
