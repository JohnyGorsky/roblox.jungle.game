# Job #095 — Implementation plan

**Project**: `roblox.jungle` · **Place**: LOBBY only (`lobby/sync/`) · **Status**: AGREED — ready to implement

Intake: [intake.md](intake.md). Skills: `roblox-ui`, `jungle-style`, GROUND-RULES §3/§6.

**Studio target (verified):** `Place1`, PlaceId **114309626266505**, studio id `dc3b3837-…4b84`
(`StarterPlayerScripts = LobbyClient, UI`). Studio ids are per-session — re-confirm before running.

---

## 1. Everything in the intake was confirmed — measured, in Play, on the lobby place

The overlap harness from Job #094 was pointed at the lobby. Results:

| Viewport | `LobbyHint` ↔ `TopBar` | Tap targets under the 58 px floor |
|---|---|---|
| 1136×640 (small phone) | **36×54 px** | `TopBar/Btn_+` 47×47 · **5× `LobbyEntryBar/Button` 47×47** · `AdminLauncher` 113×34 |
| 1334×750 (phone) | **42×63 px** | `TopBar/Btn_+` 47×47 · **5× `LobbyEntryBar/Button` 56×56** · `AdminLauncher` 133×34 |
| 1620×1080 (tablet) | **25×91 px** | `TopBar/Btn_+` 47×47 · `AdminLauncher` 162×48 |
| 1920×1080 (desktop) | **none** | `TopBar/Btn_+` 47×47 · `AdminLauncher` 170×48 |
| 2560×1080 (wide) | **none** | `TopBar/Btn_+` 47×47 |

**The overlap is invisible at desktop aspect and worst on phones.** That is precisely why it shipped —
it cannot be seen on the machine it was built on. A `screen_capture` of the live lobby confirms the
clean desktop case, which corroborates the harness rather than contradicting it.

Both offenders are opaque panels (`BackgroundTransparency` 0.15 and 0.12), so this is real paint over
paint, not two transparent holders brushing.

**Mechanism** — identical to the `RiverProgress` ↔ `CurrencyHud` case in #094: two independently
clamped elements sharing one row, whose **pixel** `MinSize` floors push them together faster than their
scale values suggest.

| | Scale | `MinSize` | `MaxSize` |
|---|---|---|---|
| `TopBar` Identity | `x 0.012–0.312, y 0.02–0.105` | `(210, 52)` | `(460, 104)` |
| `LobbyHint` panel | `x 0.28–0.72` (anchor 0.5) | `(260, 54)` | `(760, 130)` |

The `MaxSize` caps are why it vanishes on wide screens: both stop growing, and the gap reopens.

## 2. The bigger finding: the lobby's primary navigation is undersized on phones

`LobbyEntryBar` is the left rail — BOAT · SKILLS · PAINT · BOUNTIES · SHOP — and it is **the** way a
mobile player reaches every shop and progression screen without walking to a kiosk. Its buttons measure
**47×47 on a small phone**, under the 58 px thumb floor this game already applies to the driver's
controls.

This outranks the overlap. An overlap is ugly; a nav rail you mis-tap is a player who cannot spend.

**Cause:** `Components.iconBar` sizes the rail holder `0.062 × 0.46` with `MinSize (64, 240)`. Five
entries plus their labels inside 240–294 px of height leaves ~47 px per button.

**Fix (agreed, §5.3):** raise the rail's height floor so each cell clears 58 px. Five cells at 58 px +
label + gap needs roughly **380 px**, i.e. ~59% of a 640-tall phone. That height is accepted — the lobby
is a menu screen with no gameplay competing for the space. Labels stay.

## 3. Two constraints discovered that change how this must be done

### 3a. `Components.iconBar` lives in a file shared with the GAME tree

`iconBar` is **defined** in `ReplicatedStorage/UI/Components.luau`, which exists in *both* trees. It is
**called only from the lobby** (`grep -rn "iconBar" sync/` finds the definition and no call sites).

`RunComponents.luau`'s header states `UI/` is kept "byte-identical across the two trees". **That is no
longer true** — `diff` reports the two `Components.luau` files differ today. So the plan must decide,
not assume:

- If parity is still the intent, an `iconBar` change means the same edit in `sync/` — which touches the
  GAME tree from a LOBBY-scoped job, and GROUND-RULES §1 says confirm before crossing that boundary.
- If parity has already lapsed, editing only the lobby copy is correct and the stale claim in the
  header should be corrected rather than left to mislead the next person.

**→ Decided (§5.1): lobby copy only.** `sync/` is not touched by this job. The stale header comment is
now **todo #0057** rather than an edit made in passing.

### 3b. The analyzer needs `--lobby`

