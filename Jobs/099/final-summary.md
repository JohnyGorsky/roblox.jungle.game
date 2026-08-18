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

---

# ADDENDUM — the Device Emulator session (same day)

The user pointed out the Device Emulator was available. **That changed everything**, and it is the most
important lesson of this job: I had spent four jobs deferring mobile questions to "a real phone" while
the emulator — documented in our own `roblox-studio` skill, which says *"use it to verify every
HUD/menu on mobile"* — sat one click away. **The capability was written down and I did not use it.**

## What the emulator revealed immediately

**`Camera.ViewportSize` = 666 × 374** (usable **666 × 316** after insets), where the device screenshot
was ~1536 × 710. This confirmed the DPI hypothesis and made it concrete: **a pixel `MinSize` is ~2.3×
larger relative to the canvas than any desktop test suggests.**

**Roblox's own controls are real colliders no harness of ours knew about:**
`ThumbstickStart x 29..103, y 223..297` · `JumpButton x 571..641, y 226..296` ·
`DynamicThumbstickFrame` reserving the entire bottom-left quadrant.

## What was fixed as a result

**LOBBY**
- Rail: one column of five → **canvas-driven grid**, then → **collapsed behind one menu button** with a
  scrim, once measurement proved five persistent badges cannot coexist with the thumbstick. Badge 59px,
  panel 52% of viewport, top edge clear of the Roblox topbar.
- The `MaxSize` width cap (110px, meant for a narrow rail) was silently strangling the new multi-column
  overlay to 110px wide — found by measuring the *open* panel rather than trusting the layout maths.
- Centre hint **hidden on touch** (user request), admin launcher **hidden on touch**.
- Top-right cluster restyled: a new **`chip` button variant** (panel fill + accent stroke) so the
  balance, the `+` and the menu read as one cluster instead of three competing colour languages —
  gold means *progression* and green means *boat/mechanical*, so neither fitted a Robux buy or a shop menu.
- **Icon-only buttons now render their icon full-size and centred.** The existing icon path assumed a
  text+icon row (32px left padding, 0.62 height), which on a 58×58 square produced the reported "tiny
  graphic in an empty box".

**GAME**
- Hotbar moved out of the thumbstick (x 10..250 → **x 150..390**).
- Health, vitals, cargo and the role chip became a **top-left column** (rows at y 0.02 / 0.115 / 0.30 /
  0.44), leaving the bottom band to controls. The Job #094 seat-reflow is superseded and now a no-op.
- Staging hint **hidden on touch** (user request; it was also clipped and collided with the new column).
- Admin launcher **hidden on touch**.

## Verified on the touch canvas

**LOBBY: no overlaps, Roblox's controls included.** **GAME: no overlaps, thumbstick included.**
All tap targets ≥ 58px. Analyzer clean on both trees.

## Still device-only

