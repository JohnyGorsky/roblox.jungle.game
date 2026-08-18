# Job #095 — Final summary

**Project**: `roblox.jungle` · **Place**: LOBBY (`lobby/sync/`) · **Status**: complete
**Studio**: `Place1`, PlaceId 114309626266505

Intake: [intake.md](intake.md) · Plan: [implementation-plan.md](implementation-plan.md)

---

## 1. What was wrong, measured

| Problem | Before | After |
|---|---|---|
| `LobbyHint` ↔ `TopBar` overlap | up to **42×63 px** on phones (opaque on opaque) | **none**, at every size incl. a 960×600 narrow case |
| Nav rail badges (BOAT/SKILLS/PAINT/BOUNTIES/SHOP) | **47×47** on a small phone | **60 px** (72 on tablet) |
| Nav rail vs its own holder | **overflowed** — 5 tiles × 0.22 = 1.10 | **fits** (417 px in a 420 px holder) |
| `TopBar` `+` (opens the Robux shop) | ~**32 px** on a small phone | **58 px** at every size |
| Modal `Close` button | **40×40** on every panel | **58×58** |
| Shop **buy** buttons (incl. Robux rows) | **84×34** | **≥58 px** |
| `AdminLauncher` | 34 px tall | 58 px |
| Orientation | none — portrait allowed, then flipped on teleport | `LandscapeSensor`, matching the game place |
| Finding #0005 | 6 × `Enum.Font.Gotham*` | **closed** |

## 2. The overlap was invisible where it was built

`LobbyHint` (0.44 wide, centred) reached x 0.28; `TopBar`'s identity block reaches x 0.312. Both are
opaque panels, so this was real paint over paint — but both hit their `MaxSize` caps on a wide screen
and the gap reopens, so **it does not exist at desktop aspect.** That is why it shipped.

Same mechanism Job #094 found between `RiverProgress` and `CurrencyHud`: two independently clamped
elements sharing a row, whose **pixel** `MinSize` floors push them together faster than the scale
values suggest.

`LobbyHint` yields (0.44 → 0.32, spanning 0.34–0.66) rather than the top bar, on Job #094's test:
never shrink the side carrying the tap targets. The hint is a transient instruction with none; the bar
holds the avatar, name, tier and the `+`.

## 3. The nav rail was sized for four entries and now holds five

`Components.iconBar` shipped replacing "the four ad-hoc open buttons" with `tile.Size = 0.22` — correct
for four. **PAINT** was added later (Job 067) and nothing was resized, so 5 × 0.22 = 1.10 and the rail
silently overflowed its own holder while squeezing every badge under the thumb floor.

Fixed at the cause: the tile now divides by the **real entry count** (`1/count`, minus its share of the
inter-tile padding), so a sixth entry resizes the rail instead of breaking it. The holder's height floor
rose 240 → 420 px so the badges clear 58.

**That is ~66% of a 640-tall phone's height, and it was a deliberate trade** (plan §5.3): the lobby is a
menu screen with no gameplay competing for the space, unlike the in-run HUD where #094 refused the
equivalent. This rail is the only route to every shop without walking to a kiosk — a mis-tap here is a
player who cannot spend.

## 4. Two corrections to my own work along the way

**The `+` button's "47×47 at every resolution" was a harness artifact.** Its size is set imperatively by
`TopBar.layoutCluster()` at runtime, so a *clone* carries the live desktop pixel value into every
simulated viewport. Measured live and projected analytically instead, it was ~**32 px** on a small phone
— worse than reported, and not constant at all. **Any element sized by a script rather than by layout
must be measured live**; this is now a documented limitation of the harness's simulated mode.

**My first fix for the buy buttons silently did nothing.** I added a `UISizeConstraint` at the call
site, not knowing `Components.button` already creates its own. **Two `UISizeConstraint`s on one object
do not stack** — only one applies. Caught because the re-measure still read 84×34 rather than because
the code looked wrong. Fixed properly by raising the button's own floor (34 → 58), which corrects every
button in the lobby at once instead of one call site.

## 5. Scope discipline

The agreed decision was **lobby copy only** (`iconBar` has no call sites in `sync/`, so the GAME copy is
unused there). `sync/` was not touched.

Two consequences handled rather than quietly absorbed:
- The stale *"`UI/` is byte-identical across the two trees"* claim lives in `sync/` → **todo #0057**.
- The GAME tree has the **same** 40×40 close and 84×34 buy buttons, used by `DockShopClient` and the
  in-game Robux shop. #094 audited the GAME place but only swept the always-on HUD — modals were never
  opened, so it was missed → **finding #0008**.

## 6. Verification

Harness sweep before/after across 1136×640, 1334×750, 1620×1080, 1920×1080 and a 960×600 narrow case;
modal panels opened one at a time via `UIBus` and audited for tap targets and content spill; live
measurement for script-sized elements; `screen_capture` confirms the hint panel clears the identity
block with text uncropped, and the enlarged rail and `+`.

Final state: **zero overlaps, zero tap targets under 58 px, across the always-on chrome and all five
modal panels.**

`luau-analyze.sh --lobby` clean for every file this job touched. Four pre-existing diagnostics remain in
`PilotIdle.server.luau` (3 × `SameLineStatement`) and `InventoryService.luau` (1 × unknown require) —
untouched by this job, logged here rather than silently absorbed.

## 7. Files changed

| File | Change |
|---|---|
| `lobby/sync/StarterPlayer/StarterPlayerScripts/UI/Orientation.local.luau` | **new** — landscape lock |
| `lobby/sync/ReplicatedStorage/UI/Components.luau` | `iconBar`/`iconButton` count-aware sizing + rail floor; close 40→58; button floor 34→58 |
| `lobby/sync/StarterPlayer/StarterPlayerScripts/LobbyClient.local.luau` | hint panel 0.44 → 0.32 |
| `lobby/sync/StarterPlayer/StarterPlayerScripts/UI/TopBar.local.luau` | currency row height floor; `+` floor 58 |
| `lobby/sync/StarterPlayer/StarterPlayerScripts/UI/AdminClient.local.luau` | launcher tap floor |
| `lobby/sync/ReplicatedFirst/LobbyLoading.local.luau` | 3 fonts hand-copied from Theme + header note |
| `lobby/sync/ServerScriptService/Progression/RankServer.server.luau` | 3 fonts + 2 off-palette colours → Theme |

## 8. Queue

- **finding #0005** — **closed**.
- **finding #0008** — **new**: GAME place has the same undersized modal controls.
- **todo #0057** — stale cross-tree comment.

## 9. Not verified here

No real-device check was run. The lobby has no two-thumb input so the risk is much lower than #096's,
but the tap-target changes are still *measurements*, not *thumbs*. Worth one look during the phone
session #096 already needs — particularly whether the taller nav rail feels right at ~66% of screen
height, which is a judgement call no measurement settles.
