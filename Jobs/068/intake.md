# Job #068: Lobby full coverage audit

**Project**: `roblox.jungle`
**Created**: 2026-08-02
**Status**: Requirements Gathering (intake) — **audit-only job**

## Goal

A complete coverage check of the **LOBBY place** (Jungle Airfield) against `ASSETS.md` §1 and `GAME.md`:

1. Is everything the docs describe **actually implemented**?
2. Are **all purchases covered** end to end (sold → granted → applied → visible)?
3. Is there any **greybox left** in the place, and is every listed item covered?

Every gap is marked **🔴 REQUIRED** or **🟡 OPTIONAL**.

**Scope decision (user, 2026-08-02): audit only.** The deliverable is this report plus queued
`todo/`, `findings/` and follow-up job intakes. **No lobby code or place changes in this job.**

## Method — and what is *not* yet verified

- **Verified against code**, file by file: all 48 files under `lobby/` (both `lobby/sync/` and
  `lobby/build/`), plus the game tree where a lobby purchase is *applied* there (`sync/.../ItemDefs`,
  `sync/.../BoatModules`).
- **Verified against docs**: `ASSETS.md` §1 (all 14 subsections), §2, §5, §5.1; `GAME.md`
  (structure / monetization / inventory / progression); `todo/`, `findings/`, `Planned/`.
- ⏳ **NOT yet verified: the live place.** The greybox sweep (Part E) needs Studio open on the LOBBY
  place with the MCP connected. Everything in Part E is **claimed by docs, unconfirmed in world**.
  User chose to run this half live via MCP — it is the one blocking item on this job.

**Legend** — 🔴 REQUIRED = correctness, real money, or a visibly unfinished thing a player will hit.
🟡 OPTIONAL = polish, nice-to-have, or explicitly deferred by an earlier decision.

---

# Part A — Purchases: are they all covered?

Every item is traced through five stages. A purchase is only "covered" if all five hold.

| Item | Sold in lobby | Hub id set | Receipt / ownership | Effect implemented | Visible in lobby | Verdict |
|---|---|---|---|---|---|---|
| **10 / 25 / 60 / 150 Gold** | ✅ `RobuxShop` | ✅ 4 product ids | ✅ `ProcessReceipt` + `purchaseIds` idempotency + prompt `save()` | ✅ `Profiles.addGold` | ✅ TopBar gold chip | ✅ **covered** |
| **Armored Boat** (499 R$) | ✅ `RobuxShop` | ✅ `1919001295` | ✅ `Owns_armoredBoat` on join + on purchase | ✅ read in `sync/.../BoatModules:339` (+20% HP/dmg, crew-wide) | ⚠️ nothing in the lobby shows you own it | ⚠️ **gap A1** |
| **Boat Paint Pack** (99 R$) | ✅ `RobuxShop` | ✅ `1919355255` | ✅ `Owns_boatPaint` | ✅ `BoatPaint` + `PaintServer` + `PaintShop`, 6 liveries | ✅ showroom boat repaints instantly | ✅ **covered** |
| **Extra Inventory Slots** (149 R$) | ✅ `RobuxShop` | ✅ `1935044952` | ✅ `Owns_extraSlots` | ✅ `sync/.../ItemDefs.slotsFor` 4→6 | ➖ game-place effect, nothing to show in lobby | ✅ **covered** |
| **Self Revive** (20 R$) | ➖ deliberately not in the lobby shop | ✅ `3612677893` | ✅ `keyForProduct` → `GrantProduct` hook; **returns `NotProcessedYet` in the lobby** so Roblox retries in the place that can honour it | ✅ game place (DOWNED overlay) | ➖ n/a | ✅ **covered, by design** |
| **~~Cosmetic Bundle~~** (249 R$) | ⛔ removed from the shop (Job 067) | listing still exists | ownership no longer checked | ❌ never built | ❌ | 🔴 **gap A2** |

### 🔴 A1 — REQUIRED · `RobuxShop` has no OWNED state for passes

`RobuxShop.local.luau:100-104` renders every pass row identically:

