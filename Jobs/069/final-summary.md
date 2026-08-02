# Final Summary — Job #069

**Project**: `roblox.jungle`
**Completed**: 2026-08-02
**Status**: ✅ Completed — all four code fixes implemented and **verified in a live Play session**

## What this job was

Implement the required gaps found by the **Job #068 lobby audit**, one task at a time, each described
and accepted by the user before any change. Four needed code; two were user actions; four of the
audit's original findings were withdrawn along the way as wrong or by-design.

## What was implemented

### 1. A1 — the Robux shop now shows what you already own

`RobuxShop.local.luau` gated every pass row on `gamePassId > 0` — *"does this product exist"*, never
*"does this player own it"*. `MonetizationServer` already published `Owns_<key>` and the screen never
read it, so an owner of the 499 R$ Armored Boat still saw a live buy button. It was the only lobby
shop without an owned state.

Pass rows now read `Owns_<key>`, show a disabled **OWNED**, and subscribe to
`GetAttributeChangedSignal` so a row flips **the moment a purchase completes** — no reopen.

Two deliberate calls:
- **Gold packs excluded.** Repeatable developer products; "owned" is meaningless and their button must
  stay live.
- **Default is "not owned".** The attribute arrives *after* an async ownership round-trip, so the row
  starts on the price and flips when it lands. The reverse would briefly hide a real buy button from
  someone who hasn't bought — a worse failure than briefly showing one to someone who has.

*Deviation from the described plan:* shipped as text + disabled, **no `check` icon**. The row badge
already holds the product's real store art, `Components.row` exposes no icon setter, and
`ModulesShop`/`SkillShop`/`RetentionClient` are all text-only — adding an icon here alone would be the
inconsistent choice.

### 2. D1 — a config constant that lied

`LobbyConfig.PAD_COUNT = 3` was read by nothing (one grep hit: its own declaration) and wrong — the
place has 4 pads. **Deleted rather than corrected to `4`**: a constant nothing reads has no mechanism
keeping it true and would drift again. A comment in its place records that `LobbyServer` discovers pads
by the `Station == "PartyPad"` attribute.

### 3. E2 — the dock water sound that had never played

`Scenery.Dock:FindFirstChild("Pier")` was **non-recursive**. The greybox dock had `Pier` as a direct
child; the Store dock that replaced it nests a level deeper, so the lookup returned `nil` and the water
loop was **never created** — while `ASSETS.md` recorded it as ✅ wired.

Now a recursive find by name, plus a `warn()` on the else branch so a future re-nesting **fails loudly**
instead of silently dropping the sound, which is how it stayed broken. Deliberately not hardcoded to
`Dock.Dock.Pier` — that double-`Dock` is an insertion artifact, not a contract.

### 4. E3 — only 2 of 4 watchtowers creaked

A hardcoded `{ "Watchtower_NW", "Watchtower_NE" }` + `FindFirstChild`, which returns only the **first**
match per name. Three of the four towers share the name `Watchtower_NW`, so two were silent and which
one won depended on child order.

The user ruled all four towers are intended and that no scenery should be touched — which made the fix
**better**, not just smaller: the problem went back into the script where it belonged. Now scans for
Models matching `^Watchtower`, so **a fifth tower placed in the editor creaks with no script edit**.

### 5. Documentation — the durable half

- **`LOBBY-ASSET-INVENTORY.md`** (new) — a reuse manifest for the GAME place: 188 live asset ids +
  53 declared in scripts, grouped by audio / UI / boat / hero props / store components, with what
  transfers and what must be re-imported. Built for the stated goal of reusing lobby audio and SFX in
  the game place.
- **`ASSETS.md`** — 10 corrections, including a standing warning that the file describes **intent**
  while the place is **ground truth**, naming the two traps that produced four false audit findings.
- **Registry `meshes.md`** — 8 hero Meshy mesh ids added. The inventory found they existed **nowhere
  but the `.rbxl`**: lose the place file and the plane, the Pilot body and all four station buildings
  were unrecoverable, and the GAME place could not reuse them.

## Files changed

| File | Change |
|---|---|
| `lobby/sync/StarterPlayer/StarterPlayerScripts/UI/RobuxShop.local.luau` | A1 — owned-pass state |
| `lobby/sync/ReplicatedStorage/LobbyConfig.luau` | D1 — deleted `PAD_COUNT` |
| `lobby/sync/ServerScriptService/LobbySoundscape.server.luau` | E2 + E3 — recursive pier lookup, prefix tower scan |
| `LOBBY-ASSET-INVENTORY.md` | **new** — asset reuse manifest |
| `ASSETS.md` | 10 corrections + the intent-vs-ground-truth warning |
| `../roblox.workspace/Assets/registry/meshes.md` | 8 unregistered hero meshes recorded |

## Verification

**All four fixes confirmed in a live Studio Play session**, not reasoned about.

- [x] **E2 + E3 — one console line:** `[LobbySoundscape] ready — … water×1, campfire×2, rope×4, …`
      (was `water×0`, `rope×2`; campfires unchanged, so no regression)
- [x] **D1 premise confirmed in the same run:** `[Lobby] party system bound to 4 editor launch pads`
- [x] **A1 initial state:** all three owned passes read `OWNED` / `Active = false`; the four gold packs
      stayed live at R$ 49/99/199/449
- [x] **A1 live flip, both directions, without reopening the panel** — server cleared
      `Owns_armoredBoat` → row returned to `R$ 499` while Boat Paint **stayed OWNED** (proving it is
      per-row); server set it back → `OWNED` again. That second direction is exactly what
      `MonetizationServer` does on purchase completion.
- [x] `luau-analyze.sh` clean on all three scripts
- [x] Registry additions verified by grep — all 8 ids resolve

*Method:* the attribute was driven from the **Server** datamodel and read from the **Client** datamodel
— a shared `Instance`, per the `studio-mcp-testing-gotchas` rule — rather than trusting a value set
inside one `execute_luau` context. All Play-session changes were discarded on stop; nothing needed
saving.

## Not done / outstanding

| Item | Owner |
|---|---|
| `Lighting.Technology = Future` eyeball check + save the place (`todo/0040`) | **user** |
| `Mesh1.0` (`139814217941669`) is now registered but still **unidentified** | **user** |
| Dev-product prices unreconciled; all passes use **managed pricing**, so today's match is a snapshot (`todo/0025`) | queued |
| 11 optional todos — `0039` (doubled `Bloom`/`SunRays`) is the only one with real perf cost | queued |
| Boat meshes imported into the LOBBY place only — the GAME place needs its own import + `preparePaintLibrary()` | carry-over from #066 |
