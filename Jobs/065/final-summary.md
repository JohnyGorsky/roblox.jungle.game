# Final Summary — Job #065

**Project**: `roblox.jungle`
**Completed**: 2026-07-31
**Status**: ✅ Completed

## What was implemented

The lobby went from eight independently-drifted screens to one design system.

**The problem, measured at the start:** 8 lobby screens, 1,266 lines, **60 distinct `Color3.fromRGB`
values** and **75 uses of `Enum.Font.Gotham*`** — a font `STYLEGUIDE.md` never mentions. No shared theme
or component module existed anywhere, so every screen had drifted on its own.

**The design system** now lives in `lobby/sync/ReplicatedStorage/UI/`:

| Module | What it owns |
|---|---|
| `Theme` | Every colour, font, size, radius, tween, icon id and sound id. The single place a hex value appears. |
| `Components` | `screen · icon · iconButton · button · chip · progressBar · panel · row · toast · confirm · burst · iconBar`. Builders only — no game logic. |
| `UISound` | One call per interface cue; sounds cached, per-cue volumes, debounced. |
| `UIBus` | Client-side panel-open bus (see below). |

A screen may reference `Theme.*` and nothing else. **No colour, font or asset id is written in any lobby
script anymore** — including the server ones, since `Theme` is tokens-only and safe to read there.

**All 10 surfaces restyled** — the 8 UI scripts plus the two the original scope missed (the hint banner
and the player rank nameplate), plus the 8 world billboards and the pad signs.

**Beyond a restyle**, four things the audit showed were missing outright:

- **A confirm popup on every Gold spend.** Skills and modules previously deducted Gold instantly on
  click, with no undo — worst on mobile. *The one deliberate behaviour change in this job;* approved
  before implementing, and the server contract is untouched (the popup only gates the client call).
- **Visible failure.** `failed_or_not_allowed` had nothing to show; rows now flash red and shake.
- **UI VFX.** The juice rule asks for sound *and* effect; the plan originally wired 11 sounds and zero
  effects. `Components.burst` adds a wash + motes on purchase, upgrade and claim.
- **Toasts, empty states and disabled states**, none of which existed.

**One shared entry bar** replaced four ad-hoc open buttons that each screen built at hardcoded pixel
offsets — which overlapped or fell off-screen on a phone.

### Files changed

**New** — `UI/{Theme,Components,UISound,UIBus}.luau` · `UI/TopBar.local.luau` (replaces the lobby
`GoldHud`) · `UI/EntryBar.local.luau` · `StarterCharacterScripts/Footsteps.local.luau` ·
`ServerScriptService/LobbySignage.server.luau`

**Restyled** — `RobuxShop` · `SkillShop` · `ModulesShop` · `RetentionClient` (→ BOUNTIES) ·
`AdminClient` · `LobbyClient` (hint banner) · `LobbyServer` (pad signs + audio) · `LobbyStations`
(prompt cue) · `RankServer` (nameplate)

**Also** — `RankDefs` gained `nextTierFor`/`progressFor` (mirrored byte-identically to `sync/`) ·
`lobby/default.project.json` · `tools/luau-analyze.sh` · `ASSETS.md` · registry `images.md`, `audio.md`,
`ui.md`

## Verification

- [x] **Analyzer clean on every touched file, both trees.** Pre-existing findings in untouched files
      (`PilotIdle`, `InventoryService`) left alone.
- [x] **Played after every phase**; purchase, claim and party flows confirmed unchanged.
- [x] **Mobile pass measured, not eyeballed** — every surface queried live for insets, tap size and text
      clamping. Smallest tap target **23px → 34px**; close buttons **24px → ≥40px**; all gameplay
      `ScreenGui`s on `CoreUISafeInsets`.
- [x] `progressFor` edge cases executed in Studio (11 cases: tier boundaries, top tier, star boundaries)
      — no NaN, no out-of-range fill, no divide-by-zero.
- [x] All 41 asset ids Studio-verified before use.

## Bugs found and fixed along the way

1. **`SkillTrainer` had lost its `Station` attribute** — the skill kiosk was silently dead in-world, from
   before this job. Restored, verified by read-back; all four kiosks now bind. *(Place content — saved.)*
2. **`lobby/default.project.json` had no `StarterCharacterScripts` mapping**, so anything placed there
   would never have synced.
3. **`tools/luau-analyze.sh` only ever analyzed the GAME tree** — every lobby file reported "Unknown
   require", making the whole lobby tree unanalyzable. It now selects the tree and regenerates its sourcemap.
4. **Two systems fighting over one object** — `LobbySignage` was restyling the live `PadSign` billboards
   that `LobbyServer` rewrites every tick, in non-deterministic startup order. Now skipped explicitly.
5. **`LobbyServer` nil-safety (finding 0002)** — cast `FindFirstChild` straight to `BasePart?` and would
   have lied if anything non-BasePart were ever named `PadSignAnchor`. Fixed and closed.
6. **My own regression:** shrinking the close `X` on request took it to 23px, under a thumb. Caught by
   measuring, not by looking. `UISizeConstraint` floors added.

## Two things worth remembering

**`AutomaticSize` does not mix with aspect-constrained or scale-sized children.** Two attempts at the
content-hugging Gold chip collapsed to an empty circle: automatic sizing can't measure such children, and
a `UIAspectRatioConstraint` defaults to `DominantAxis.Width`, so a width of 0 drives the height to 0 too.
The chip now measures `TextBounds` and sizes itself from a known height.

**`execute_luau` runs in a separate Luau context.** Requiring `UIBus` there yields a *different*
BindableEvent, so a scripted fire cannot reach the real listener — the first test looked like a bug and
wasn't. Client-side buses must be tested with a real click (`user_mouse_input`).

## Carried forward (deliberate, not dropped)

1. **`TeleportGui`** — byte-identical in both trees and shown during teleports in *both* directions.
   Restyling only the lobby copy would change its appearance by travel direction, and the game tree has
   no `Theme` (decision #7). Moves with the game-place restyle.
2. **The 7 upgrade-item renders** (`ASSETS.md §1.9b`) — Boat Upgrades and the buy popup show icon + text
   until they exist.
3. **Settings panel** → `Planned/lobby-settings-panel.md` (new functionality with its own persistence
   design; kept out of a restyle).
4. **The 15 game-place screens** — out of scope throughout; the theme is written so they can adopt it.
5. **Real-device check** — 34/40px is *our* tap floor; `roblox-ui` notes Roblox publishes no official
   minimum, and an emulator cannot tell you how something feels under a thumb.
