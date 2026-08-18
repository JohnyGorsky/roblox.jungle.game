# Job #094 — Final summary

**Project**: `roblox.jungle` · **Place**: GAME (`sync/`) · **Status**: implemented, pending your review
**Studio**: `Last River COOP Game`, PlaceId 138141472932347

Intake: [intake.md](intake.md) · Plan: [implementation-plan.md](implementation-plan.md)

---

## 1. The reported bug: turn buttons were inverted — fixed

**Cause (measured, not inferred).** `UIListLayout.SortOrder` defaults to **`Enum.SortOrder.Name`**, and
the touch buttons are named from their glyph (`"Touch_" .. glyph`). `Touch_▶` (U+25B6) sorts before
`Touch_◀` (U+25C0), so the **right**-turn button rendered on the **left**. The steering maths, the seat
write and the server were all correct the whole time.

A probe built the real pair through the real component and measured it:

| | before | after |
|---|---|---|
| left-arrow (steer −1) | x = **227** (right) | x = **39** (left) ✅ |
| right-arrow (steer +1) | x = **39** (left) | x = **227** (right) ✅ |

**Throttle was correct only by accident** — `▲` (U+25B2) happens to sort before `▼` (U+25BC). It would
have broken silently the day anyone edited a glyph. Now explicit too.

**Fix:** `SortOrder = Enum.SortOrder.LayoutOrder` on both holders **and** explicit `LayoutOrder` on each
button (a new `layoutOrder` parameter on `RunComponents.touchButton`). Neither half works alone —
the intake's original proposal of "just set `LayoutOrder`" would have changed nothing, which is why it
was worth measuring before writing code.

**Why only this file:** all 10 other layouts in `sync/` already set `SortOrder` explicitly. These two
were the only ones that didn't.

## 2. Two thumbs at once — fixed (but see §6)

`touchButton` was bound to `MouseButton1Down` / `Up` / `MouseLeave`. Roblox routes only the **first**
active touch through mouse emulation, so a driver holding throttle could not reliably also press steer —
the exact input the boat is built around. Replaced with per-`InputObject` tracking via
`InputBegan`/`InputEnded`, so each finger is independent, plus a `UserInputService.InputEnded` fallback
that releases a button whose finger slid off before lifting (the latched-throttle hole the old
`MouseLeave` guard only half-covered).

One subtlety worth recording: `release()` now clears the owning `InputObject`. Without that,
`makePair`'s `setActive(false)` — which releases the opposite button while its finger may still be
physically down — would leave an owner behind and the button would refuse every later press. That is a
rudder that dies mid-bend and never returns. Covered by a regression assertion in the verification run.

## 3. Overlaps — audited and resolved

Built `tools/hud-overlap-audit.luau`, a **repo-kept regression check** that measures painted rectangles
(not holder frames) and reports every cross-HUD intersection plus every undersized tap target.

**Before → after**, 4 landscape resolutions:

| Overlap | Status |
|---|---|
| `HealthHud` ↔ steer buttons (up to 138×29 px, every resolution) | **Fixed** — health bar shifts right to x 0.225 while in a control seat, the same instant the hotbar already vacates the corner. |
| `BoatHud` vitals ↔ `InventoryHud` hotbar (29×29 px, phone presets only) | **Fixed** — vitals moved 0.5 → 0.55. |
| `UntieButton` 48 px tall, under the 58 px thumb floor | **Fixed** — height floor raised 44 → 58. |

Final sweep: **3 states × 4 resolutions, zero overlaps, zero undersized tap targets.**

### Two corrections to my own earlier analysis

- **I missed the vitals ↔ hotbar collision in the intake.** I checked the vitals against the touch
  controls but not against the hotbar. The detector caught it. Cause: hotbar slots are square, so its
  width derives from its **height** — on a short viewport it reaches x≈0.388, past the vitals' old
  0.35 edge. Invisible at desktop aspect, which is why scale arithmetic alone missed it.
- **Intake overlap #3 (carry chip vs steer) was wrong.** I read the `HandsFull` card's anchor as
  `(0,0)`; it is `(0,1)`, so it occupies 0.761–0.797 and clears the steer buttons. No change needed.
