# Job #097 — Final summary

**Project**: `roblox.jungle` · **Place**: GAME (`sync/`) · **Status**: complete
**Studio**: `Last River COOP Game`, PlaceId 138141472932347

Intake: [intake.md](intake.md) · Plan: [implementation-plan.md](implementation-plan.md)

---

## 1. What changed

Two floors in `sync/ReplicatedStorage/UI/Components.luau`, both the fix already validated in Job #095:

| | Before | After |
|---|---|---|
| `Components.panel` close button | `MinSize (40, 40)` | `(58, 58)` |
| `Components.button` (every button, incl. every shop row action) | `MinSize (0, 34)` | `(0, 58)` |

Plus the stale cross-tree claim in `RunComponents.luau` corrected (**todo #0057**): its header said `UI/`
is "byte-identical across the two trees", which a `diff` disproves and #095 widened further. It now says
what is actually true — same vocabulary in both trees, not a file you can copy wholesale.

## 2. Before → after, measured live

| Panel | Before | After |
|---|---|---|
| `DockShop` | `Close` 53×53 · six purchase buttons **215×34** | all ≥58 |
| `RobuxShop` | `Close` 55×55 · six Robux buttons **224×34** | all ≥58 |
| `RunResults` | `Close` **40×40** | ≥58 |
| `AdminPanel` | `Close` 44×44 · six buttons 877×44 | all ≥58 |

The 34 px floor was the one that mattered: it governed the **dock purchases** (in-run spending) and the
**Robux rows** (real money). And these were measured at 1978×1313 — **a phone is about half that tall**,
so they were best-case numbers.

## 3. The risk was checked, not assumed

The lobby is all menus; this tree is not, so a 58 px floor could have burst a short in-run container.
Verified explicitly:

- **No button overflows its row** in any modal.
- **`UntieButton` 160×58, `DownedHud` revive 409×62** — comfortable, no overflow.
- **Full regression matrix** — driving · gunner · on-foot · moored, at four viewports: **zero overlaps
  everywhere**. Nothing #094 or #096 closed has reopened.
- `luau-analyze.sh` clean; `screen_capture` shows the in-run HUD unchanged.

## 4. A measurement mistake worth recording

The first baseline forced every `ScreenGui` **and every descendant** visible to reach the modals. It
reported hotbar slots at **57×57** — one pixel under the floor, and very nearly a fix for a problem that
does not exist. Forcing normally-hidden children into a `UIListLayout` changes the flow; measured
naturally the same slots are **76×76**.

**The faithful method is to enable the `ScreenGui` only** — a panel's own children are already in their
natural `Visible` state. This is the second harness artifact this mobile pass has produced (the first
was #095's imperatively-sized `+` button), and both share one lesson: *the measurement apparatus can lie,
so a surprising number gets re-measured a second way before it gets fixed.*

## 5. Scope held

Two genuinely undersized controls turned up that are **not** `Components.button`, so the shared floor
does not reach them: `ObjectiveHud`'s tray header (**150×32**) and `InventoryHud`'s `DropButton`
(**160×21**). Both are scale-derived — `collapsedSize` 0.045 and the HandsFull card 0.036 of screen
height — so they are real, not artifacts, and get worse on a phone.

They were logged as **finding #0009**, not folded into this job. #0008 was scoped to the modal
close/buy buttons; widening it silently would have made the job's own verification meaningless.

## 6. Files changed

| File | Change |
|---|---|
| `sync/ReplicatedStorage/UI/Components.luau` | close floor 40→58; button floor 34→58 |
| `sync/ReplicatedStorage/RunUI/RunComponents.luau` | corrected the stale byte-identical claim |

## 7. Queue

- **finding #0008** — **closed**.
- **todo #0057** — **closed**.
- **finding #0009** — **new**: in-run tray header + drop button under the floor.
