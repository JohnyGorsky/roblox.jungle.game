# Job #095: Lobby mobile-ready pass — landscape lock, overlap audit, font cleanup

**Project**: `roblox.jungle`
**Place**: **LOBBY only** (`lobby/sync/`)
**Created**: 2026-08-18
**Status**: Complete

## Why this job exists

[Job #094](../094/final-summary.md) made the **GAME** place mobile-ready and deliberately stopped at the
place boundary (GROUND-RULES §1 — a job never crosses it without permission). This is the other half.

It matters more than "the other half" suggests: **the lobby is the first thing a mobile player ever
sees.** A player who can't read the lobby never reaches the river to find out the boat controls got
fixed.

Closes **finding #0005** (leftover Gotham fonts in the lobby tree).

## Requirements / goal

1. **Lock landscape**, matching the game place.
2. **Run the overlap harness** across the resolution matrix; fix what it reports.
3. **Mobile-first sweep** of every lobby GUI — scale, aspect/size constraints, `TextScaled`, safe area,
   thumb-sized tap targets.
4. **Close finding #0005** — six `Enum.Font.Gotham*` references still in the lobby tree.

## Investigation — read-only pass over `lobby/sync/`

### A. No orientation lock at all

`grep -rn "ScreenOrientation" lobby/` returns **nothing**. Job #094 locked the GAME place to
`LandscapeSensor`, so as it stands a mobile player browses the lobby in portrait and is then flipped to
landscape on teleport. Inconsistent, and it means the lobby's layouts are being exercised in an
orientation nothing has ever tested.

### B. A top-bar collision that looks real

| Element | Geometry | MinSize |
|---|---|---|
| `TopBar` left block | `x 0.012–0.312, y 0.02–0.105` | `(210, 52)` |
| `LobbyClient` panel | `x 0.28–0.72, y 0.02–0.105` (anchor 0.5) | `(260, 54)` |

**Overlap `x 0.28–0.312`** at the same vertical band. At 1136 px wide that is ~36 px of real estate,
and it follows **exactly the failure mode Job #094 found** between `RiverProgress` and `CurrencyHud`:
two independently-clamped elements sharing a row, where the pixel `MinSize` floors (here 210 and 260)
push them into each other as the viewport narrows, faster than the scale values suggest. The scale
maths alone understates it — which is why this needs the harness, not arithmetic.

**To be confirmed empirically**, not fixed on the strength of this table.

### C. Finding #0005 — six Gotham references

| File | Lines |
|---|---|
| `lobby/sync/ReplicatedFirst/LobbyLoading.local.luau` | 84, 96, 132 |
| `lobby/sync/ServerScriptService/Progression/RankServer.server.luau` | 228, 241, 266 |

The finding already records the right treatment for each, and the two files are **not** the same case:

- **`LobbyLoading`** runs from `ReplicatedFirst` and cannot `require` Theme from `ReplicatedStorage`
  without blocking on the very replication it exists to hide. It gets the same treatment `GameLoading`
  already has: hand-copied palette values plus a header note explaining why it is not a `require`.
- **`RankServer`** builds its GUI labels server-side and **can** require Theme. It should.

### D. Surfaces to audit

`AdminClient` · `EntryBar` · `ModulesShop` · `PaintShop` · `RetentionClient` · `RobuxShop` ·
`SkillShop` · `TeleportGui` · `TopBar` · `UIClick` · `LobbyClient` · `LobbyLoading`

Worth particular attention:
- **`PaintShop`** uses a `UIGridLayout` (`CellSize` `0.31 × 0.44`) — grids are the layout most likely to
  break at an untested aspect, and this is the only one in either tree.
- **The shops** (`ModulesShop`, `RobuxShop`, `SkillShop`, `PaintShop`) are `ScrollingFrame` lists with
  `Theme.rowHeight` rows — check row height against the thumb floor, since these are purchase flows and
  a mis-tap costs the player real money.
- **`AdminClient`** launcher sits at `0.98, 0.78` with `MinSize (90, 32)` — 32 px is well under the
  58 px thumb floor, though it is dev-only.

## Approach

Reuse [`tools/hud-overlap-audit.luau`](../../tools/hud-overlap-audit.luau) from Job #094 — it was built
to be re-runnable for exactly this. It needs a lobby `AUDIT` list and lobby `STATES`; the measurement
logic (painted leaves, not holder frames) carries over unchanged.

**Note the two-tree gotcha:** the analyzer takes `--lobby`, and `lobby/` has its own
`default.project.json` + `sourcemap.json`. Running the GAME sweep against lobby files reports "Unknown
require" on everything. `bash tools/luau-analyze.sh --lobby`.

## Playtest & verification

Same discipline as #094: Studio on the **LOBBY** place (`Place1`, PlaceId 114309626266505, studio id
`dc3b3837-…4b84` at the time of writing — re-confirm, ids are per-session), harness sweep across the
resolution matrix, `screen_capture` per state, verify by read-back **and** screenshot.

**Same known gap:** the emulator is single-pointer and desktop Play reports `TouchEnabled = false`, so
anything touch-gated needs a real device to confirm. Less critical here than in #094 — the lobby has no
two-thumb input — but the tap-target findings still want one phone check.

## Open questions for the plan phase

1. Does the `TopBar` ↔ `LobbyClient` overlap reproduce in the harness, and does it worsen as the
   viewport narrows the way the `MinSize` floors predict?
2. Which yields — the top bar or the centre panel? (In #094 the equivalent call was made by asking
   which change would shrink a tap target; the same test applies.)
3. Should the lobby lock `LandscapeSensor` (matching the game) or is a portrait lobby actually
   defensible, given the lobby is menus rather than two-thumb driving?
4. Do the shops need bigger rows on touch, given a mis-tap in `RobuxShop` spends real money?

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] Final summary + changelog written
