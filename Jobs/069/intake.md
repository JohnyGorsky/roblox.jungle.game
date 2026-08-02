# Job #069: Lobby audit fixes (Job 068 follow-up)

**Project**: `roblox.jungle`
**Created**: 2026-08-02
**Status**: In progress

## Requirements / goal

Implement the required gaps found by the **Job #068 lobby coverage audit**, in the agreed severity
order **A1 → D1 → E1 → E2 → E3**, with **A2** and **B3** as user actions.

**Working rule for this job (user, 2026-08-02):** *each task is described first and only implemented
once the user accepts it.* One task at a time.

> Scope note: Job 068 is **audit-only**. Every code change lives here.
> Gap ids (A1/D1/E1…) refer to `Jobs/068/intake.md`.

## Task list

| Order | Gap | Todo | Kind | Status |
|---|---|---|---|---|
| 1 | **A1** — `RobuxShop` shows a buy button for passes the player already owns | `0019` | code | ✅ **done** |
| 2 | **D1** — `LobbyConfig.PAD_COUNT = 3` is dead and wrong (4 pads) | `0023` | code | ▫ awaiting description + approval |
| 3 | **E1** — greybox `RunwayMarkings` double-paints the real runway; `Spawn.Pad` | `0036` | live/place | ▫ |
| 4 | **E2** — dock water-lapping sound never attaches | `0037` | code | ▫ |
| 5 | **E3** — three models named `Watchtower_NW` | `0038` | live/place | ▫ |
| — | **A2** — unlist Cosmetic Bundle on the Creator Hub | `0020` | **user** | ▫ |
| — | **B3** — spawn star still greybox (reopened by the sweep) | `0022` | **user** | ⚠️ needs the user's answer |

---

## ✅ Task 1 — A1: owned-pass state in the Robux shop

**File:** `lobby/sync/StarterPlayer/StarterPlayerScripts/UI/RobuxShop.local.luau` (LOBBY tree only).

### What was wrong

Every pass row was gated on `gamePassId > 0` — *"does this product exist"*, never *"does this player
own it"*. `MonetizationServer` already publishes `Owns_<key>` on the player and this screen never read
it, so an owner of the 499 R$ Armored Boat still saw a live buy button; only Roblox's own dialog told
them. It was the **only** lobby shop without an owned state.

### What changed

1. `offer()` now **returns the row**, so a caller can update it after construction.
2. The **passes** loop registers an ownership refresh per row: reads `Owns_<key>`, and on owned sets
   `setText("OWNED")` + `setEnabled(false)`.
3. It subscribes to `player:GetAttributeChangedSignal("Owns_<key>")`, so a row flips **the moment a
   purchase completes**, with no panel reopen.

### Two decisions inside the change

- **Gold packs are deliberately excluded.** They are repeatable developer products — "owned" is
  meaningless and their buy button must always stay live. Only `GamePasses` get the treatment.
- **The default is "not owned", and that direction matters.** `Owns_extraSlots` and friends arrive
  *after* an async `UserOwnsGamePassAsync` round-trip, i.e. after the row is built. So the row starts
  showing the price and flips to OWNED when the attribute lands. Defaulting the other way would
  briefly hide a real buy button from someone who has **not** bought — a worse failure than briefly
  showing one to someone who has.

### Deviation from what was described

I said "OWNED **with the `check` icon**". It ships as **text + disabled only**, no icon swap, because:

- `Components.row` builds its icon at construction and exposes no setter, and the row's badge already
  holds the **product's real store art** — replacing that with a generic tick loses information.
- It now matches the existing lobby exactly: `ModulesShop` (`OWNED`), `SkillShop` (`MAX`) and
  `RetentionClient` (`CLAIMED`) are all text-only too. **Nothing in the lobby currently renders the
  `check` icon for these states**, so adding it here alone would be the inconsistent choice.

`ASSETS.md` §1.9 row 8 lists `check` as *"CLAIMED / OWNED / MAX states"* — that remains an unrealised
intention across four screens, not an A1 gap. Worth a separate pass if we want it.

### Verified

- `tools/luau-analyze.sh` on the file (LOBBY tree) → **no diagnostics**.
- Attribute name traced end to end: `MonetizationServer` writes `"Owns_" .. gp.key`; this screen reads
  `"Owns_" .. gp.key`. Keys: `armoredBoat`, `boatPaint`, `extraSlots`.
- `Components.button.setEnabled(false)` sets `enabled = false`, and the `Activated` handler returns
  early on it — so a disabled OWNED row **cannot** fire a purchase prompt.

### NOT verified — needs a Play test

This is a file edit in the LOBBY Rojo tree, so it **needs a Rojo sync** before it exists in the place.
Confirming the flip visually needs a player who owns a pass — the honest check is:
**Play → open the Robux shop → a pass you own reads OWNED and is not clickable.**

## Checklist

- [x] Task 1 (A1) implemented + analyzer clean
- [ ] Task 1 verified in Play (needs Rojo sync)
- [ ] Tasks 2–5 described, approved, implemented
- [ ] Final summary + changelog
