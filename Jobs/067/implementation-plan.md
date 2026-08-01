# Implementation Plan — Job #067

**Project**: `roblox.jungle`
**Created**: 2026-08-01

Closes the four findings in [`intake.md`](intake.md). Decisions below are the user's (2026-08-01).

## Decisions

| # | Decision |
|---|---|
| 1 | **Boat Paint = tint in code**, no new textures. 6 in-world military liveries. |
| 2 | **Cosmetic Bundle: removed from the in-game shop only.** The Creator Hub listing stays up for now — the user will unlist it. Removing it in-game is what stops new purchases from *this* client. |
| 3 | **Armored Boat keeps its power**, and `GAME.md` records the exception honestly rather than pretending it doesn't exist. |
| 4 | **Build all three gaps this job**: ramps module, paid self-revive, extra inventory slots. |

---

## 1. Boat Paint Pack — the pass that sells nothing (finding 1)

### The art problem, and the answer

Every boat mesh imported with a **full PBR `SurfaceAppearance`** (ColorMap + Normal + Roughness + Metalness,
`AlphaMode = Overlay`). An opaque `ColorMap` **completely overrides `BasePart.Color`** — so the obvious
"just set `.Color`" does nothing at all. That is the trap this feature dies in if not checked first.

**Verified in Studio before designing around it:** `SurfaceAppearance.ColorMap` *is* writable at runtime
(unlike `MeshPart.MeshId`, which is plugin-gated — Job 066). So:

> **Clear `ColorMap`, keep `NormalMap` + `RoughnessMap` + `MetalnessMap`, set `BasePart.Color`.**

The sculpted weathering — rivets, panel lines, dents, wear-driven roughness variation — is carried by the
*normal and roughness* maps and survives completely. Only the painted albedo changes. That is a real
livery, not a colour wash over a photo.

`olive` is the **default and free**, and is implemented as *"leave the art exactly as authored"* — no
ColorMap clear at all — so the boat every player already knows is untouched.

### Pieces

| File | Change |
|---|---|
| `ReplicatedStorage/Boat/BoatPaint.luau` | **NEW**, both trees. 6 liveries, `DEFAULT`, `isValid()`, `apply(model, id)` |
| `ReplicatedStorage/Boat/BoatParts.luau` | `paintable` flag on `PartDef`; true for `hull` + `hullPlate` |
| `ReplicatedStorage/Progression/ProfileConfig.luau` | `paint` field + migration (both trees) |
| `Progression/Profiles.luau` | publish `BoatPaint` attribute; `setPaint()` (both trees) |
| lobby `PaintServer.server.luau` | **NEW** — RemoteFunction: validate pass ownership + livery id, persist, bump `ModulesRev` |
| lobby `BoatPaintPanel.local.luau` | **NEW** — swatch picker in the design system |
| lobby `LobbyBoat.server.luau` | apply paint on build |
| game `BoatModules.server.luau` | apply paint on build |

**Only the hull and its armour plates take paint.** Deck planking, engines, seats and stations keep their
own materials — a boat where the wooden deck turns navy blue looks like a bug, not a livery.

### The liveries

`olive` (free default) · `graphite` · `sand` · `navy` · `jungle` · `rust`. Owning the pass unlocks the
five non-default ones; everyone can always select `olive`.

## 2. Cosmetic Bundle — removed in-game (finding 1)

Dropped from `MonetizationDefs.GamePasses`, so it vanishes from the Robux shop in both places and
`MonetizationServer` stops setting `Owns_cosmeticBundle`. Trails / wake FX / emote stay unbuilt; the pass
is no longer sold from inside the game. **The Creator Hub listing is the user's to unlist.**

## 3. Armored Boat — keep, but stop the docs lying (finding 2)

The pass is `power = true` and `GAME.md` says twice that Robux is *"convenience & cosmetics only… core power
stays earnable."* Keeping the pass without touching the doc leaves the design pillar quietly false.

`GAME.md` gains an explicit, named exception recording *what* it is, *why* it's tolerated (the buff is
**shared with the whole crew**, so one buyer helps everyone — closer to "someone brought good gear" than a
solo advantage), and that it is the **only** power item we sell. No code change.

