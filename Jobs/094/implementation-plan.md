# Job #094 — Implementation plan

**Project**: `roblox.jungle` · **Place**: GAME only (`sync/`) · **Status**: awaiting agreement

Intake: [intake.md](intake.md). Skills consulted: `roblox-ui`, GROUND-RULES §3/§6, GAME.md
§"Platform & input", STYLEGUIDE §6.10/§6.11.

**Studio target (verified, read-only probe):**
`Last River COOP Game` — PlaceId **138141472932347**, studio id `9c07cff7-…fdb0`
(`StarterPlayerScripts = Boat, Combat, UI`). The other connected instance (`Place1`,
PlaceId 114309626266505, `LobbyClient, UI`) is the **LOBBY** and is **out of scope** — nothing in
this job touches it.

---

## 1. Root cause of the turn bug — CONFIRMED, not hypothesised

The intake's hypothesis A was right about the symptom and **wrong about the mechanism**, which
matters because the fix it proposed would not have worked.

A non-destructive probe (built the exact structure in `CoreGui`, measured, destroyed itself) returned:

```
SortOrder = Enum.SortOrder.Name          <-- the actual default
creation order: 1st = LEFT-arrow(-1)   2nd = RIGHT-arrow(+1)
LEFT-arrow(-1)   AbsolutePosition.X = 227    LayoutOrder = 0
RIGHT-arrow(+1)  AbsolutePosition.X =  39    LayoutOrder = 0
>>> button physically on the left = RIGHT-arrow (INVERTED)
```

`UIListLayout.SortOrder` defaults to **`Enum.SortOrder.Name`**, not `LayoutOrder`. The buttons are
named from their glyph (`"Touch_" .. glyph`), and `▶` (U+25B6) sorts before `◀` (U+25C0) — so the
**right-turn button renders on the left**. The steering maths, the remote path and the server are all
correct; only the on-screen order is wrong. Hypothesis B (camera inversion) is ruled out.

> **Correction to the intake:** it proposed "set an explicit `LayoutOrder`". That alone **would not
> have fixed anything**, because with `SortOrder = Name` the engine ignores `LayoutOrder` entirely.
> Both properties must be set.

**Why throttle feels fine:** `▲` (U+25B2) sorts before `▼` (U+25BC), which happens to be the intended
order. It is correct by luck and would break the moment anyone changed a glyph.

**Why only this file:** every other layout in the game tree sets `SortOrder = LayoutOrder` explicitly
(10 call sites). `TouchControls.local.luau`'s two layouts are the **only** ones in `sync/` that
don't — a clean, narrow, one-file root cause.

## 2. The portrait collision is worse than the intake's arithmetic showed

`RiverProgress` carries `UISizeConstraint.MinSize = (210, 34)`. On a narrow viewport its `0.36` scale
box is **clamped wider**: at 400px wide, `0.36 × 400 = 144px` → forced up to 210px = **52.5% of the
width**, centred, spanning `x 0.238–0.762`. The currency chips are right-aligned from `0.985` and hug
their own text, so a two-chip row easily reaches back past `0.6`. That is a **large** overlap, not the
3.5% the scale maths predicted — and it is caused by the very `MinSize` clamps that exist to keep
things readable.

In **landscape** the same pair is fine: the chips hug right and never reach `RiverProgress`. The
exception is a six-figure Gold balance, where the chip widens leftward — worth one check.

**This is the argument for the orientation decision below**: locking landscape deletes the entire
failure mode rather than engineering around it.

## 3. Decisions (agreed via wizard)

| # | Question | Decision |
|---|---|---|
| 1 | `UIListLayout` tie-break | **Settled empirically** — defaults to `Name`. Fix needs `SortOrder` **and** `LayoutOrder`. |
| 2 | Portrait | **Lock to landscape.** Removes the §2 failure mode outright. |
| 3 | Health bar vs steer buttons | **Move it on touch** — health is mandatory at-a-glance (§6.11) and you can be boarded while driving, so hiding it is the wrong trade. |
| 4 | Global `UIScale` | **No.** Per-element scale plus the existing size constraints are sufficient; a global knob would fight the clamps that already exist. Revisit only if the audit finds density problems a per-element fix can't reach. |
| 5 | Noise reduction | **Shorten + collapse, cut nothing.** A mobile player sees the same game, quieter. |

## 4. Workstreams

### WS1 — Fix the boat touch controls *(the reported bug)*

**Files:** `sync/ReplicatedStorage/RunUI/RunComponents.luau`,
`sync/StarterPlayer/StarterPlayerScripts/Boat/TouchControls.local.luau`

1. **Order (the actual fix).** Set `SortOrder = Enum.SortOrder.LayoutOrder` on both `steerLayout` and
   `throttleLayout`, add a `layoutOrder` parameter to `RunComponents.touchButton`, and assign it in
   `makePair` (first = 1, second = 2). Both halves are required.
2. **Do not leave the next one to luck.** Add a header note in `touchButton` stating that names derive
   from glyphs and therefore must never be relied on for order.
3. **Multi-touch (intake §B).** Replace `MouseButton1Down` / `MouseButton1Up` / `MouseLeave` with
   per-`InputObject` tracking: `GuiObject.InputBegan` / `InputEnded` filtered to
   `Enum.UserInputType.Touch` **and** `MouseButton1` (PC keeps working), storing the owning
   `InputObject` per button so two thumbs are independent. Add a `UserInputService.InputEnded`
   fallback so a finger lifted *off* the button still releases it — closing the latched-throttle hole
   the current `MouseLeave` guard only half-covers.
