# Implementation Plan — Job #123

**Project**: `roblox.jungle`
**Created**: 2026-08-27 21:02:10
**Status**: Implemented & verified in Play (2026-08-27)

## 1. What was decided (wizard, 2026-08-27)

| Question | Answer |
|---|---|
| What is a "camp"? | The **river stop / landing site**. Six per run, at docks 1, 3, 5, 7, 9, 11 → z = 1600, 4800, 8000, 11200, 14400, 17600. Each has exactly **one** trading post. |
| Stock spread | **Stocked from then on.** M16 at stops 2–6, Bazooka at stops 3–6. A crew that arrives broke can save and buy it later; the price is the wall, not a one-time window. |
| Ammo limit | **Salvage is the only limit** — buy as many boxes as you can afford, exactly like pistol/shotgun ammo works today. |

## 2. The stock table

| Stop | z | Base stock | New |
|---|---|---|---|
| 1 | 1600 | bandage · pistolAmmo · shotgunAmmo · fuel · ammo · repair · pistol · shotgun | — |
| 2 | 4800 | " | **M16 · M16 Ammo** |
| 3 | 8000 | " | **M16 · M16 Ammo · Bazooka · Bazooka Ammo** |
| 4–6 | 11200+ | " | same as stop 3 |

## 3. The economy, measured from the code

Everything below is read out of the source, with the file it came from. Randomised values are given
min–max with the average used in the arithmetic.

### 3.1 What one landing site pays

| Source | Count/site | Each | Avg total | Where |
|---|---|---|---|---|
| Resource crates (near: 2 × Gasoline; deep: Metal + Ammo) | 4 | 40 | 160 | `ExcursionServer:1033`, call sites `:2528–2529` |
| Weapon crate (deep camp) | 1 | 80 | 80 | `ExcursionServer:997` |
| Handheld ammo crate (deep camp) | 1 | 40 | 40 | `ExcursionServer:1017` |
| Watchtower chests — **both** towers carry one | 2 | 45–70 | 115 | `CampDefs.TOWER.chest:572`, `KIND.near/deep tower = true:526,532` |
| Village hut stashes — 6–10 huts × 75% chance | ~6 | 25–40 | 195 | `CampDefs.VILLAGE.stash:309–312` |
| Yard barrels | 3–5 | 12–22 | 68 | `CampDefs.VILLAGE.yardLoot:372–377` |
| Gold nugget (25%/camp × 2 camps, run-capped) | ~0.5 | 30 salvage + 1 gold | 15 | `ExcursionServer:648` |
| **Loot subtotal** | | | **673** | |
| Land kills — guards + 2 hut bandits + Rocket Man | 6 (stop 1) / ~8 (stop 2+) | 6 | 36 / 48 | `KillReward.LAND_SALVAGE:32` |
| Reinforcement kills over a 3–6 min stop | ~1–2 | 6 | ~9 | `ExcursionServer:3204` |
| **Site total** | | | **~718 (stop 1) · ~730 (stop 2+)** | |

Two things worth noting about how that splits across a crew:

- The **distance drip** (1 Salvage / 60 studs, `SalvageServer.DRIP_STUDS:12`) pays **every player the
  full amount** — 26 to reach stop 1, then 53 per 3200-stud leg.
- Everything in the table above is **one object, one looter**. But only the four resource crates
  require the carry/`Busy` trip; the weapon crate, ammo crate, both tower chests, every hut stash and
  every yard barrel are **instant-grant**. So the split across a crew is decided by who covers ground,
  not by an even quarter — a player who runs the village and both towers collects ~500 of the 673 even
  in a four-stack, while a player who guards the boat earns close to drip only.

Prices are therefore set against **a thorough raider**, which is the crew member who walks up to the
counter.

### 3.2 Objectives (crew-wide, `ObjectiveDefs:18–21`)