`lobby/` has its own `default.project.json` and `sourcemap.json`. Running the GAME sweep over lobby
files reports "Unknown require" on everything. Use `bash tools/luau-analyze.sh --lobby`.

## 4. Workstreams

### WS1 — Landscape lock
Port `Orientation.local.luau` from #094 into `lobby/sync/StarterPlayer/StarterPlayerScripts/UI/`.
Same reasoning, same `LandscapeSensor`, same why-not-`StarterGui` note. Without it a player browses the
lobby in portrait and is flipped on teleport, and the lobby's layouts are being used in an orientation
nothing has tested.

### WS2 — The `TopBar` ↔ `LobbyHint` overlap
**`LobbyHint` narrows** (§5.2). It is a transient instruction with no tap targets, so shrinking it costs
nothing playable, whereas `TopBar` carries the avatar, name, tier and the `+` button. This is the same
test #094 used: never shrink the side carrying the tap targets.

### WS3 — Tap targets
- `LobbyEntryBar` rail → clear 58 px by raising the holder's `MinSize` height (§2, §5.3). Lobby copy of
  `Components.iconBar` only.
- `TopBar/Btn_+` → 47×47 at **every** resolution, because `side = floor(height * 0.72)` derives from a
  height that is itself clamped constant. It opens the **Robux shop**: a mis-tap here is a real-money
  purchase flow the player did not mean to open. Raise the floor.
- `AdminLauncher` 34–48 px tall — dev-only, lowest priority, fix if free.

### WS4 — Mobile-first sweep
Every lobby surface: `AdminClient` · `ModulesShop` · `PaintShop` · `RetentionClient` · `RobuxShop` ·
`SkillShop` · `TeleportGui` · `TopBar` · `LobbyClient` · `LobbyLoading` · `EntryBar` · `UIClick`.

Particular attention:
- **`PaintShop`** — the only `UIGridLayout` in either tree (`CellSize 0.31 × 0.44`); grids break first at
  an untested aspect.
- **The shops** — `ScrollingFrame` lists on `Theme.rowHeight`. These are purchase flows; check the row
  height against the thumb floor for the same reason as `Btn_+`.

### WS5 — Finding #0005, six Gotham references
Not one fix but two, and the finding already records why:
- `lobby/sync/ReplicatedFirst/LobbyLoading.local.luau` (84, 96, 132) — runs from `ReplicatedFirst` and
  **cannot** `require` Theme without blocking on the replication it exists to hide. Same treatment
  `GameLoading` already has: hand-copied palette values **plus a header note** saying why it is not a
  require. Copying values without the note just invites someone to "fix" it back.
- `lobby/sync/ServerScriptService/Progression/RankServer.server.luau` (228, 241, 266) — builds GUI
  server-side and **can** require Theme. It should.

## 5. Decisions (agreed via wizard, 2026-08-18)

| # | Question | Decision |
|---|---|---|
| 1 | `iconBar` cross-tree (§3a) | **Lobby copy only.** `iconBar` has no call sites in `sync/`, so the GAME copy is unused there and nothing breaks. Job stays inside its place boundary. ⚠️ Open sub-point: the stale "byte-identical" claim lives in `sync/ReplicatedStorage/RunUI/RunComponents.luau` — correcting even that one comment means touching the GAME tree, so it is **NOT** done under this decision. Logged as a todo instead. |
| 2 | Which yields in the top row | **`LobbyHint` (centre panel) narrows.** It is a transient instruction with no tap targets; `TopBar` holds the avatar, name, tier and the `+` button. Same test #094 used — never shrink the side carrying the tap targets. |
| 3 | Nav rail height | **Take the height.** Raise the rail's `MinSize` so all five buttons clear 58 px, accepting ~59% of a small phone's height. The lobby is a menu screen; no gameplay competes for that space. Labels stay — #094's notes already record a playtester failing to read an unlabelled icon. |
| 4 | Portrait | **Lock landscape**, matching the game place. One orientation across both places; no flip on teleport. |

## 6. Verification

Harness sweep (lobby `AUDIT` list + states) before and after, across the resolution matrix; per-state
`screen_capture`; verify by read-back **and** screenshot; `luau-analyze.sh --lobby` clean.

**Known gap, same as #094:** the emulator is single-pointer and desktop Play reports
`TouchEnabled = false`. Less critical here — the lobby has no two-thumb input — but the tap-target
changes still want one real-phone confirmation.

## 7. Order of work

1. WS1 landscape → 3. WS3 tap targets (highest player impact) → 4. WS2 overlap →
5. WS4 sweep → 6. WS5 fonts → 7. summary + changelog; close finding #0005.
