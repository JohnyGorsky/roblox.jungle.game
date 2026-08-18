# Job #097: GAME modals — thumb-sized close and buy buttons

**Project**: `roblox.jungle`
**Place**: **GAME only** (`sync/`)
**Created**: 2026-08-18
**Status**: Complete

## Why this job exists

[Job #095](../095/final-summary.md) fixed the lobby's modal tap targets and, in doing so, found that the
**GAME** tree carries the same code and the same problem — logged as **finding #0008**.

Job #094 audited the GAME place but swept only the **always-on HUD**: its state matrix never opened a
modal panel, so every button inside one went unmeasured. This job closes that gap.

Closes **finding #0008** and **todo #0057**.

## Measured baseline (live, GAME place, viewport 1978×1313)

Measured by enabling each modal's `ScreenGui` and nothing else — see §"Method" below for why that
distinction matters. **A phone is roughly half this tall, so these are best-case numbers.**

| Panel | Under the 58 px thumb floor |
|---|---|
| `DockShop` | `Close` **53×53** · six purchase buttons **215×34** |
| `RobuxShop` | `Close` **55×55** · six Robux buttons **224×34** |
| `RunResults` | `Close` **40×40** |
| `AdminPanel` | `Close` **44×44** · six buttons **877×44** *(dev-only)* |

Both causes are the same two lines #095 already fixed in the lobby copy:

- `sync/ReplicatedStorage/UI/Components.luau:646` — `closeFloor.MinSize = (40, 40)`
- `sync/ReplicatedStorage/UI/Components.luau:210` — `floor.MinSize = (0, 34)` on **every** button

The 34 px floor is the one that matters most: it governs every shop row's action button, which in this
tree includes the **dock purchases** (in-run spending) and the **Robux rows** (real money).

## Method note — why the first baseline was wrong

The first pass forced every `ScreenGui` **and every descendant** `Visible = true` to reach the modals.
That reported hotbar slots at **57×57**, apparently one pixel under the floor. It was an artifact:
forcing normally-hidden children into a `UIListLayout` changes the flow. Measured naturally the same
slots are **76×76** and pass comfortably.

**The faithful method is to enable the `ScreenGui` only** — a panel's own children are already in their
natural `Visible` state. Recorded here because it nearly produced a fix for a problem that did not
exist.

## Scope

**In:** the two floors in `sync/ReplicatedStorage/UI/Components.luau`, plus the stale cross-tree comment
in `sync/ReplicatedStorage/RunUI/RunComponents.luau` (todo #0057), which lives in this tree.

**Out:** anything the numbers above tempt but the finding does not cover —
- `AdminLauncher` / `AdminPanel` are **dev-only**; they get fixed for free by the shared floor, and no
  further work is spent on them.
- `InventoryHud`'s `DropButton` and `ObjectiveHud`'s tray `Header` appeared in the *distorted* baseline
  and are **not** confirmed problems. If the post-fix sweep shows them genuinely undersized in a natural
  state, they become a finding, not a silent addition to this job.

## Risk to watch

The lobby is all menus; **this tree is not.** Raising the global button floor to 58 also affects in-run
HUD buttons — `UntieButton`, `DownedHud`'s revive button, `RunClient`'s results rows. A taller button
inside a short container could overflow it or create a new overlap.

This is directly testable: [`tools/hud-overlap-audit.luau`](../../tools/hud-overlap-audit.luau) already
covers the in-run states from #094 and #096, so the fix has to be proven not to reopen anything those
jobs closed.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] Final summary + changelog written