- 🔴 `hunter` — "15 threats" → 120. **Excluded from the budget.** The independent reviewer found that
  `RunKills` is written in exactly one place — `EnemyServer:460`, the *river creature* tick — and
  `ExcursionServer` never writes it at all. **No camp guard, hut ambusher or Rocket Man counts toward
  it.** So raiding cannot earn this and it cannot be assumed at any stop. Logged as
  **finding 0042**; it is a real bug, and until it is fixed this 120 does not exist for a raider. My
  first pass counted it at stop 2 — removing it is the single biggest correction to the budget.
- `reachRapids` — zone 3 → **120**. Fires at z ≥ 9000, i.e. **between stop 3 and stop 4**. Counted in
  the stop-4 row only.
- `nightOwl` — survive a night on the water → 150. Dawn lands at ~10.7 min real time
  (`DayNightServer:31–33`), so which stop it falls on depends on how long the crew is ashore.
  Excluded — situational upside.

Bunkers (150/share) are in the end zone past z 17600 — irrelevant here.

### 3.3 Cumulative budget at each counter

Standing at that stop's post having cleared that site. Reviewer's arithmetic, cross-checked against
mine; the two agreed on the per-site pool (673) and the drip, and differed only on objectives.

| At the post of | Solo gross | Solo **disposable** (−~175/stop, `ShopDefs` essentials) | 4-crew member gross |
|---|---|---|---|
| Stop 1 | 735 | 735 | 203 |
| Stop 2 | 1,510 | **~1,335** (worst case 1,130) | 437 |
| Stop 3 | 2,287 | **~1,937** (worst case 1,527) | 673 |
| Stop 4 | 3,187 (incl. `reachRapids`) | ~2,662 | 1,031 |

A full solo run yields roughly **4,800**.

**Upside case — Scavenger's Instinct.** `SkillDefs` gives +3%/level to 10 = **+30%**, and it applies to
the whole loot pool but *not* to kills, nuggets, drip or objectives (`ExcursionServer:922–923`,
`KillReward:43–45`). A maxed looter's pool is 673 → 875, putting **~1,739 at the stop-2 counter** and
**~2,543 at stop 3**. That is the ceiling the prices must not fall under.

### 3.4 🔴 The crew-size problem, and why it does not block this job

The reviewer's sharpest finding: **the loot pool does not scale with crew size at all.** Nothing in
`buildLandingSite` reads player count except the guard-count `scale` (`:2459`). Every loot source is one
object that `:Destroy()`s itself, so exactly one player is ever paid; only the drip and objectives are
per-player. A 4-crew member therefore earns ~235/stop against a solo player's ~777, and by arithmetic
**never affords the existing 750 Shotgun inside a 6-stop run.**

Two reasons this does not change the prices:

1. **It is a race, not a split.** Only the four resource crates need the carry/`Busy` trip; the weapon
   crate, ammo crate, both tower chests, every hut stash and every yard barrel are instant-grant. One
   crew member who runs the village and both towers takes most of the 673 — and that is the player who
   walks up to the counter.
2. **The shop is already priced this way.** The 750 row predates this job and has the same property.
   Pricing the M16 above it is consistent with the shop as it exists, not a new problem introduced here.

Logged separately as **finding 0045** so it gets decided on its own merits rather than inside a pricing
job. If you want premium rows reachable by a four-stack, the fix is to scale the pool with crew size —
which is a balance job of its own and would then let these prices rise.

## 4. The prices

| Row | Price | Grants | Per unit | Sanity check |
|---|---|---|---|---|
| **M16** | **1,250** | gun + 30 bursts | — | 1.67× Shotgun (750), 3.1× Pistol (400). **94% of the stop-2 disposable budget** — it costs essentially everything camps 1+2 paid. ~26% of a whole run's income. |
| **M16 Ammo** | **350** | 10 bursts | 35/burst | 0.125 Salvage per damage (280/burst) against the Shotgun's 0.104 — dearer per damage, as the premium gun should be. |
| **Bazooka** | **1,800** | gun + 6 rockets | — | 2.4× Shotgun, 1.44× M16, 4.5× Pistol. **93% of the stop-3 budget if you skipped the M16.** ~38% of a whole run's income. |
| **Bazooka Ammo** | **500** | 2 rockets | 250/rocket | The most expensive shot in the game, deliberately — see §5. |