```lua
offer(gp.key, gp.name, gp.blurb, gp.robux, gp.gamePassId > 0, function()
    MarketplaceService:PromptGamePassPurchase(player, gp.gamePassId)
end)
```

Enablement is `gamePassId > 0` — **"does this product exist"**, never **"does this player own it"**.
`Owns_<key>` is set on the player by `MonetizationServer` and is sitting right there, unread by this
screen. A player who already owns Armored Boat still sees a live **R$ 499** button; tapping it opens
Roblox's dialog, which is the only thing that tells them they already bought it.

This is the **only** lobby shop without an owned state — `ModulesShop` has `OWNED`, `SkillShop` has
`MAX`, `RetentionClient` has `CLAIMED`, `PaintShop` locks unowned swatches. The `check` icon was even
sourced for exactly this (`ASSETS.md` §1.9 row 8: *"CLAIMED / OWNED / MAX states"*). Required because
it is a live storefront showing a buy button for something already paid for.

### 🔴 A2 — REQUIRED · Cosmetic Bundle unlisting is unconfirmed

Job 067 removed it from `MonetizationDefs`, which stops *this client* prompting it. The Creator Hub
listing itself is a manual step, recorded as still-outstanding in Job 067's final summary. Until it's
unlisted, a 249 R$ pass that delivers nothing is still buyable from the store page. **User action, not
code.** Verification only — no work here.

### 🟡 A3 — OPTIONAL · Price drift between `MonetizationDefs` and the Hub

`robux` in the defs is what the shop row *prints*; the Hub is what the player is *charged*. Nothing
reconciles them, and Extra Inventory Slots has managed pricing enabled. A mismatch shows a wrong price,
not a wrong charge. Worth a one-time `GetProductInfo` reconciliation pass; cheap, low risk.

### 🟡 A4 — OPTIONAL · Self Revive is invisible in the lobby

