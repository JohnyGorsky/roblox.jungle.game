# Job #099: Mobile closeout — tall-phone aspects, CoreGui collisions, touch verification backlog

**Project**: `roblox.jungle`
**Places**: **GAME and LOBBY** — one job, crossing the place boundary **with explicit permission**
(asked and granted 2026-08-18; the mobile problem spans both and splitting it would need two device
sessions).
**Created**: 2026-08-18
**Status**: ⚠️ CODE COMPLETE — NOT CLOSED. Blocked on one device session (todo #0058).

## What this closes

| Item | What |
|---|---|
| finding **#0004** | Default VehicleSeat D-pad may still draw alongside ours |
| finding **#0006** | On touch, any tap-to-look fires the weapon |
| finding **#0007** | Turret unaimable on touch — gunner role unplayable *(high)* |
| finding **#0009** | In-run tray header (150×32) + DropButton (160×21) under the thumb floor |
| todo **#0058** | The phone session that verifies Job #096 |
| todo **#0059** | Real-phone overlap pass, incl. the two regressions Job #095 introduced |

## Investigation — and a correction to my own diagnosis

### A. The rail does NOT overflow. It is simply enormous.

Measured at the user's exact phone dimensions and every tall aspect, with the real component:

| Canvas | Rail height | % of canvas | Top tile |
|---|---|---|---|
| 1536×710, no inset *(what #095 tested)* | 420px | 59% | y=275, clear |
| 1536×710, topbar inset | 420px | 64% | y=219, clear |
| 1448×599, topbar+notch+home | 420px | **70%** | y=167, clear |
| 1352×537, small 20:9 full insets | 420px | **78%** | y=107, clear |

So `#095`'s "take the height" decision was **wrong at real aspects** — not because it overflows, but
because a nav rail eating three-quarters of everything the player can see is not a fix, it is a
different bug. At y=107 it also sits exactly where Roblox's own logo/menu chrome lives, which is why
BOAT reads as cut off in the screenshot.

### B. ⚠️ The likely root cause my aspect sweep still missed: **DPI, not aspect**

The user confirmed the screenshot **was** taken on a build including #095. My model says the rail is
clear there; the device says otherwise. The most probable explanation:

**Roblox's GUI coordinate space on a high-DPI phone is much smaller than the screenshot's pixel
dimensions.** If the device reports a viewport near 1200×540 rather than 1536×710, then after insets the
**hard 420px `MinSize` floor becomes ~87% of the canvas**, and its top edge lands under the topbar —
matching the screenshot exactly.

**The lesson is bigger than this job:** a *pixel* `MinSize` does not scale with device DPI. Every fix in
#094/#095/#097 leaned on pixel floors (58, 420, 62). They are all suspect on a high-DPI device, and no
amount of aspect-ratio testing would have revealed it. **`Camera.ViewportSize` on the real device is the
number we have never had.**

### C. The harness has now misled me three times

1. **#095** — the `+` button read as constant 47×47 because it is sized imperatively by a script; a
   clone carries a stale pixel value.
2. **#097** — hotbar slots read as 57×57 because forcing hidden children visible changes `UIListLayout`
   flow; they are really 76×76.
3. **#099 (here)** — the hint text measures `TextFits = true` at every phone canvas, yet the screenshot
   plainly shows it clipped.

**Agreed conclusion (wizard):** the harness is trustworthy for **static rectangle geometry only**. Text
fit, script-sized elements and Roblox CoreGui overlap are **device-only** questions. This job verifies
device-first and uses the harness only where it has earned trust.

### D. Finding #0009 — both are scale-derived, both real

- `ObjectiveHud` tray `Header` = the full collapsed card, `collapsedSize = 0.17 × 0.045` → **~29px tall**
  on a 640-tall canvas. It is the tap target that expands the objective list.
- `InventoryHud` `DropButton` = `Size(1,1)` of the HandsFull card, `0.2 × 0.036` → **~23px**. It is how
  a carrying player puts cargo down.

Neither is a `Components.button`, so #097's shared floor never reached them.

## Decisions (agreed via wizard)

| # | Decision |
|---|---|
| Scope | **One job, both places**, boundary crossing explicitly permitted |
| Rail | **Drop the labels on touch**, keep 58px badges — reverses my #095 reasoning, which predated knowing the rail eats 70–78% of the canvas |
| Verification | **Device-first.** Harness for static geometry only; user supplies a screenshot per state |
| Build | The screenshot **did** include #095, so the current code is genuinely wrong on device |

## Plan of attack

1. **Get the real numbers off the device** — `ViewportSize`, `GetGuiInset`, and the actual rendered size
   of the rail, hint and thumb targets. Everything else is guesswork until we have them.
2. **Make the layouts DPI-robust** rather than tuned to a guess: proportional sizing with sane caps
   instead of hard pixel floors that assume a desktop-sized coordinate space.
3. **Fix #0009** (Studio-verifiable, static geometry — the harness is reliable here).
4. **Device session** (todo #0058) closes #0004/#0006/#0007.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [~] Implementation completed — Studio-verifiable work done; 5 device checks outstanding (final-summary §4)
- [x] Final summary + changelog written