- **My first detector run produced a false positive** (`BoatTouchControls` ↔ `InventoryHud`) because it
  forced every HUD visible at once, ignoring that the hotbar hides in a control seat. The harness now
  models per-state gating — a detector that doesn't invents collisions, and invented collisions get
  "fixed", which moves real UI for no reason.

## 4. Portrait — locked to landscape

New `sync/StarterPlayer/StarterPlayerScripts/UI/Orientation.local.luau` sets
`PlayerGui.ScreenOrientation = LandscapeSensor`.

Portrait was broken in two independent ways, both documented in that file: square touch buttons
overflow their 0.19-wide holder when `H > W`, and `RiverProgress`'s `MinSize = 210px` clamp forces it to
**52% of the screen width** on a narrow viewport, colliding with the currency chips. The readability
clamp itself causes the collision, so it can't be tuned away without making the bar unreadable.

Set from a **script**, not on `StarterGui`, because `StarterGui` is not in this repo's auto-sync set —
a property set there would live only in the `.rbxl`, invisible to git and to review.

*(Uses `LandscapeSensor`, not `LandscapeLeft`: the player still picks which way up the phone is.)*

## 5. Noise on touch — shortened, nothing cut

- `ZoneBanner` hold **2.6 s → 1.8 s** on touch.
- `CrewToast` **3 → 2** concurrent rows on touch — the stack's base sits at y 0.80, exactly where the
  throttle buttons begin, so a third row grew upward from a base already flush against the thumb.
- `ObjectiveHud` — **no change needed**; the tray component already defaults to collapsed.

## 6. What is NOT proven — read this before publishing

**Multi-touch is unverified on real hardware.** Studio's Device Emulator is single-pointer, and a
desktop Play session reports `TouchEnabled = false`, so `TouchControls` never builds there at all. §2 is
correct by construction and its state machine is regression-tested, but *two thumbs on glass* has not
happened. Only a phone can confirm it.

**Finding #0004 (default VehicleSeat D-pad) is still open**, for the same reason. Updated with the
investigation rather than closed on a guess.

**→ The one human step left:** open the place on your phone, sit in the DriverSeat, and
1. hold throttle **and** steer simultaneously through a bend — both must register;
2. slide a thumb off the throttle mid-hold — the boat must stop accelerating;
3. check that **only one** set of controls is on screen (settles #0004).

## 7. Files changed

| File | Change |
|---|---|
| `sync/ReplicatedStorage/RunUI/RunComponents.luau` | `touchButton`: `layoutOrder` param; per-`InputObject` input; service-level release |
| `sync/StarterPlayer/StarterPlayerScripts/Boat/TouchControls.local.luau` | `SortOrder` on both layouts; explicit layout orders |
| `sync/StarterPlayer/StarterPlayerScripts/UI/HealthHud.local.luau` | Touch reflow clear of the steer buttons |
| `sync/StarterPlayer/StarterPlayerScripts/UI/HudClient.local.luau` | Vitals 0.5 → 0.55 |
| `sync/StarterPlayer/StarterPlayerScripts/UI/UntieButton.local.luau` | Tap floor 44 → 58 |
| `sync/StarterPlayer/StarterPlayerScripts/UI/ZoneBanner.local.luau` | Shorter hold on touch |
| `sync/StarterPlayer/StarterPlayerScripts/UI/CrewToast.local.luau` | 2 rows on touch |
| `sync/StarterPlayer/StarterPlayerScripts/UI/Orientation.local.luau` | **new** — landscape lock |
| `tools/hud-overlap-audit.luau` | **new** — regression harness |

`luau-analyze.sh` clean (exit 0) across the whole GAME tree.

## 8. Queue changes

- **todo #0014** (custom mobile boat controls before publish) — **resolved**.
- **finding #0004** (default D-pad) — **still open**, updated with why Studio can't settle it.
- **finding #0006** (touch fires the weapon on any tap-to-look) — **new**, logged during this job,
  deliberately out of scope: it needs a dedicated fire button, which is a new control, not a fix.

## 9. Follow-ups worth a job

1. **The phone sign-off in §6** — before publish.
2. **Lobby place** — needs the same landscape lock and its own mobile audit (plus finding #0005).
3. **Finding #0006** — dedicated touch fire button / drag-vs-tap discriminator.
4. **Portrait support**, if ever wanted, is now a deliberate design job rather than a constraint tweak.
