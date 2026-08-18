# Job #094: Mobile-ready GUI pass: touch controls, overlaps, scale audit

**Project**: `roblox.jungle`
**Created**: 2026-08-18
**Status**: Implemented — pending review + the phone sign-off in final-summary.md §6

## Requirements / goal

Make every **GAME-place** GUI genuinely mobile-ready:

1. **Fix the boat touch controls** — the steer buttons are reported to turn the wrong way, and the
   input layer cannot handle two thumbs at once.
2. **Verify nothing overlaps** — audit every HUD element's rectangle in every state and resolve the
   collisions.
3. **Audit every GUI against the mobile-first checklist** — scale positioning, aspect/size
   constraints, `TextScaled`, safe area, thumb-sized tap targets — and fix what fails.
4. **Cut HUD noise on touch** — a phone screen is small and half of it is under a thumb. Non-essential
   chrome (intro/start messages, hints, toasts, banners) should be quieter or absent on mobile.

Mobile-first is a **standing hard requirement** (GAME.md §"Platform & input", STYLEGUIDE.md §6.10),
so this job is the deliberate audit that requirement has been owed since Job #075 built the HUD.

## Scope (agreed via wizard)

| | |
|---|---|
| **In scope** | The **GAME place** only — `sync/` |
| **Out of scope** | The **LOBBY place** (`lobby/sync/`) — separate Rojo place, separate job (see finding #0005) |
| **Depth** | Controls + overlaps + **full mobile audit of all game GUIs** + mobile noise reduction |
| **Not doing** | Adding *new* touch buttons for actions that are currently tap-anywhere (fire/interact). That is a design addition, not a fix — logged below as a follow-up. |

Closes: **todo #0014** (custom mobile boat controls before publish) and
**finding #0004** (default VehicleSeat D-pad may still draw).

## Investigation — what's already been found

Read-only pass over `sync/` before writing this intake. Everything below is a *hypothesis with
evidence*; the implementation plan confirms each one in Studio before changing code.

### A. The turn buttons — prime suspect: `UIListLayout` tie-break by Name

> **RESOLVED in the plan — read [implementation-plan.md](implementation-plan.md) §1 before acting on this
> section.** The symptom below was confirmed, but the *mechanism* is different: `SortOrder` defaults
> to `Name`, so the fix proposed here ("set an explicit `LayoutOrder`") would **not** have worked on
> its own. Kept as the historical record of the investigation.

[TouchControls.local.luau](../../sync/StarterPlayer/StarterPlayerScripts/Boat/TouchControls.local.luau)
builds the pair in the intended order (left arrow = −1 first, then right arrow = +1), and the
*logic* is correct end-to-end:

- left arrow → `SteerFloat = -1` → `BoatServer` reads `seat.Steer = -1` → `desiredYaw -= s * TURN * …`
  → yaw increases → counter-clockwise → **boat turns left**. Correct.

The suspect is **rendering order, not logic**. `RunComponents.touchButton` names each button
`"Touch_" .. glyph` and **never sets `LayoutOrder`**
([RunComponents.luau:565](../../sync/ReplicatedStorage/RunUI/RunComponents.luau#L565)), so both
siblings sit at `LayoutOrder = 0` and `UIListLayout` breaks the tie by **Name**:

| Glyph | Codepoint | Name | Sorts |
|---|---|---|---|
| right arrow | U+25B6 | `Touch_▶` | **first → drawn LEFT** |
| left arrow | U+25C0 | `Touch_◀` | second → drawn RIGHT |

U+25B6 sorts *before* U+25C0, so the right-turn button renders on the **left** of the pair — exactly
the reported symptom. The throttle pair escapes the same bug only by luck: up (U+25B2) happens to
sort before down (U+25BC), which is the intended order — which is *why* throttle feels right and
steering feels inverted.

**Hypothesis B (fallback):** the boat steers correctly but reads inverted relative to `BoatCamera`.
Ruled in or out by the same emulator test.

**Fix (pending confirmation):** set an explicit `LayoutOrder` — add a `layoutOrder` parameter to
`RunComponents.touchButton` and assign it in `makePair`. Never rely on a name tie-break.

### B. Input layer cannot handle two thumbs (the bigger mobile bug)

`touchButton` binds **`MouseButton1Down` / `MouseButton1Up` / `MouseLeave`**
([RunComponents.luau:609-613](../../sync/ReplicatedStorage/RunUI/RunComponents.luau#L609-L613)).
Roblox routes only the **first** active touch through mouse-emulation events. Consequences on a real
phone:

- **Holding throttle and then pressing steer may not register** — the second thumb has no mouse event
  to fire. Driving a bend requires both at once, so this is core.
- **`MouseLeave` is unreliable for touch** — a thumb sliding off the button can leave the throttle
  latched on with nothing holding it, which is exactly the failure the code's own comment says it is
  guarding against.

**Fix:** track a per-button `InputObject` via `GuiObject.InputBegan` / `InputEnded` filtered on
`Enum.UserInputType.Touch` (keeping `MouseButton1` for PC), plus a `UserInputService.InputEnded`
fallback so a finger lifted off the button still releases it. Confirm the API shape against
`roblox-ui` / `roblox-dev` before writing it.

### C. Overlaps found by rectangle math

Computed from `AnchorPoint` + `Position` + `Size` (scale). **To be confirmed empirically** — the plan
runs a scripted `AbsolutePosition`/`AbsoluteSize` intersection check rather than trusting this table.

| # | A | B | Overlap | Verdict |
|---|---|---|---|---|
| 1 | **HealthHud** bar `x .015–.285, y .803–.845` | **TouchControls** steer `x .02–.21, y .80–.96` | direct | **Real.** HealthHud has *no* seat gating; the steer buttons (DisplayOrder 9) draw over the health bar (DisplayOrder 6) whenever you drive on touch. |
| 2 | **RiverProgress** `x .32–.68, y .022–.084` | **CurrencyHud** `x .645–.985, y .02–.078` | `x .645–.68` | **Likely real** (~3.5% of width, both DisplayOrder 6). CurrencyHud's row is list-laid-out and may not fill its box — verify visually. |
| 3 | **InventoryHud** carry chip `x .015–.215, y .797–.833` | **TouchControls** steer | direct | **Conditional** — only when `Busy` (carrying). Confirm whether you can be seated while carrying. |
| 4 | **AdminClient** launcher `x .88–.98, y .735–.78` | **CrewToast** stack (bottom `.80`) | direct | **Real but dev-only.** Low priority. |
| 5 | **ObjectiveHud** tray expanded (grows down from `y .095`) | CrewToast / throttle | possible | **Unknown** — expanded height scales with objective count. Test at the max count. |
| 6 | **CrewToast** bottom `.80` | **Throttle** top `.80` | tangent | Zero gap, no overlap. Give it breathing room. |

**Checked and clean:** `BoatStatusCard` (ASHORE only) vs `HudClient` cargo (ABOARD only) — mutually
exclusive despite sharing an origin. `InventoryHud` hotbar correctly hides in a control seat.
`UntieButton` / `HudClient` vitals / `RoleChip` / `ZoneBanner` — no collisions.

### D. HUD noise on mobile

A phone gives us roughly a third of the readable area of a monitor, and the bottom corners are under
thumbs. Everything that is *nice to read* on PC competes with everything that is *necessary to see*
on a phone. Candidates to gate, shorten, or move behind a tap on touch — each decided in the plan,
not assumed here:

- **Start/intro messaging** — `StagingHint` (top-centre card, `0.4 × 0.13`), `ZoneBanner`
  (`0.6 × 0.17` full-bleed), `GameLoading` / `IntroFade`. These land exactly where a phone player is
  trying to read the river.
- **Transient toasts** — `CrewToast` stack sits directly above the throttle thumb.
- **Hints** — `InventoryHud`'s drop hint already branches on `TouchEnabled` for its *wording*; the
  precedent for branching on *presence* is there.
- **Persistent readouts** — do fuel/hull/health/cargo/objectives all need to be on screen at once on
  a phone, or does the collapsible-tray pattern (STYLEGUIDE §6.11) apply more aggressively?

The rule to propose in the plan: **on touch, anything that is not a vital or a control is either
shorter, briefer, or collapsed by default.** STYLEGUIDE §6.11 already says heavy panels default
collapsed — this extends the same principle to messaging.

### E. Other mobile-readiness issues

1. **Portrait orientation is untested and probably broken.** The steer/throttle holders are
   `0.19 × 0.16` scale with square (`UIAspectRatioConstraint = 1`) buttons. Button width in scale-x is
   `0.16 × H/W`; in portrait `H > W`, so two buttons plus padding **exceed the 0.19 holder width** and
   clip or overflow. Needs an orientation-aware holder or flex sizing.
2. **`UISizeConstraint.MinSize = 58,58`** on a button inside a scale-sized holder can force the button
   larger than its parent on small viewports. Clamp with `MaxSize` too, or size the holder from the
   constraint.
3. **No global `UIScale` knob** (roblox-ui rule 2) — no single lever to tune HUD density per device.
4. **Nothing but `TouchControls` branches on `TouchEnabled`** — no HUD adapts density for touch.
5. **Combat is tap-anywhere on touch** — `GunClient` / `WeaponClient` fire on any `Touch` `InputBegan`.
   Both correctly honour `gameProcessed`, so HUD taps don't misfire, but tapping to look around fires
   the weapon. Out of scope by the agreed depth → **log as a follow-up finding.**
6. **Finding #0004 — the default VehicleSeat D-pad** may still draw alongside ours on a touch device,
   giving two sets of controls. Must be settled in the emulator.

## Playtest & verification plan (agreed: Studio Device Emulator over MCP)

Claude drives the Studio session via MCP; the human keeps Studio open on the GAME place.

**1. Baseline capture (before any change)**
`start_stop_play` → Device Emulator on a phone preset with touch enabled → `screen_capture` each HUD
state. This is what proves the bugs are real rather than inferred from arithmetic.

**2. Scripted overlap detector (the objective half)**
`execute_luau` walks every `ScreenGui` in `PlayerGui`, collects each **visible** `GuiObject`'s
`AbsolutePosition`/`AbsoluteSize`, and reports every intersecting pair plus every tap target under the
thumb-size floor. Run per resolution preset. The output is a table, not an eyeball judgement — and it
stays in the repo as a re-runnable regression check.

**3. State matrix** — each state captured *and* run through the detector:

| staging (ashore) | driving (seated) | gunner seat | carrying cargo | downed | dock shop open | run results |
|---|---|---|---|---|---|---|

**4. Resolution matrix** — landscape phone, **portrait phone**, tablet, small phone, desktop.
Portrait is the one most likely to fail (§E.1) and the one never yet tested.

**5. Direction test (the actual bug)** — seat the driver, press the left-arrow button, read back
`seat.SteerFloat` **and** the boat's yaw delta via `execute_luau`, and `screen_capture` the result.
This separates "wrong button position" (hypothesis A) from "wrong logic" (B) from "camera reads
inverted" — arithmetic alone cannot.

**6. Noise pass (§D)** — capture the first 30 seconds of a run on a phone preset and judge how much of
the screen is chrome versus river. That screenshot is the argument for what gets cut.

**7. Per ground rules + memory** — verify by *read-back plus screenshot*, never by assumption; and reset
`Camera.CameraType = Custom` after any `screen_capture` that positions the camera, so the user's Edit
navigation isn't left locked.

### What this method genuinely cannot settle — flagged, not hidden

The Device Emulator emulates **one pointer**. It **cannot** test two thumbs at once, so §B — the most
important mobile fix — can only be made *correct by construction* (per-`InputObject` tracking) and
reasoned about, not proven here. Same for finding #0004: the emulator is better than desktop Play, but
a real device is the final word on whether Roblox's own D-pad draws.

**→ Recommended human step before publish:** one Team Test or published-place session on your actual
phone, holding throttle and steer simultaneously through a bend. Claude will state exactly what to look
for. Say the word and I'll promote this from a suggestion to a required sign-off in the plan.

## Open questions for the plan phase

1. Does `UIListLayout` actually tie-break by Name here? (Confirm in Studio — do not ship a fix for a
   cause that wasn't the cause.)
2. Should the health bar move, or hide while driving the way the hotbar does?
3. Portrait: support it properly, or lock the game to landscape?
4. Is a global `UIScale` worth introducing now, or is per-element scale sufficient?
5. Noise (§D): which messages get cut on touch versus merely shortened — and does anything get cut on
   PC too, or is this a touch-only branch?

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] Final summary + changelog written