### Repriced after the reviewer's measurement

My first pass proposed 1,250 / 2,000 against a stop-2 budget of ~1,450 and a stop-3 budget of ~2,030.
Both budgets came down once `hunter`'s 120 was removed (§3.2) and the reviewer's measured spend replaced
my guess:

| | first pass | corrected | price | % of budget |
|---|---|---|---|---|
| Stop-2 budget | ~1,450 | **~1,335** | M16 1,250 | 94% |
| Stop-3 budget | ~2,030 | **~1,937** | Bazooka **1,800** ← lowered from 2,000 | 93% |

2,000 would have sat at 103% of the corrected stop-3 budget — i.e. **not affordable at the stop where it
first appears**, which is the one thing the brief rules out. 1,800 is the same 93% ratio the M16 has.

Both sit under the *typical* budget and well under the maxed-Scavenger ceiling (1,739 / 2,543), so a
skilled looter buys comfortably and an unlucky run slips one stop later — which the "stocked from then
on" decision already covers.

### The consequence that makes this work

You can afford **one premium weapon per run**, not both:

- Skip the M16 → Bazooka at stop 3 (1,800 of ~1,937).
- Buy the M16 at stop 2 → ~85 left, ~687 at stop 3, ~1,412 at stop 4, **Bazooka at stop 5**.

That is a real decision at the stop-2 counter rather than a shopping list, and it is why the ratio
between the two is not the 2.67× the Robux prices imply.

### No re-buy exploit

`InventoryService.grant` tops up ammo when the gun is already owned (`InventoryService:465–472`), so a
weapon row doubles as an ammo row — that is exactly the Job #104 pistol bug. Both ammo boxes are
cheaper per unit than re-buying the gun, so the exploit is priced out rather than blocked:

| | via ammo row | via re-buying the gun |
|---|---|---|
| M16 | **35** / burst | 41.7 / burst (1,250 ÷ 30) |
| Bazooka | **250** / rocket | 300 / rocket (1,800 ÷ 6) |

## 5. 🔴 The line this crosses, stated out loud

`ItemDefs.M16` and `ItemDefs.Bazooka` each carry an explicit comment saying their **missing
`ammoPerCrate` is the only thing holding the power line** on a `power = true` Robux purchase, and
`MonetizationDefs`' header says a fourth such item "needs a better argument than *there are already
three*". This job adds `ammoPerCrate` to both. That is the ask, and those comments must be rewritten
rather than left contradicting the code.

**It is worth saying that this change makes the monetization *fairer*, not worse.** The three
`power = true` items exist because the M16 and Bazooka could not be earned at any price — that was the
whole objection recorded in Jobs #117 §10 and #118 §8. After this job Robux buys **time and
convenience**, which is the rule `MonetizationDefs` is written to defend:

- you get the weapon from the **start of the run** — through the river legs and camps 1–2, when you are
  weakest and have no Salvage;
- you keep the 1,250 / 1,800 Salvage for fuel, repairs and bandages;
- the lifetime pass means **every run**, no grind.

**The risk to flag:** the 150 R$ and 250 R$ lifetime passes lose their exclusivity, so conversion may
dip. Against that — a weapon a player can *see on the shelf at camp 2 and want at camp 1* is a better
funnel than a shop row nobody understands. This is your call to make, not mine; if you would rather
protect the passes, the lever is the Salvage price, not the stock table.

## 6. Implementation steps

Game place only (`sync/`). The lobby tree is **not touched** — it has no trading post, no Salvage and
no loadout.

1. **`ReplicatedStorage/Inventory/ItemDefs.luau`** — add `ammoPerCrate = 10` to `M16` and
   `ammoPerCrate = 2` to `Bazooka`. Rewrite both "⚠️ NO `ammoPerCrate`" blocks to record that the cap
   is now a *price*, not an absence, and that the lever is the price, not `damage`/`blastDamage`.
   - ⚠️ Checked: this cannot leak into camp loot crates. The camp `Kind == "Ammo"` crate reads
     `ItemDefs.ammoPerCrate` for `weaponId`, and `weaponId` is only ever `Pistol`/`Shotgun`
     (`ExcursionServer:2611`). No camp crate will grant M16 bursts or rockets.
