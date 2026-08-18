# Job #099 — Implementation plan

**Project**: `roblox.jungle` · **Places**: GAME **and** LOBBY (boundary crossing permitted)
**Status**: IMPLEMENTED for everything Studio can settle — see final-summary.md

Intake: [intake.md](intake.md)

---

## 1. Decisions (agreed via wizard, 2026-08-18)

| # | Decision |
|---|---|
| Scope | **One job, both places.** Splitting would need two device sessions |
| Build | The reported screenshot **did** include #095 — so the current code is genuinely wrong on device |
| Rail | **Drop labels on touch**, keep the 58px badge — reverses #095's reasoning |
| Verification | **Device-first.** Harness for static geometry only |

## 2. The core insight this job turns on

**Pixel `MinSize` floors do not scale with device DPI.**

Roblox's GUI coordinate space on a high-DPI phone can be far smaller than the screenshot resolution
suggests. #095's `MinSize = (64, 420)` was tuned against desktop-sized viewports; on a device reporting
~1200×540 it becomes ~87% of the canvas and the rail climbs under the Roblox topbar — exactly what was
reported. No amount of *aspect-ratio* testing reveals this, because the failure is about absolute size,
not shape.

**Therefore the fix is not a better number. It is removing the dependence on a number.**

## 3. What was changed

### 3a. LOBBY — the rail sizes from the canvas, not toward a constant

`Components.iconBar` now computes its height at runtime from the ScreenGui's own `AbsoluteSize`:

- takes at most **62%** of available height,
- prefers a **58px** badge, degrading to the **44px** platform minimum only when the canvas is genuinely
  too short,
- recomputed on `AbsoluteSize` change, so orientation changes and the device emulator are covered,
- **captions hidden on touch** (`showLabel`), which is what buys the height back.

Measured across canvases (n=5, gap 8):

| Canvas | Rail | % of canvas | Badge |
|---|---|---|---|
| 1080 desktop | 322px | 30% | 58 |
| 710 phone | 322px | 45% | 58 |
| 599 phone+inset | 322px | 54% | 58 |
| 537 small 20:9 | 322px | 60% | 58 |
| 482 DPI-scaled | 299px | 62% | 53 |
| 400 very small | 252px | 63% | 44 |

Against the old hard floor's **78–87%**. It can no longer swallow the screen, and it degrades instead of
breaking.

### 3b. LOBBY — the hint's clipping was VERTICAL, and #095 caused it

`applyText` sets `TextScaled` with a **12px `MinTextSize` floor**, so text cannot shrink out of a box
that is too small — it wraps, and anything past the box is cut. #095 narrowed the panel 0.44 → 0.32 to
clear the TopBar; the title then wrapped to two lines and the unchanged 0.085 height had room for one.
Hence "STEP ON A LAUNCH PAD TO" and "…hold Start to launch the", both severed mid-sentence.

**#095 checked that the narrowed panel no longer collided. It never checked that the text still fit.**

Fix: panel height 0.085 → **0.115**, `MinSize` height 54 → **96** (the clamp that actually bites on a
phone), `MaxSize` 130 → 150. Verified: title box 40px, subtitle 33px at every phone canvas — room for two
wrapped lines at the 12px floor.

### 3c. GAME — finding #0009

- `ObjectiveHud` `collapsedSize` height **0.045 → 0.075** (and the expanded size kept consistent). The
  card *is* the tap target that expands the objective list.
- `InventoryHud` `DropButton` gets a `UISizeConstraint` `MinSize = (0, 58)`. The card stays visually
  small; the button grows past it, which is invisible and entirely the point. It is the only way to put
  cargo down, and a carrying player can neither shoot nor swing an axe.

## 4. Verification

Static geometry only, per the agreed split. Lobby sweep after the changes, now including tall and
DPI-scaled canvases the earlier jobs never tested:

| Canvas | Result |
|---|---|
| 1920×1080 · 1334×750 · 1624×750 · 1448×599 · 1352×537 · 1200×482 | **no overlaps at any size** |

`luau-analyze.sh` clean on both trees.

⚠️ The sweep reports rail badges as `57×57` at every canvas. **That is the clone artifact, not a
finding** — `resize()` is runtime logic and does not run on a clone, so the cloned rail carries the live
desktop pixel value. The formula table in §3a is the trustworthy source. This is the same class of
artifact as #095's `+` button and #097's hotbar slots.

## 5. What remains — device only

Nothing below can be settled from a desk, and this job does not pretend otherwise:

1. **Confirm the rail and hint on a real phone** — a fresh screenshot of the lobby.
2. **finding #0004** — one set of driving controls, or two?
3. **finding #0006** — drag to look without firing; then fire deliberately.
4. **finding #0007** — drag to aim the turret; report whether `TOUCH_SENS = 0.010` feels right.
5. **Job #096's multi-touch** — throttle + steer together through a bend; thumb-slide off the throttle.

All of it is one session, already written up as **todo #0058**.