## 4. Ramps / Hull Shape module (finding 3)

A 7th Gold module, `ramps` — 170 Gold.

**What it actually does**, hooked to systems that exist today rather than a promise:

- **`RampBoost` (+35% launch)** — `RampTest` already applies launches through `boat.LaunchUntil`, and
  `RiverData` already emits deterministic `kind = "ramp"` hooks. The multiplier is read at launch time, so
  it works the moment real ramps land (todo `0013`) and works in `RampTest` now.
- **Rapids handling — the always-on benefit.** The Rapids zone runs `currentMul 1.5` / `turn 1.35`. The
  module gives **+20% rudder authority at low speed** (`TURN_FULL_SPEED` scaled down) and **−15% current
  shove**. Felt on every twisty stretch, not just on a jump.

Visible part: a bow ramp/spoiler wedge, greybox until art exists — the same `library = nil` pattern
Job 066 used, so it ships now and gets a mesh later.

## 5. Extra Inventory Slots pass (finding 4)

`ItemDefs.SLOT_COUNT = 4` is a hard constant read by `InventoryService` and `InventoryHud`. It becomes a
**base**, with `ItemDefs.MAX_SLOTS = 6` and a per-player `SlotCount` attribute. `+2 slots`, 149 R$.

Pure convenience: more carry capacity, no stat change. Squarely inside the design pillar.

## 6. Paid self-revive (finding 4)

`PlayerCombat` already has the downed state, the bleed-out timer and this exact comment at line 118:
`-- no self-revive (that's the paid revive, P8)`. The hook point was left for us.

Also: **the downed state currently has no client UI whatsoever** — you drop, you can't move, nothing tells
you why or how long you have. So this ships a **downed overlay** (bleed-out countdown + "waiting for a
teammate") with the paid *Get up* button as one element of it. The overlay is worth having on its own.

- Developer product (repeatable, in-run consumable), 49 R$ — **bought at the moment you're downed**, not
  stocked in the lobby shop.
- `MonetizationDefs.Products` + `MonetizationDefs.keyForProduct()`; `ProcessReceipt` grows a non-gold branch.
- Revives you at the same HP a teammate's bandage would, so paying is *convenience* (nobody nearby) rather
  than *advantage*.

⚠️ The GAME place has **no design system** — `Theme`/`Components` are lobby-only and its HUD is still
greybox (P9). The overlay therefore uses a small local palette lifted from `Theme.color`, commented as
such, so the P9 pass can delete it and swap in the real thing.

## New Creator Hub items the user must create

Both ship with `id = 0`, which the shop already renders as **"Soon"** and every ownership check guards —
so nothing breaks before they exist.

| Item | Type | Price | Name | Description |
|---|---|---|---|---|
| Extra Inventory Slots | **Game Pass** | 149 R$ | `Extra Inventory Slots` | `Two more loadout slots — carry a second gun, more bandages, and still keep your torch. Convenience only: no extra damage, no extra health.` |
| Self Revive | **Developer Product** | 49 R$ | `Self Revive` | `Downed with nobody nearby? Get yourself back on your feet at half health and keep the run alive. Usable any time you're bleeding out.` |

Ids go into `MonetizationDefs.luau` — `GamePasses[].gamePassId` and `Products[].productId` — **in both
trees** (`sync/` and `lobby/sync/`), which must stay byte-identical.

## Verification

- Analyzer clean on every touched file in **both** trees.
- Paint: check in Studio that a non-default livery **actually changes colour** on the lobby boat (the whole
  point of the ColorMap finding) and that Normal/Roughness survive; deck and engines unchanged.
- Slots: pass off → 4 slots; forced on → 6, hotbar redraws, looting fills slot 5.
- Self-revive: downed overlay appears, countdown runs, grant path revives (receipt path can't be tested
  unpublished — grant is exercised directly).
- Ramps: attribute set + part visible; rapids handling measured, not eyeballed.

## Checklist

- [x] Plan agreed
- [ ] Implementation
- [ ] Final summary + changelog
