# Job #099 — Final summary

**Project**: `roblox.jungle` · **Places**: GAME + LOBBY (boundary crossing permitted)
**Status**: ⚠️ **CODE COMPLETE — NOT CLOSED.** Everything Studio can settle is done and verified; five
checks need a real device (§4).

Intake: [intake.md](intake.md) · Plan: [implementation-plan.md](implementation-plan.md)

---

## 1. The finding that matters most

**Pixel `MinSize` floors do not scale with device DPI**, and Roblox's GUI coordinate space on a high-DPI
phone can be far smaller than a screenshot's resolution suggests.

Job #095 raised the lobby rail to a hard `MinSize = (64, 420)` so five thumb-sized badges would fit. On a
device reporting roughly 1200×540 that is **~87% of the canvas**, and the rail climbs under the Roblox
topbar — precisely what the reported screenshot showed.

**No amount of aspect-ratio testing would have found this.** Todo #0059 blamed the aspect matrix
(1.78:1 vs 2.16:1), and that gap is real, but it was not the cause. The cause is absolute size, not
shape. Every fix in #094/#095/#097 leaned on pixel floors (58, 420, 62); they were all suspect for the
same reason.

**So the fix is not a better number — it is removing the dependence on one.**

## 2. What changed

**Lobby rail — sized from the canvas.** `Components.iconBar` now computes its height at runtime from the
ScreenGui's `AbsoluteSize`: at most 62% of available height, preferring a 58px badge and degrading to the
44px platform minimum only when the canvas is genuinely too short. Recomputed on resize, so orientation
and the device emulator are covered. **Captions drop on touch**, which is what buys the height back.

| Canvas | Before (#095) | After |
|---|---|---|
| 710 phone | 420px = 59% | **322px = 45%**, badge 58 |
| 599 phone+inset | 420px = 70% | **322px = 54%**, badge 58 |
| 537 small 20:9 | 420px = 78% | **322px = 60%**, badge 58 |
| 482 DPI-scaled | 420px = **87%** | **299px = 62%**, badge 53 |
| 400 very small | — | **252px = 63%**, badge 44 |

**Lobby hint — the clipping was vertical, and #095 caused it.** `applyText` sets `TextScaled` with a
**12px `MinTextSize` floor**, so text cannot shrink out of a box that is too small — it wraps, and the
overflow is cut. #095 narrowed the panel 0.44 → 0.32 to clear the TopBar; the title then wrapped to two
lines and the unchanged 0.085 height had room for one. Height is now 0.115 with a 96px floor; title box
40px and subtitle 33px at every phone canvas.

> #095 checked that the narrowed panel no longer **collided**. It never checked that the text still
> **fit**. That is the lesson, not the pixel value.

**GAME — finding #0009.** `ObjectiveHud`'s collapsed card (which *is* the tap target that expands the
objective list) 0.045 → 0.075; `InventoryHud`'s `DropButton` gets a 58px floor. The card stays visually
small and the button grows past it — invisible, and entirely the point. It is the only way to put cargo
down, and a carrying player can neither shoot nor swing an axe.

## 3. Verification

Lobby sweep after the changes, now including tall and DPI-scaled canvases no earlier job tested:

| 1920×1080 · 1334×750 · 1624×750 · 1448×599 · 1352×537 · 1200×482 |
|---|
| **no overlaps at any size** |

`luau-analyze.sh` clean on both trees.

⚠️ The sweep reports rail badges as `57×57` everywhere. **That is a clone artifact, not a finding** —
`resize()` is runtime logic that does not run on clones, so the cloned rail carries the live desktop
value. This is the **fourth** time this harness has produced a misleading number (after #095's
imperatively-sized `+`, #097's force-visible hotbar slots, and this job's `TextFits = true` on clipped
text). The agreed position now stands: **the harness is trustworthy for static rectangle collisions and
nothing else.**

## 4. What remains — device only

Not settleable from a desk, and not claimed as done:

1. **Fresh lobby screenshot** confirming the rail and hint on a real phone.
2. **#0004** — one set of driving controls, or two?
3. **#0006** — drag to look without firing; then a deliberate shot that does fire.
4. **#0007** — drag to aim the turret; is `TOUCH_SENS = 0.010` usable?
5. **#096 multi-touch** — throttle + steer through a bend; thumb-slide off the throttle.

One session covers all five — written up as **todo #0058**.

## 5. Files changed

| File | Change |
|---|---|
| `lobby/.../UI/Components.luau` | `iconBar` canvas-driven sizing; `iconButton` optional caption |
| `lobby/.../LobbyClient.local.luau` | hint height 0.085 → 0.115, floor 54 → 96 |
| `sync/.../UI/ObjectiveHud.local.luau` | collapsed card 0.045 → 0.075 |
| `sync/.../UI/InventoryHud.local.luau` | `DropButton` 58px floor |

## 6. Queue

- **#0009** — fixed and statically verified; close after the device screenshot confirms it.
- **#0004 / #0006 / #0007** — unchanged, still device-blocked.
- **#0058** — the session that closes all of the above.
- **#0059** — its rail/hint half is fixed here; its *aspect-matrix* half is now permanently addressed
  because the layouts no longer depend on absolute pixel sizes.