**Multi-touch.** The emulator is single-pointer, so "throttle + steer together" (Job #096) remains the
one honest reason to want hardware — findings #0004/#0006/#0007 and todo #0058.

## Skill updated

`roblox-studio` SKILL.md now leads its testing section with an emphatic emulator block — what it gives
(TouchEnabled, real ViewportSize, GetGuiInset, TouchGui rects), the ViewportSize-vs-screenshot trap, the
bottom-left reservation, and the three ways UI measurement lied during these jobs (clones don't run
runtime code; forcing Visible changes layout; TextFits is unreliable off-screen).

---

# ADDENDUM 2 — the probe caught what I had already called "clean"

Writing the `mobile` skill's diagnostic probe and running it immediately found two defects in work I had
just verified and reported as passing:

1. **I measured against the wrong rectangle.** I cleared the hotbar of `ThumbstickStart` (the resting
   dot, x 29..103) and declared it clean. The real reservation is `DynamicThumbstickFrame` — **x −100..266**
   — because the dynamic stick spawns wherever the thumb lands. Slots 1–3 were still inside it.
2. **I never checked the hotbar's own tap size.** Slots were **46×46**, under the 58 px floor, on the
   control used to switch weapons mid-fight.

**Fix:** the hotbar moved to x=276 (genuinely clear of the frame) and wrapped into a **3×2 grid of 58 px
slots**. Six slots in a single row need 388 px; the bottom band only has ~260 px between the stick
(ends x266) and the fire button (starts x526), so a row cannot fit at full size — the same wrap answer
the lobby rail needed.

Also: the bandage chip's label rendered as **"BANDA"**, truncated mid-word, in the new compact column.
Dropped to icon + number on touch — a cut word teaches less than no word.

**Hiding on mobile took three attempts.** `AdminLauncher` and `StagingHint` each survived a first fix
because something re-enabled them: the element's own `refresh()` driver, and `IntroHudGate`'s
`setHudEnabled(true)` after the cold open. Only an early `return` placed **before** the ScreenGui is
created holds. An earlier "verified hidden" reading was taken *during* the intro, before the re-enable
fired — true, and meaningless.

**Final verified state (GAME, real touch canvas):** zero collisions — ours against each other *and*
against every Roblox control — and every tap target ≥ 58 px.

**The meta-point:** three separate "verified clean" claims in this job were wrong because of *how* I
measured, not *what* I built. That is why the new `mobile` skill leads with measurement protocol rather
than layout advice, and why its probe checks against every `TouchGui` child instead of the obvious one.

---

# ADDENDUM 3 — how the validation itself was wrong, and what fixed it

Challenged on *how* the "zero collisions" claim was validated. It did not survive the question.

**The checker had a blind spot.** It compared only pairs from **different** ScreenGuis
(`if a.owner ~= b.owner`), so two elements colliding *inside* one HUD — vitals against cargo in
`BoatHud`, say — could never be reported. It printed a clean result while measuring a fraction of the
screen.

**Corrected, it found 31 raw overlaps.** All 31 turned out to be *intentional layering*: a gauge's
`Value` text sits on its `Fill`; a hotbar slot's `Key` number sits on its `Art`; Roblox's own
`ThumbstickStart` sits on `ThumbstickEnd`. So a naive "any overlap is a bug" check is equally useless —
it cries wolf on every well-composed component.

**The working rule** (now in the probe): compare **every** pair, then flag only those whose nearest
common ancestor is a **top-level HUD block or higher**. Things inside one small component are
composition; two components on top of each other are a bug. Validated: **31 raw → 0 real**, which also
proves the filter is doing work rather than trivially returning zero.

**And the rule that matters most:** numbers are necessary, never sufficient. Every wrong "verified
clean" in this job was wrong *numerically first* — the script passed and the screenshot disagreed.
Clipped text, placeholder icons and "reads as an empty box" are invisible to a rectangle checker and
obvious in one picture. `mobile` SKILL.md §4b now says so explicitly.

## Hotbar footprint

Asked how the two hotbar rows could cover less screen. Fixed by removing what should not have been
drawn rather than by shrinking what should: on touch the bar now renders **only populated slots**, not
every unlocked one.

| | before | after |
|---|---|---|
| slots drawn | 6 (4 empty) | **2 — what is carried** |
| block | 190 × 124 | **124 × 58** |
| share of screen | 9.5% | **2.9%** |
| slot size | 58 px | 58 px (unchanged) |

Verified on the touch canvas: clear of `DynamicThumbstickFrame`, both slots >= 58 px, and confirmed by
screenshot as well as by measurement.

---

# ADDENDUM 4 — objectives tray, and three more verification failures

**Reported:** the objectives tray overlapped the currency chips. **Measured:** 150 x 10 px overlap — the
tray at y 30..62 against chips at y 6..40. Caused by this job's own #0009 fix, which raised the collapsed
height to clear the thumb floor and so pushed the card up into the row above.

**Fixed on touch:** moved lower (y 0.095 -> 0.17), narrowed (0.17 -> 0.10 wide), and the summary
shortened from "OBJECTIVES  0/4" to "0/4". The count is kept deliberately — the ask was "just icon not
text", and the word is what made it wide, but a bare clipboard with no number is a mystery button and a
count is the whole point of a collapsed summary. Now 76 x 58 at x 580..656, y 54..112: clear of the
currency row and of every other visible element.

**Three more ways verification failed, all now in the `mobile` skill:**

1. **A transparent button escaped the tap-target audit.** The tray's `Header` is a clear 150x32
   `TextButton` covering its whole card — under the 58 px floor, and invisible to a paint-filtered scan.
   Tap-size checks must cover every `GuiButton`, painted or not. The probe now does.
2. **A pixel `MinSize` silently overrode a scale change.** Narrowing `collapsedSize` to 0.10 did
   nothing: `clamp.MinSize = (150, 32)` clamped it back. The edit was right; something else won. Always
   read back `AbsoluteSize` after changing a size.
3. **The tray was measured and screenshotted while `Visible = false`.** The numbers looked fine and the
   picture showed nothing — neither meant anything. Re-verified with it actually on screen: measured
   clear *and* visually confirmed.

The min size is now touch-aware at (76, 58) — narrower for the shorter label, and taller so the card,
which IS the button that expands the objective list, finally clears the thumb floor.