4. **Landscape lock.** Restrict the place's supported orientation to landscape (per decision 2).
5. **Finding #0004** — determine in the emulator whether Roblox's default VehicleSeat D-pad still
   draws alongside ours. If it does: investigate the `PlayerModule` `VehicleController`. Resolve or
   re-scope the finding either way; do not leave it open by silence.

### WS2 — Resolve the overlaps

**Files:** `HealthHud`, `RiverProgress` / `CurrencyHud`, `CrewToast`, `AdminClient`, `ObjectiveHud`

1. **Health bar (overlap #1, confirmed real).** On `TouchEnabled`, raise it clear of the steer
   buttons' top edge (`y 0.80`). Landscape-only simplifies the sums.
2. **Top row (overlap #2).** Landscape-lock resolves the portrait case. Still verify the six-figure
   Gold case in landscape, and reconcile the stale comment in `StagingHint` which asserts the currency
   chips start at `0.7` when the row frame actually starts at `0.645`.
3. **CrewToast / throttle (#6).** Zero gap at `y 0.80`. Add margin.
4. **AdminClient launcher (#4, dev-only)** and **ObjectiveHud expanded (#5, unknown)** — resolve
   whatever the detector reports at max objective count.
5. Re-run the detector after each change; **no overlap is "fixed" until the harness says so.**

### WS3 — Mobile audit sweep

Every `ScreenGui` in `sync/` against the roblox-ui checklist: scale positioning, `UIAspectRatioConstraint`
+ `UISizeConstraint`, `TextScaled` + `UITextSizeConstraint`, safe area, tap-target size. Fix what fails.

Two things the read-only pass already flagged:
- **`UISizeConstraint.MinSize = 58,58`** on a touch button inside a scale-sized holder can force the
  button larger than its parent on small viewports. Add `MaxSize`, or drive the holder from the constraint.
- **Only `TouchControls` branches on `TouchEnabled`** — no HUD adapts density for touch. WS4 changes that.

### WS4 — Noise reduction on touch *(shorten + collapse, cut nothing)*

Behind a single shared `isTouch` check so the policy is one decision, not fifteen:
- `ZoneBanner` / `StagingHint` — shorter hold, tighter copy.
- `CrewToast` — fewer simultaneous rows on touch (it also sits right above the throttle thumb).
- `ObjectiveHud` — start collapsed on touch (§6.11 already endorses this).
- Audit remaining hint/subtitle text for phone-length wording.

Everything stays reachable. Nothing is removed.

## 5. Verification harness

A reusable `execute_luau` script — **kept in the repo as a regression check**, not a throwaway:

- Walk every `ScreenGui` in `PlayerGui`; collect each **visible** `GuiObject`'s `AbsolutePosition` /
  `AbsoluteSize`.
- **Ignore pure holders** — a fully transparent `Frame` with no visible content is not a collision.
  (This matters: `CurrencyHud`'s row frame is `0.34` wide but its chips hug the right edge. Testing
  frames rather than content would produce a false positive here and hide the real portrait failure.)
- Report every intersecting pair, plus every tap target under the thumb-size floor.
- Run per state × per resolution; output is a **table, not a judgement**.

**State matrix:** staging (ashore) · driving (seated) · gunner seat · carrying cargo · downed ·
dock shop open · run results.
**Resolution matrix:** landscape phone · tablet · small phone · desktop. *(Portrait is dropped by
decision 2 — the lock is what makes that legitimate.)*

**Protocol per ground rules + memory:** verify by read-back **and** `screen_capture`, never by
assumption; reset `Camera.CameraType = Custom` after any positioned capture so Edit navigation isn't
left locked; `execute_luau` runs in a separate Luau context, so verify through shared Instances rather
than module internals.

## 6. What I need from you

1. **Studio free for a playtest window** — WS1/WS2 verification needs `start_stop_play` on the GAME
   place with the Device Emulator. Tell me when it's convenient; I won't enter Play unannounced.
2. **A real-phone check before publish** (see §7). I'll say exactly what to look for.
3. **Review + commit** — I don't commit (ground rule §1).

## 7. Risks and what this plan cannot prove

- **Multi-touch cannot be verified in Studio.** The Device Emulator emulates **one pointer**. WS1.3 —
  the most important fix — will be made correct by construction and reasoned through, but *proven*
  only on a real device. This is a known gap, stated up front rather than discovered at publish.
- **Finding #0004** (default D-pad) has the same limitation: the emulator is better evidence than
  desktop Play, but a phone is the final word.
- **Landscape lock is a product decision with a real cost** — portrait players get an orientation
  prompt instead of a game. Recorded as deliberate, not incidental.
- **WS3 is open-ended by nature.** If the sweep uncovers something large, I'll bring it back rather
  than expanding scope silently.

## 8. Out of scope

- The **LOBBY** place (`lobby/sync/`) — including finding #0005.
- **Finding #0006** (touch fires the weapon on any tap-to-look) — real, but a new-control design
  change, logged during this job's investigation and deliberately left for its own job.
- New on-screen buttons for fire/interact/drop.

## 9. Order of work

1. Baseline: Play + Device Emulator, capture all states, run the detector → the "before" table.
2. WS1 (controls) → re-verify, including the direction read-back.
3. WS2 (overlaps) → re-run detector across the matrix.
4. WS3 (audit sweep) → fix → re-run.
5. WS4 (noise) → capture the first 30s of a run; compare chrome-vs-river against baseline.
6. `final-summary.md` + `changelog.md`; close todo #0014 and finding #0004.