2. **`ReplicatedStorage/Economy/ShopDefs.luau`** — four new rows and a new field:
   - `m16` 1,250 · `m16Ammo` 350 (`ammoFor = "M16"`) · `bazooka` 1,800 · `bazookaAmmo` 500
     (`ammoFor = "Bazooka"`). Amounts resolve through the existing `perBox()` helper, never hand-typed.
   - add `minStop: number?` to `ShopItem` — the landing ordinal a row first appears at. Generic, so a
     fifth weapon is data only.
   - `ShopDefs.Order`: restocks stay first (the panel shows ~3 rows on a phone,
     `ShopDefs.luau:41–45`), so the four new rows go **after** `shotgun` — an M16 you buy once must not
     push the bandage row off screen.
   - `ShopDefs.stockedAt(stop)` helper, so client and server share one answer.
3. **`ServerScriptService/World/CampDefs.luau`** — retire the `TOWER.chest` note that says making it
   top up rockets was rejected *because* rockets cannot be bought. The chest stays Salvage (that part of
   the reasoning still holds — it is not an ammo crate), but the stated reason is now false.
4. **`ServerScriptService/Excursion/ExcursionServer.server.luau`** — pass the landing ordinal into
   `buildTradingPost(postPos, model, shorePoint, tier)` and, on prompt trigger, publish it
   server-side as a **monotonic high-water mark** (`player:SetAttribute("ShopStop", max(current, tier))`)
   before `openShop:FireClient(player, tier)`.
   - `tier = math.ceil(index / 2)` already exists at `:2457` and is exactly the landing ordinal.
   - Monotonic on purpose: it matches the "stocked from then on" decision and cannot go stale.
   - Server-authoritative: a client can scribble on its local copy of a Player attribute, but that
     write does not replicate, and §5's gate reads the **server's** value.
5. **`ServerScriptService/Economy/SalvageServer.server.luau`**
   - generalise the weapon branch: `applyItem`'s `id == "pistol" or id == "shotgun"` becomes a
     `grants: string?` field on the row, so the four new rows need no code here (same move Job #104
     made for `ammoFor`).
   - **gate the buy** on `ShopStop >= def.minStop`, returning a new `"locked"` error. Without this the
     row is a client-side suggestion and the M16 is buyable from the boat at stop 1.
6. **`StarterPlayer/StarterPlayerScripts/UI/DockShopClient.local.luau`**
   - `ITEM_ICON`: `m16 = "rifle"`, `m16Ammo = "rifleAmmo"`, `bazooka = "bazooka"`,
     `bazookaAmmo = "rocketAmmo"`. **All four already exist** in `Theme.icon` (`:169`, `:174`, `:186`,
     `:187`) — and `:172` already predicted this row: *"the natural glyph for an M16 ammo row if the
     trading post ever sells rifle rounds"*. No new assets needed.
   - rows are built once at startup, so `refreshAll` gains a visibility pass: hide any row whose
     `minStop` exceeds the stop the panel was opened at. Take the stop from the `OpenShop` payload.
   - `"locked"` needs no new copy — a hidden row cannot be tapped; the server check is the backstop.

### Deliberately NOT in scope

- **The Robux rows stay exactly as they are** — 30/80 R$ per-run, 150/250 R$ lifetime. §5 explains what
  they now sell.
- **`Granted_m16` / `Granted_bazooka` are untouched**, so the Robux one-run row still reads as buyable
  to a player who bought the weapon with Salvage. Buying it then just adds 30 bursts / 6 rockets — not a
  scam, but it is misleading. Logging this as a **finding** rather than fixing it here; it is a
  monetization-UI question, not this job.

## 7. Independent review (GROUND-RULES 8)

- [x] Agent run, without being told my theory — handed only "audit the in-run Salvage economy and report
      the numbers with citations". No mention of the M16, the Bazooka, this job's existence, or any price,
      so nothing it found could be an echo of my own model.

