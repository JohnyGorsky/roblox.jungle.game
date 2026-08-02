# Job #069: Lobby audit fixes (Job 068 follow-up)

**Project**: `roblox.jungle`
**Created**: 2026-08-02
**Status**: In progress

## Requirements / goal

Implement the required gaps found by the **Job #068 lobby coverage audit**, in the agreed severity
order **A1 → D1 → E1 → E2 → E3**, with **A2** and **B3** as user actions.

**Working rule for this job (user, 2026-08-02):** *each task is described first and only implemented
once the user accepts it.* One task at a time.

> Scope note: Job 068 is **audit-only**. Every code change lives here.
> Gap ids (A1/D1/E1…) refer to `Jobs/068/intake.md`.

## Task list

| Order | Gap | Todo | Kind | Status |
|---|---|---|---|---|
| 1 | **A1** — `RobuxShop` shows a buy button for passes the player already owns | `0019` | code | ✅ **done** |
| 2 | **D1** — `LobbyConfig.PAD_COUNT = 3` is dead and wrong (4 pads) | `0023` | code | ✅ **done** |
| ~~3~~ | ~~**E1** — `RunwayMarkings` + `Spawn.Pad`~~ | `0036` | — | ❌ **not a gap** — intended design (user) |
| 3 | **E2** — dock water-lapping sound never attaches | `0037` | code | ✅ **done** |
| 4 | **E3** — three models named `Watchtower_NW` | `0038` | code | ✅ **done** (no place change) |
| — | **A2** — unlist Cosmetic Bundle on the Creator Hub | `0020` | **user** | ▫ |
| ~~—~~ | ~~**B3** — spawn star still greybox~~ | `0022` | — | ❌ **not a gap** — intended design (user) |

> **User ruling 2026-08-02:** *"spawn pads and runway is ok. Design is ok."* — `Spawn.Star`,
> `Spawn.Pad` and `RunwayMarkings` are all kept as-is. They remain byte-identical to the greybox
> originals, so they are recorded on the **confirmed-intentional list** in `Jobs/068/intake.md` Part E
> to stop a future sweep re-flagging them.

---

## ✅ Task 1 — A1: owned-pass state in the Robux shop

**File:** `lobby/sync/StarterPlayer/StarterPlayerScripts/UI/RobuxShop.local.luau` (LOBBY tree only).

### What was wrong

Every pass row was gated on `gamePassId > 0` — *"does this product exist"*, never *"does this player
own it"*. `MonetizationServer` already publishes `Owns_<key>` on the player and this screen never read
it, so an owner of the 499 R$ Armored Boat still saw a live buy button; only Roblox's own dialog told
them. It was the **only** lobby shop without an owned state.

### What changed

1. `offer()` now **returns the row**, so a caller can update it after construction.
2. The **passes** loop registers an ownership refresh per row: reads `Owns_<key>`, and on owned sets
   `setText("OWNED")` + `setEnabled(false)`.
3. It subscribes to `player:GetAttributeChangedSignal("Owns_<key>")`, so a row flips **the moment a
   purchase completes**, with no panel reopen.

### Two decisions inside the change

- **Gold packs are deliberately excluded.** They are repeatable developer products — "owned" is
  meaningless and their buy button must always stay live. Only `GamePasses` get the treatment.
- **The default is "not owned", and that direction matters.** `Owns_extraSlots` and friends arrive
  *after* an async `UserOwnsGamePassAsync` round-trip, i.e. after the row is built. So the row starts
  showing the price and flips to OWNED when the attribute lands. Defaulting the other way would
  briefly hide a real buy button from someone who has **not** bought — a worse failure than briefly
  showing one to someone who has.

### Deviation from what was described

I said "OWNED **with the `check` icon**". It ships as **text + disabled only**, no icon swap, because:

- `Components.row` builds its icon at construction and exposes no setter, and the row's badge already
  holds the **product's real store art** — replacing that with a generic tick loses information.
- It now matches the existing lobby exactly: `ModulesShop` (`OWNED`), `SkillShop` (`MAX`) and
  `RetentionClient` (`CLAIMED`) are all text-only too. **Nothing in the lobby currently renders the
  `check` icon for these states**, so adding it here alone would be the inconsistent choice.

`ASSETS.md` §1.9 row 8 lists `check` as *"CLAIMED / OWNED / MAX states"* — that remains an unrealised
intention across four screens, not an A1 gap. Worth a separate pass if we want it.

### Verified

- `tools/luau-analyze.sh` on the file (LOBBY tree) → **no diagnostics**.
- Attribute name traced end to end: `MonetizationServer` writes `"Owns_" .. gp.key`; this screen reads
  `"Owns_" .. gp.key`. Keys: `armoredBoat`, `boatPaint`, `extraSlots`.
- `Components.button.setEnabled(false)` sets `enabled = false`, and the `Activated` handler returns
  early on it — so a disabled OWNED row **cannot** fire a purchase prompt.