Correct by design (it's a contextual buy, bought while downed). Noting it only so a future reader
doesn't "fix" it by adding it to the lobby shop, where it would be a meaningless purchase.

### GAME.md monetization table — reconciliation

`GAME.md` *What we actually sell* lists 5 live items. All 5 are in `MonetizationDefs`, all 5 have Hub
ids, all 5 have working effects. **No item is sold-but-unimplemented, and no promised item is
unsold.** The Job 067 class of bug (live pass delivering nothing) does not recur — except for the
Cosmetic Bundle's lingering Hub listing (A2).

---

# Part B — ASSETS.md §1 (lobby) coverage, section by section

## ✅ Fully covered — no action

| § | Area | State |
|---|---|---|
| 1.1 | Foliage | 175 models placed, 8 library masters, grass tufts built. Vines dropped by decision. Rejected pack logged. |
| 1.2 | Landmark | Plane (Meshy, PreciseConvexDecomposition), rigged Pilot + idle anim, 5-tile runway |
| 1.3 | Station buildings | All 4 Meshy stalls swapped in, `Station` attr + `Anchor` + prompt transferred |
| 1.4 | Party pads | v2 rebuilt, 4 pads, party badge, VFX, `Center` kept for detection |
| 1.5 | Water / dock | Store dock, built mooring post, per-player showroom boat (Job 066) |
| 1.11 | Ambient audio | 5 of 6 beds wired — see B4 |
| 1.12 | SFX | All 14 wired, 2D vs positional split correct, zero asset ids in scripts |
| 1.14 | Lighting | Warm-afternoon rig applied |
| 5 | Loading screen | Built + background art wired with editor override |

## Gaps

### 🔴 B1 — REQUIRED · `Leaderboard_Weekly` is an empty board (§1.6)

`greybox_placement.luau:157` builds it. **Nothing anywhere reads it** — `grep Leaderboard_Weekly`
returns exactly one hit, the line that creates it. `RankServer` binds only `Leaderboard_TopRuns`
(`:126`) and has no Weekly branch at all.

`ASSETS.md` §1.6 claims *"Weekly = 'coming soon' placeholder"*. There is no such placeholder in code —
the board carries only the greybox `lbl()` billboard reading **"WEEKLY"** over a blank face. A player
walks up to a titled, framed, empty board. Required because it reads as broken, and the fix is either a
one-line SurfaceGui or deleting the board.

### 🔴 B2 — REQUIRED · Station entry signs (§1.3, last row · open `todo/0018`)

`ASSETS.md` §1.3 row *"Sign boards (per station) · 4+ · ▫ queued"*. Two of the four stations got an
entry sign during their Meshy swap (SkillTrainer, RobuxShop); **Bounties and BoatUpgrades did not** —
their notes list only *"Station attr + Anchor/prompt transferred, grounded, localized"*.

Right now those two are identified purely by the distance-culled `BillboardGui`, which is what
`todo/0018` explicitly says is not good enough. Required as the last visibly-unfinished piece of the
otherwise-complete station set.

### 🔴 B3 — REQUIRED · The spawn "airfield star" is still a greybox cylinder (§1.8)

§1.8 lists the painted military star as **⏸ pending (you)** — the decal was never generated. What is
in the place is `greybox_placement.luau:55`: a cream `SmoothPlastic` cylinder named `Star`, 11 studs
across, sitting on the spawn pad. **This is the first thing every player sees on join.** Required — it
is greybox on the spawn point.

### 🟡 B4 — OPTIONAL · Jungle day ambience 2 is uploaded but not wired (§1.11)

`ASSETS.md` §1.11 says *"Jungle day ambience 1 **& 2** — ✅ wired"*. `LobbySoundscape` defines and
plays `Ambience1` only. Ambience 2 exists in the registry (`120011248667884`, *"ambient bed variant"*)
and is dead weight. One-line fix or a doc correction; a single bed sounds fine, so optional.

### 🟡 B5 — OPTIONAL · Camp prop long tail (§1.7)

Still `▫ queued`: **fuel can** (1) · **lantern / tiki torch** (2+) · **toolbox / spare tire / cargo
pallet / rope / radio**. Explicitly P3 "fine detail" in the §1 priority line. The lantern gap also
blocks the torch-flame VFX (B7) and the lantern half of the built directional markers.

### 🟡 B6 — OPTIONAL · Ground path decals (§1.8)

Curved sand/dirt/tire-track paths connecting the zones, `⏸ pending (you)`. Styleguide §24 wants them;
nothing breaks without them.

### 🟡 B7 — OPTIONAL · Two VFX blocked or deferred (§1.10)

- **Torch / lantern flame** — `▫ queued`, blocked on B5's props.
- **Flag / tarp wind sway** — `▫ deferred`, "needs per-frame cloth anim; low value". Agreed; leave.

All 11 other lobby VFX are built.

### 🟡 B8 — OPTIONAL · Countdown / launch music layer (§1.13)

`⏸ pending`, marked optional in the doc itself. The launch already has the `teleport_woosh` cue and
per-second `timer_countdown` ticks, both positional on the pad — so the moment is not silent.

### 🟡 B9 — OPTIONAL · The 7 upgrade-item renders (§1.9b)

`▫ to generate`: Twin Motors · Reinforced Hull · Searchlight Rig · Extended Fuel Tank · Cargo capacity
· Mounted Gun Upgrade · Gold chest. `ASSETS.md` already states these block only the Boat-Upgrades panel
and buy popup *looking like the mockup* — both work today with the flat §1.9 glyphs via
`Theme.moduleIcon`. **Blocked on user generation**, so it can't be a required item on a code job.

> **Do not re-scope this to 16 renders × 3 levels.** §1.9b was corrected on 2026-07-30: modules are
> one-time unlocks (no tiers) and skills go to level 10 (per-level art impossible).

### ✅ §1.9 icons — nothing left to source

All 23 sourced, uploaded, Studio-verified, and every one is referenced from `Theme.icon`. Cross-checked
each key against its consumers: all 23 are live, none orphaned.

One live consequence worth carrying forward, not a gap: the delivered set is **full-colour flat**, not
the mono silhouettes §1.9's tint table assumed. `Theme.icon`'s comment and §1.9's colour note both
record this, and the code correctly seats them on dark chips instead of tinting. **Decide by eye at
restyle time** whether they fight the muted jungle palette.

---

# Part C — GAME.md's lobby promises vs the code

| GAME.md promise | State |
|---|---|
| "Lobby place — players gather and team up (~1–6)" | ✅ 4 pads × `MAX_PER_PAD = 6` |
| "teleported to a private reserved gameplay server" | ✅ `ReserveServerAsync` + `TeleportAsync`, 3 retries, seed/partySize/members in teleport data |
| Meta currency spent in the lobby on **boat upgrades** | ✅ 7 modules, `ModulesShop` + `ModulesServer` |
| …and on **skills/classes** | ✅ 10 skills × 10 levels, `SkillShop` + `SkillServer` |
| …and on **starting gear** | ❌ **gap C1** |
| "Run objectives … pay bonus cash + meta currency" | ✅ 3 weekly objectives, `RetentionDefs` + `RetentionClient` |
| Score & leaderboards, "Global + friends boards" | ⚠️ global Top 10 by River Score ✅; **friends board ❌ — gap C2**; weekly board ❌ (B1) |
| Boat skins chosen in the lobby, shown on the moored boat | ✅ Job 067, 6 liveries |
| Daily rewards | ✅ 7-day cycle + 30-day milestone + 2-day grace |

### 🟡 C1 — OPTIONAL · "Starting gear" is never sold

`GAME.md` *Economy & monetization* lists three Gold sinks: boat upgrades, skills/classes, **and
starting gear**. Two are built; there is no starting-gear/loadout purchase anywhere in the lobby.
Optional — it's a design line, not a broken feature, and the Gold economy already has two healthy
sinks.

### 🟡 C2 — OPTIONAL · Friends leaderboard is unbuilt

`GAME.md` says *"Global + friends boards"*. Only global exists (`OrderedDataStore`, Top 10). Optional
for a pre-launch lobby.

### ✅ Mobile-first

Checked against `GAME.md`'s hard requirement. `EntryBar` replaced four hardcoded-pixel buttons with one
scale-based, safe-area-aware `Components.iconBar`; `Theme.text` caps every size with a
`{max, min}` clamp; `Theme.rowHeight` documents its Device-Emulator verification. Compliant.

---

# Part D — Code-level findings (lobby tree)

### 🔴 D1 — REQUIRED · `LobbyConfig.PAD_COUNT = 3` is dead **and wrong**

The place has **4** pads (Blue/Red/Green/Yellow). `grep PAD_COUNT` across both trees returns exactly
one hit — its own declaration. `LobbyServer` discovers pads by `Station == "PartyPad"` attribute, so
the constant is never read.

Required not for behaviour (nothing breaks) but because it is a **lying config value** in the file a
future reader will open first to change the party setup. Delete it, or make it authoritative.

### 🟡 D2 — OPTIONAL · Pad occupancy is an unconditional Heartbeat loop

`LobbyServer:379` runs every frame, gated to real work every 0.3 s, and inside that does
`#pads × #Players` distance checks plus a `Workspace:GetDescendants()`-free path. Fine at lobby scale.
Noting it only because `GAME.md`'s mobile perf budget is a standing constraint. No action now.

### 🟡 D3 — OPTIONAL · `findStation` walks all of `Workspace` per station

`LobbyStations:33` and `LobbyServer:38` each do a full `Workspace:GetDescendants()` scan, retried every
0.2 s for up to 15 s at startup. Startup-only, five callers, invisible to players. Only worth touching
if the lobby place grows a lot.

### ✅ Checked and clean

- **No asset id is hardcoded in a screen script.** Every id resolves through `Theme.icon` /
  `Theme.sound` / `Theme.productIcon`. Spot-checked all 10 UI files — the rule holds.
- **`LobbySignage` correctly skips `PadSign`**, which `LobbyServer` owns and rewrites — the two would
  otherwise race at startup.
- **Server authority on launch**: `startCountdown` re-checks `pad.occupants[1] ~= leader` server-side.
- **`ProcessReceipt` is idempotent** via `prof.purchaseIds[PurchaseId]`, and saves promptly on real
  money.
- **`GAMEPLAY_PLACE_ID` is set** (`138141472932347`) — teleport is live, not a Studio placeholder.
- `findings/0002` (analyzer nil-warning) and `findings/0003` (invisible cargo module) are both **fixed**
  and verified in the current code.

---

# Part E — Greybox sweep ⏳ *blocked on Studio*

**Status: NOT VERIFIED.** Studio MCP is not connected in this session. Per the user's decision this
half runs live via MCP once the LOBBY place is open. Until then, *"no greybox left"* cannot be claimed.

The risk is specific: `lobby/build/greybox_placement.luau` **builds** the stand-ins, and every
replacement since has been *"localized to `AssetLibrary/…` and placed"* — a phrasing that does not
guarantee the greybox original was deleted rather than left underneath. `ASSETS.md` §1.7 is the one
place that explicitly says a greybox set was *replaced* ("25 models, replaced 41 greybox placeholders").

### What to sweep — the greybox signature, item by item

Every part below is created by `greybox_placement.luau` with a known name, size and colour. The sweep
walks `Workspace.LOBBY_GREYBOX` and flags anything still matching.

| Greybox object | Line | Should have been replaced by | Priority |
|---|---|---|---|
| `Spawn.Star` — cream cylinder 11⌀ | :55 | §1.8 airfield-star decal (**never generated** — B3) | 🔴 known live |
| `Spawn.Pad` — sand cylinder 26⌀ | :54 | possibly intentional; confirm | 🔴 |
| `Plane.*` — Fuselage/Cockpit/Nose/Wings/Tail/Engine/Prop/Gear (13 parts) | :64-75 | `Scenery.Plane` Meshy MeshPart | 🔴 |
| `Plane.Pilot.*` — Legs/Torso/Head blocks | :78-80 | rigged `workspace.Pilot` | 🔴 |
| `PartyPad_*.Ring` / `.Center` | :89-90 | pad v2 rebuild (`Center` **kept on purpose** for `LobbyServer` detection) | 🟡 expect `Center` |
| Stall geometry — Floor/BackWall/WallN/WallS/Counter/Roof/Sign/FlagPole/Flag ×2 | :103-111 | Meshy SkillTrainer + Bounties | 🔴 |
| `RobuxShop.Base/Kiosk/Roof` | :120-122 | Meshy kiosk | 🔴 |
| `BoatUpgrades.Bench/Rig/Arm/Sign` | :129-132 | Meshy mechanic rig | 🔴 |
| `Dock.Pier` + 8 `Post`/`Post2` + `Winch` | :139-143 | Store dock + built mooring post. ⚠️ **`Pier` is deliberately kept** — `LobbySoundscape:101` attaches the water loop to it. Confirm it is invisible/`CanCollide=false`, not a plank floating in the real dock | 🔴 |
| `Leaderboard_*` PostL/PostR/Board/Trim ×2 | :150-153 | built wood+trim boards; `RankServer` fills `TopRuns`' `Board` — that part is **load-bearing** | 🟡 |
| `WelcomeSign.*` | :162-165 | built welcome sign | 🟡 |
| `Watchtower_N*` Leg×4/Platform/Rail/Roof | :172-175 | RangerTower @0.7. ⚠️ `LobbySoundscape:114` resolves these **by model name** — the rope creak must still find a part | 🔴 |
| `RunwayMarkings.Dash` ×9 + `Threshold` ×4 | :184-185 | user-made runway "27" + stripes (§1.8 ✅ done) — **likely double-painted** | 🔴 |
| Camp props: `Crate`×12, `Barrel`×9, `TentFloor`/`TentRoof`×2, `FirePit`/`Logs`/`Flame`×2, `Sandbag`×7 | :190-210 | 25 Store props (§1.7 says 41 greybox replaced). ⚠️ **`FirePit` is load-bearing** — `LobbySoundscape:108` matches `p.Name == "FirePit"`. The neon `Flame` part should be gone (§1.10 built real Fire/Smoke/embers) | 🔴 `Flame` |
| `foliage()` clumps ×10 — `Trunk`/`Canopy` ball/`Bush` ball | :213-215 | 175 foliage models | 🔴 |

### Load-bearing greybox — do **not** delete blind

Four greybox parts are wired by name and must survive or be re-pointed. This is the trap in the sweep:

| Part | Read by |
|---|---|
| `PartyPad_*.Center` | `LobbyServer:48` (pad detection), pad VFX |
| `Dock.Pier` | `LobbySoundscape:101` (water loop) |
| `FirePit` (×2) | `LobbySoundscape:108` (campfire crackle) |
| `Leaderboard_TopRuns.Board` | `RankServer:127` (the live Top-10 SurfaceGui) |
| `Watchtower_NW` / `_NE` (model names) | `LobbySoundscape:114` (rope creak) |

### Also to verify live

- 🔴 **`Lighting.Technology = Future`** and the atmosphere rig are actually saved into the place —
  `ASSETS.md` §1.14 warns *"Save the place or it resets."*
- 🔴 **Boat mesh import + `preparePaintLibrary()`** was run and saved in the lobby place, or liveries
  render flat (§2).
- 🟡 **`RampBow` known art defect** (§2): imported with a square footprint, so at 6 wide it is 6 deep
  and rides *under* the gun base rather than in front of it. Visible on the showroom boat.
- 🟡 Stray parts **outside** `LOBBY_GREYBOX` (an earlier `LOBBY_BLOCKOUT` folder is destroyed at
  :19, but only if the build script was re-run).

---

# Summary — the gap list

## 🔴 Required (7)

| # | Gap | Kind |
|---|---|---|
| A1 | `RobuxShop` shows a buy button for passes the player already owns | code |
| A2 | Cosmetic Bundle Hub listing still live (Job 067 carry-over) | **user** |
| B1 | `Leaderboard_Weekly` is a framed, titled, empty board | code |
| B2 | Bounties + BoatUpgrades have no physical entry sign (`todo/0018`) | build |
| B3 | Spawn "airfield star" is still a greybox cream cylinder | **user art** |
| D1 | `LobbyConfig.PAD_COUNT = 3` — dead and wrong (there are 4) | code |
| E | **The whole greybox sweep** — unverified until Studio is open | live |

## 🟡 Optional (11)

A3 price reconciliation · A4 self-revive visibility (no action) · B4 ambience 2 unwired · B5 camp prop
long tail · B6 ground path decals · B7 torch flame (blocked) + wind sway (deferred) · B8 countdown
music layer · B9 the 7 upgrade renders (blocked on generation) · C1 starting gear unsold · C2 friends
leaderboard · D2/D3 perf micro-notes

## Doc corrections `ASSETS.md` needs regardless

Three rows currently claim more than the code does:

- §1.11 — "Jungle day ambience 1 **& 2** ✅ wired" → only 1 is wired.
- §1.6 — "Weekly = 'coming soon' placeholder" → there is no placeholder, the board is empty.
- §1.9 — the screen list omits `PaintShop`, `TopBar`, `AdminClient`, `EntryBar`, which all exist and
  consume icons.

## Open questions for the plan

1. **`Leaderboard_Weekly`** — build a real weekly board (needs a weekly `OrderedDataStore` + rollover),
   ship a genuine "coming soon" face, or remove the board until there's data?
2. **A1's owned state** — just disable the row with a `check` badge, or hide owned passes entirely?
3. **B3's spawn star** — generate the decal, or drop the star and let the sand pad stand alone?
4. **Sweep aggressiveness** — flag-and-report only, or also propose deletions for the follow-up job?

## Checklist

- [x] Desk audit completed (Parts A–D)
- [ ] Live greybox sweep completed (Part E) — **needs Studio + MCP**
- [ ] Implementation plan created & agreed
- [ ] Findings/todos filed + follow-up job intakes opened
- [ ] Final summary + changelog written