**Where it agreed with me** — the per-site loot pool (673 avg), the drip (`floor(z/60)`, per-player), the
six landing sites, `tier = ceil(index/2)`, and that both towers carry a chest. It also independently
confirmed that adding `ammoPerCrate` cannot leak into camp crates.

**Where it corrected me — three material changes to the prices:**

1. 🔴 **`hunter`'s 120 does not exist for a raider.** `RunKills` is written only by the river-creature
   tick; no camp kill counts. I had banked it in the stop-2 budget. → finding 0042, and −120 from every
   row of §3.3.
2. **It measured the spend I had guessed at.** Fuel is nearly free if the crew hauls both Gasoline
   crates (2 crates = 80 fuel; a 3200-stud leg costs 80–89 against a 100 tank), so mandatory spend is
   ~175/stop, not my ~200 — but ammo is dearer than I assumed at higher `strength`. Net effect on the
   stop-3 budget: ~2,030 → ~1,937, which is what moved the Bazooka from 2,000 to **1,800**.
3. **The crew-size gap is worse than I hedged.** It showed the loot pool has *no* crew scaling and that
   the existing 750 Shotgun is already unaffordable to a 4-crew member within a run — a stronger claim
   than my "spread is skill-based". Both are true (§3.4); it goes to finding 0045 rather than being
   absorbed into these prices.

**Also surfaced, all out of scope and logged:** findings 0043 (strength ramps 1.21×/landing, not the
recorded 1.10×), 0044 (end-zone chests pay ~120 dead Salvage), todos 0062–0064.

⚠️ Its numbers are still **read from source, not measured in a run** — as are mine. §9 check 5 is the
one that actually tests them.

## 8. What I need from you

- [ ] **Go-ahead on the four prices** (§4) — 1,250 / 350 / 1,800 / 500.
- [ ] **Acknowledge §5** — this converts three `power = true` items into convenience items and softens
      the two lifetime passes. Your call.
- [ ] **Studio open on the GAME place**, so the verification in §9 can run in Play.
- [ ] Nothing else. No assets, no Hub work, no IDs — all four icons are already uploaded and registered.

## 9. Verification — RESULTS (GROUND-RULES 7)

All of it run in **Play** on `Last River COOP Game` (PlaceId 138141472932347), 2026-08-27. Nothing here was
ticked from Edit — the shop panel is a `LocalScript` and the camps are built at runtime, so Edit shows
neither. Play was started by me and **stopped afterwards**; Studio was left in Edit.

- [x] **Reproduced in PLAY** at the real counter — a landing site was force-built (`ForceFirstCamp`), the
      character walked to the trading post, and the real `ShopPrompt` was triggered.
- [x] Not a "works in X, broken in Y" report.
- [x] **The analyzer was proved able to fail before being trusted.** `tools/luau-analyze.sh` returned exit
      0 with no output on the changed files, which is indistinguishable from not having run. So a
      deliberate error was injected twice — a syntax error (reported: `Expected <eof>`) and a type error
      (reported: `Expected 'number', but got 'string?'`, resolving the *new* `grants` field) — and removed.
      Only then was the clean run taken as evidence. Game tree: exit 0. Lobby tree: 4 diagnostics, all
      pre-existing (`PilotIdle` style, the dead pre-#067 `InventoryService` fork `RifleGrant`'s header
      documents) and none in the file touched there, which was comment-only.
- [x] **No world fact asserted from a constant** — see check 5. The per-site income was *measured on a
      real generated site*, not taken from the plan's averages.

### Checks — each said what failure would look like