### NOT verified — needs a Play test

This is a file edit in the LOBBY Rojo tree, so it **needs a Rojo sync** before it exists in the place.
Confirming the flip visually needs a player who owns a pass — the honest check is:
**Play → open the Robux shop → a pass you own reads OWNED and is not clickable.**

---

## ✅ Task 2 — D1: the lying pad-count constant

**File:** `lobby/sync/ReplicatedStorage/LobbyConfig.luau` (LOBBY tree only).

### What was wrong

`LobbyConfig.PAD_COUNT = 3` — read by **nothing** (one grep hit across both trees: its own
declaration) and **wrong** (the place has 4 pads: Blue/Red/Green/Yellow). `LobbyServer` discovers pads
by scanning for `Station == "PartyPad"`, so the constant never had any effect. Harmless at runtime,
but it is the first value someone opens this file to change.

### What changed — deleted, not corrected

The line is **gone**, replaced by a comment in its place explaining that pads are discovered by
attribute and that the old constant had drifted to a lie.

**Why delete rather than set it to `4`:** a constant that nothing reads has no mechanism keeping it
true, so it would drift again the moment a fifth pad is placed. The alternative — making it
authoritative by having `LobbyServer` validate the discovered count against it and warn on mismatch —
was offered and not taken; it trades a silent drift for a loud one at the cost of more code, and
attribute-discovery is already the better design.

The comment matters as much as the deletion: someone will come looking for a pad-count knob, and it
now tells them where the real answer lives instead of leaving a hole.

### Verified

- `grep PAD_COUNT` over `lobby/` + `sync/` → only the new explanatory comment. (Two further hits are
  in `Jobs/017/` historical docs, correctly left untouched — they record what *was* true then.)
- `tools/luau-analyze.sh` on `LobbyConfig` + `LobbyServer` → **no diagnostics**.
- Behaviour unchanged by construction: nothing read the value, and `MAX_PER_PAD` / `COUNTDOWN` /
  `GAMEPLAY_PLACE_ID` are untouched.

---

## ✅ Task 3 — E2: the dock water sound that never played

**File:** `lobby/sync/ServerScriptService/LobbySoundscape.server.luau` (LOBBY tree only).

### What was wrong

`Scenery.Dock:FindFirstChild("Pier")` — **non-recursive**. The greybox dock had `Pier` as a direct
child; the Store dock that replaced it nests one level deeper (`Scenery.Dock.Dock.Pier`). So the
lookup returned `nil`, `waterCount` stayed `0`, and **the water-lapping loop was never created** —
the lobby has had no dock water sound at all, while `ASSETS.md` §1.11 recorded it as ✅ wired.

Invisible from disk. Only the live tree shows it, which is exactly why the sweep was worth running.

### What changed

- `dock:FindFirstChild("Pier", true)` — a **recursive find by name**.
- Added a `warn()` on the else branch, so if the dock is ever re-nested again this **fails loudly**
  instead of silently dropping the sound — which is how it stayed broken this long.

**Why not hardcode `Dock.Dock.Pier`:** the double-`Dock` is an artifact of how the Store asset was
inserted, not a stable contract. A name search at any depth survives the dock being swapped or
re-nested, and matches how the rest of the script already thinks.

### Verified live (Studio MCP, read-only)

| Check | Result |
|---|---|
| OLD `FindFirstChild("Pier")` | `nil` — **confirms the bug was real, not theoretical** |
| NEW `FindFirstChild("Pier", true)` | `Workspace.LOBBY_GREYBOX.Scenery.Dock.Dock.Pier` |
| Resolved instance | `Part`, `isBasePart = true`, `31.9 × 0.84 × 0.63` |
| `Sound` instances under `Scenery.Dock` beforehand | **0** — the loop had genuinely never been created |
| Regression: `FirePit` rule | still finds **2** |
| Regression: watchtower lookups | both still resolve to a BasePart |
| `luau-analyze.sh` | no diagnostics |

**Note on the resolved part:** the Store dock's `Pier` is a thin plank (0.84 × 0.63 cross-section)
rather than the main deck slab. Immaterial for the audio — it sits at the dock and the emitter uses
`RollOffMinDistance 10` / `MaxDistance 120`, so a few studs of offset is inaudible.

### NOT verified — needs a Rojo sync + Play

The script prints its own counts, so the check is concrete:
**`[LobbySoundscape] ready — … water×1`** (it currently reports `water×0`).

---

## ✅ Task 4 — E3: only 2 of 4 watchtowers creaked

**File:** `lobby/sync/ServerScriptService/LobbySoundscape.server.luau` (LOBBY tree only).
**No place change. Nothing renamed, moved or deleted.**

### The finding, and the ruling that reshaped the fix

The sweep found **four** towers where §1.6 specifies two, three of them named `Watchtower_NW` (two
flanking the southern approach). My first proposal was to rename the southern pair to `_SW`/`_SE`.

