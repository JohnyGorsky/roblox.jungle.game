# Job #097 — Implementation plan

**Project**: `roblox.jungle` · **Place**: GAME only (`sync/`)
**Status**: IMPLEMENTED — see final-summary.md · was AGREED — the approach is the one validated in [Job #095](../095/final-summary.md) and
approved when this work was chosen.

Intake: [intake.md](intake.md) · Baseline measured live, GAME place, PlaceId 138141472932347.

---

## 1. The change

Two lines in `sync/ReplicatedStorage/UI/Components.luau`, both already proven in the lobby:

| Line | From | To | Governs |
|---|---|---|---|
| ~646 | `closeFloor.MinSize = (40, 40)` | `(58, 58)` | the `Close` on every modal |
| ~210 | `floor.MinSize = (0, 34)` | `(0, 58)` | **every** button, incl. every shop row's action |

Plus one comment correction in `sync/ReplicatedStorage/RunUI/RunComponents.luau` (todo #0057): its
header claims `UI/` is "byte-identical across the two trees", which a `diff` disproves — #095's changes
to the lobby copy have widened the gap further, so leaving the claim would actively mislead.

**Fix at the button's own constraint, not at the call site.** #095 first tried adding a second
`UISizeConstraint` where the shop row builds its button; it silently did nothing, because **two
`UISizeConstraint`s on one object do not stack** — only one applies. That lesson transfers directly.

## 2. Why 58

The number is this game's own thumb floor, already used by `RunComponents.touchButton` for the driver's
controls and applied throughout #094/#095. Roblox publishes no official minimum (see `roblox-ui`), so
consistency with our own choice is the argument, not an external standard.

## 3. The real risk, and how it is checked

The lobby is entirely menus. **This tree is not** — the same floor now applies to in-run HUD buttons
(`UntieButton`, `DownedHud`'s revive, `RunClient`'s results rows), where a taller button could overflow
a short container or create a new overlap.

Verification, in order:
1. **Re-measure the modals** (`ScreenGui`-only enable — see intake §Method) → every `Close` and buy
   button ≥ 58.
2. **Re-run `tools/hud-overlap-audit.luau`** across the states from #094 and #096 — driving, gunner,
   on-foot, aboard, moored — at the full resolution matrix. Must stay at zero overlaps and zero
   undersized targets.
3. **`luau-analyze.sh`** clean.
4. **`screen_capture`** of the in-run HUD to confirm nothing visibly burst its container.

If step 2 regresses, the global floor is the wrong instrument and the fix narrows to the panel/row
components only — decided on the evidence, not now.

## 4. Out of scope

- `InventoryHud/DropButton` and `ObjectiveHud/Header` — they appeared only in a **distorted** baseline
  (intake §Method). If step 2 shows them genuinely undersized, they become a **finding**, not an
  unannounced addition here.
- The LOBBY tree — done in #095.
- Anything needing a device; this job is fully verifiable in Studio.

## 5. Order of work

1. Two floors + the comment → 2. analyzer → 3. modal re-measure → 4. full harness sweep →
5. screenshot → 6. summary + changelog; close finding #0008 and todo #0057.