| # | Check | Failure would have looked like | Result |
|---|---|---|---|
| 1 | Stop 1 does not stock the new rows | an M16/Bazooka row visible at the tutorial landing | ✅ real prompt at landing 1 → `ShopStop=1`, panel opened **8 visible / 4 hidden** |
| 2 | Stop 2 stocks M16 + M16 Ammo only | a Bazooka row at stop 2, or a missing M16 | ✅ 10 visible, Bazooka pair hidden |
| 3 | Stop 3 stocks all four | fewer than 4 new rows | ✅ 12 visible, correct prices + blurbs + 4 distinct icons |
| 4 | The server gate really gates | `{ok=true}` and a Bazooka in a slot from the boat | ✅ `locked` for all four, **and no Salvage deducted** (9549 held across 4 refusals) |
| 5 | The income model | measured site pool well under the prediction | ✅ **measured 705 vs predicted ~718 (−1.8%)** — see below |
| 6 | The weapon works when bought with Salvage | greybox block, or the burst latch not applying | ✅ `HeldItem` is a **MeshPart** (`rbxassetid://101680702520520`), not the `Part` fallback; one trigger pull took AmmoM16 **70 → 69** |
| 7 | Ammo rows require the gun | 350 charged for rounds nothing reads (the #104 bug) | ✅ `nogun`, nothing deducted |
| 8 | No re-buy exploit cheaper than the ammo row | ammo dearer per unit than re-buying the gun | ✅ live: M16 35/burst vs 41.7; Bazooka 250/rocket vs 300 |

**Purchase arithmetic, live:** 9549 → bandage −50 → pistol −400; then at stop 2 M16 −1250 (8299) and
M16 Ammo −350 (7949, AmmoM16 30→40 = exactly `ammoPerCrate`); at stop 3 Bazooka −1800 (6149,
AmmoBazooka 0→6) and Bazooka Ammo −500 (5649, 6→8). Later, from the plan's own predicted stop-3 budget:
**1937 − 1250 = 687**, matching §4 to the unit.

**Stock table measured against the live river** (`RiverData.docksBetween`, not the comment): 11 docks, 6
landings at z 1600/4800/8000/11200/14400/17600, `tier` = 1…6, M16 from landing 2, Bazooka from landing 3.

### 🔴 The check that earned its keep

Check 4 **failed on the first run and caught a regression I had introduced.** `bandage` came back
`locked` alongside the four new rows. Cause: `stockedAt` was written `stop >= (def.minStop or 1)`, and
`stop` is legitimately **0** before any post is visited (`resetAll` sets it; a nil attribute reads as 0) —
so `0 >= 1` locked *every pre-existing row in the shop*. Fixed to gate only rows that opted in
(`if not minStop then return true end`), re-verified: base rows buy at stop 0, gated rows refuse. The
failure mode is recorded in a 🔴 comment on the function so it is not re-introduced.

Two further harness notes, so the next reader does not repeat them: `ProximityPrompt.PromptShown` does
**not** fire in this context even for untouched prompts (a control test on the crash-site Robux kiosk
confirmed it), so it is useless as a signal — use `Triggered`; and `InputHoldBegin` needs the character to
have **settled** after a server-side teleport, which is why the first shop-prompt attempt read `ShopStop=0`.

### Measured income (check 5, the one that tests the prices)

Enumerated every `LootCrate` and standing enemy in the real generated landing site 1:

| Component | Measured | |
|---|---|---|
| Salvage crates (2 tower chests + hut stashes + yard barrels) | 13 crates | 389 |
| Resource crates (2 Gasoline, Metal, Ammo) | 4 | 160 |
| Weapon crate (Pistol) | 1 | 80 |
| Handheld ammo crate (Pistol) | 1 | 40 |
| Standing enemies @ 6 (1 near + 2 deep + 2 hut + 1 Rocket Man) | 6 | 36 |
| **Measured total** | | **705** |
| Plan §3.1 prediction for stop 1 | | ~718 |

The randomised components the plan was least sure of — 6–10 huts × 75%, 3–5 yard barrels, 2 chests at
45–70 — came in at **389 against a predicted 378**. The model holds.

### ⚠️ What is still NOT measured

**A full solo run to the stop-2 counter.** The per-site pool is now measured, but the *cumulative* figure
(~1,335 disposable at stop 2) also assumes ~175/stop of essential spend and that the crew clears
thoroughly — both player behaviour, not code. So the prices are validated against a measured site pool,
not against a played run. If the M16 feels out of reach at stop 2 in real play, the lever is
`ShopDefs.m16.cost`, and finding 0042 (`hunter`'s unreachable 120) is the first thing to fix — it would
raise both budgets by 120 on its own.