**The user ruled the towers are intended** — *"4 are intended, do not delete any game assets… all
scenery is how it should be."* That turned out to make the fix **better**, not merely smaller: it
forced the problem back into the script, where it actually belonged.

### What was wrong

```lua
for _, name in ipairs({ "Watchtower_NW", "Watchtower_NE" }) do
    local m = scenery:FindFirstChild(name)
```

A hardcoded two-name list plus `FindFirstChild`, which returns only the **first** match per name. With
three towers sharing `Watchtower_NW`, **two of the four were silent**, and which one won depended on
child order — arbitrary and invisible.

### What changed

Scan `Scenery` for **Models whose name starts with `Watchtower`** and attach the creak to each.

- Duplicate names stop mattering — the script no longer cares.
- **A fifth tower placed in the editor creaks automatically, no script edit** — the user's stated goal,
  and the same find-by-name-and-attach rule the rest of the lobby follows
  (memory: `lobby-editor-placed-not-scripted`).
- The naming oddity (two southern towers still called `_NW`) is left alone: cosmetic, and the scenery
  is signed off.

### Verified live (Studio MCP, read-only)

| Check | Result |
|---|---|
| OLD rule | attaches to **2** of 4 |
| NEW rule | attaches to **4** — NE `(96,−115)`, NW `(−88,−110)`, NW `(34,151)`, NW `(−63,153)` |
| Each hit resolves to a BasePart | ✅ all four → `Base` |
| False positives | none — only `Model`s are matched, every hit is a real tower |
| `luau-analyze.sh` | no diagnostics |

**Cost:** two extra looping positional sounds (volume 0.25, rolloff 10–120). Negligible, but it is a
real +2 rather than a free change.

### NOT verified — needs a Rojo sync + Play

Concrete check, from the script's own print: **`rope×4`** (currently `rope×2`).

---

---

# ✅ PLAY VERIFICATION — all four fixes confirmed running (2026-08-02)

Rojo had already synced all three files into the place (confirmed by `script_grep` before testing).
Studio Play started via MCP; results read from the real server console and the real client GUI, not
inferred.

## Audio — one console line proves two fixes

```
[LobbySoundscape] ready — music+ambience+wind (2D), water×1, campfire×2, rope×4, cicadas looping
```

| | Before | After |
|---|---|---|
| **E2** dock water | `water×0` | **`water×1`** ✅ |
| **E3** watchtowers | `rope×2` (of 4 towers) | **`rope×4`** ✅ |
| campfires (untouched) | `campfire×2` | `campfire×2` — no regression |

The same run also printed **`[Lobby] party system bound to 4 editor launch pads`**, independently
confirming D1's premise: the place has 4 pads, and the deleted `PAD_COUNT = 3` was wrong.

## A1 — owned passes, tested in both directions

Initial state (test account owns all three passes):

| Row | Text | Active |
|---|---|---|
| `Row_Armored Boat` | `OWNED` | `false` ✅ |
| `Row_Boat Paint Pack` | `OWNED` | `false` ✅ |
| `Row_Extra Inventory Slots` | `OWNED` | `false` ✅ |
| `Row_10/25/60/150 Gold` | `R$ 49/99/199/449` | `true` ✅ — correctly excluded |

Then the **live flip**, driven from the server and read on the client, **without reopening the panel**:

1. Server `SetAttribute("Owns_armoredBoat", nil)` → row became **`R$ 499`, `Active = true`**, while
   `Row_Boat Paint Pack` **stayed OWNED** — proving the refresh is per-row, not global.
2. Server `SetAttribute("Owns_armoredBoat", true)` → row returned to **`OWNED`, `Active = false`**.

Step 2 is the direction that matters: it is exactly what `MonetizationServer` does on
`PromptGamePassPurchaseFinished`, so **a completed purchase now updates the row live**.

> Method note: the attribute was driven from the **Server** datamodel and read from the **Client**
> datamodel — a shared `Instance`, per the `studio-mcp-testing-gotchas` rule, rather than trusting a
> value set inside one `execute_luau` context. All changes were Play-session only and were discarded
> when Play stopped.

## Status — code work complete

| Remaining | Owner |
|---|---|
| **A2** — unlist the Cosmetic Bundle on the Creator Hub (`todo/0020`) | **user** |
| **ASSETS.md doc corrections** (`todo/0035`, 8 rows) | queued |
| `Lighting.Technology` eyeball check (`todo/0040`) | **user** |

## Checklist

- [x] Task 1 (A1) implemented, analyzer clean, **verified in Play (both directions)**
- [x] Task 2 (D1) implemented, verified by grep + analyzer, premise confirmed in Play (4 pads)
- [x] Task 3 (E2) implemented, analyzer clean, **verified in Play (`water×1`)**
- [x] Task 4 (E3) implemented, analyzer clean, **verified in Play (`rope×4`)**
- [ ] Final summary + changelog
