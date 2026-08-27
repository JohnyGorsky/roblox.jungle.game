# Final Summary — Job #123

**Project**: `roblox.jungle`
**Status**: Implemented & verified in Play, 2026-08-27
**Studio**: `Last River COOP Game`, PlaceId 138141472932347

## What was asked

The M16 and the Bazooka could only be bought with Robux. Sell them for in-run **Salvage** at the camp
trading posts — camp 2 stocks the M16 and its ammo, camp 3 adds the Bazooka and its ammo — priced high
but reachable on what a crew earns clearing camps 1 and 2.

## What shipped

**Prices** (measured against the run's income, not chosen for feel — see the plan §3–§4):

| Row | Price | Grants | Stocked from |
|---|---|---|---|
| M16 | **1,250** | gun + 30 bursts | landing 2 |
| M16 Ammo | **350** | 10 bursts (35/burst) | landing 2 |
| Bazooka | **1,800** | gun + 6 rockets | landing 3 |
| Bazooka Ammo | **500** | 2 rockets (250/rocket) | landing 3 |

Once unlocked a row stays stocked at every later stop (owner's call: the price is the wall, not a
one-time window). Ammo is limited only by Salvage, like every other ammo row.

The prices sit at **94%** and **93%** of the disposable Salvage a thorough raider holds at the counter
where each first appears, which produces the property the whole design rests on: **you can afford one
premium weapon per run, not both.** Buy the M16 at landing 2 and the Bazooka is out of reach until
landing 5; skip it and the Bazooka is yours at landing 3.

## Files changed (game place only — `sync/`)

| File | Change |
|---|---|
| `ReplicatedStorage/Inventory/ItemDefs.luau` | `ammoPerCrate = 10` on M16, `= 2` on Bazooka. Both "⚠️ NO `ammoPerCrate`" blocks rewritten — the cap is now a **price**, not an absence. |
| `ReplicatedStorage/Economy/ShopDefs.luau` | 4 new rows; new `grants` and `minStop` fields on `ShopItem`; `ShopDefs.stockedAt()`; `Order` extended (new rows go **last** — the mobile rule the file already carried). |
| `ServerScriptService/Economy/SalvageServer.server.luau` | weapon branch generalised to `def.grants`; **server-side stock gate** on buy (`"locked"`); `list` returns `stop`; `ShopStop` reset with Salvage. |
| `ServerScriptService/Excursion/ExcursionServer.server.luau` | `buildTradingPost(…, stop)`; the prompt publishes the landing as a monotonic `ShopStop` high-water mark. |
| `ServerScriptService/World/CampDefs.luau` | `TOWER.chest`'s stated reason was retired by this job; rewritten with the reason that still holds. |
| `StarterPlayer/…/UI/DockShopClient.local.luau` | 4 icon mappings; rows hidden (not muted) when the post does not stock them. |
| `ReplicatedStorage/Progression/MonetizationDefs.luau` **(both trees)** | comment-only: records that Robux now buys time, not access. Both copies verified byte-identical afterwards. |

**No new assets.** All four icons already existed in `Theme.icon` — `rifle`, `rifleAmmo`, `bazooka`,
`rocketAmmo`. `Theme.icon:172` had already been registered against this exact row.

**Two new generic concepts**, so a fifth weapon is data only: `grants` (replaces the hardcoded
`id == "pistol" or id == "shotgun"`) and `minStop`. Neither the client, the server, nor `ExcursionServer`
knows anything about the M16 or the Bazooka by name.

## The monetization line, on the record

`ItemDefs` said the missing `ammoPerCrate` was *"the only thing holding the line"* on three
`power = true` items, and `MonetizationDefs` said a fourth would need a better argument. This job adds
that field. Those comments were rewritten rather than left contradicting the code.

**The change makes the monetization fairer.** The P2W objection recorded in Jobs #117 §10 and #118 §8 was
precisely that these weapons could not be earned at any price. Robux now buys **time**: the weapon from
the start of the run (the river legs and camp 1, when you are weakest and broke), every run, without
spending 1,250/1,800. That is convenience, which is the rule `MonetizationDefs` exists to defend.

**Flagged to the owner and accepted:** the 150 R$ / 250 R$ lifetime passes lose their exclusivity, so
conversion may dip. The lever if that matters is the Salvage price, not the stock table.

## Verification

Full results in the plan §9. Everything in Play; Studio left in Edit.

- Real prompt at landing 1 → `ShopStop=1`, panel **8 visible / 4 hidden**. Stop 2 → 10 visible. Stop 3 →
  all 12, correct prices, blurbs and 4 distinct icons.
- Server gate refuses `locked` **and deducts nothing**; ammo rows refuse `nogun` and deduct nothing.
- A Salvage-bought M16 holds the real **MeshPart** art and one trigger pull costs exactly one round
  (70 → 69).
- **Measured the real generated landing site: 705 Salvage against the plan's predicted ~718 (−1.8%).**
  The randomised part the plan was least sure of came in at 389 vs 378 predicted.
- The analyzer was proved able to fail (injected syntax + type errors, both reported) before its clean
  run was trusted.

### 🔴 The regression the verification caught

Check 4 failed first time: `bandage` came back `locked` too. `stockedAt` was `stop >= (def.minStop or 1)`,
and `stop` is legitimately **0** before any post is visited — so `0 >= 1` locked **every pre-existing row
in the shop**. Fixed to gate only rows that opted in; the failure mode is now a 🔴 comment on the
function. Had check 4 only tested the new rows, this would have shipped.

### Still not measured

A full solo run to the stop-2 counter. The per-site pool is measured; the *cumulative* ~1,335 also
assumes ~175/stop of essential spend and a thorough clear — player behaviour, not code. If the M16 feels
out of reach in real play, the lever is `ShopDefs.m16.cost`.

## Independent review (GROUND-RULES 8)

One agent, handed only "audit the in-run Salvage economy and report the numbers" — no mention of this
job, the weapons, or any price. It **changed the prices**: it found the `hunter` objective's 120 Salvage
is unreachable by raiding (I had banked it at stop 2), and measured the essential spend I had guessed at.
Net effect: the stop-3 budget fell from ~2,030 to ~1,937, which moved the **Bazooka from 2,000 to 1,800** —
at 2,000 it would not have been affordable at the stop where it first appears, the one thing the brief
ruled out.

## Logged, out of scope

| # | | Severity |
|---|---|---|
| finding 0042 | `hunter` cannot be completed by raiding — `RunKills` ignores all camp combat | **high** |
| finding 0043 | Village strength ramps 1.21×/landing, not the recorded 1.10× | med |
| finding 0044 | End-zone tower chests pay ~120 Salvage where there is no shop | med |
| finding 0045 | The loot pool has no crew-size scaling — the 750 Shotgun is already solo-only by arithmetic | med |
| todo 0062 | Stale comment: `RiverData` says docks refuel, `DockServer` says they don't | — |
| todo 0063 | Decide: Rocket Man on landing 1 vs the Job #102 onboarding rule | — |
| todo 0064 | `NuggetsSpawned` is never reset, unlike `Salvage` and the bunkers | — |

Also **not** fixed, deliberately: `Granted_m16` / `Granted_bazooka` are untouched, so the Robux one-run
row still reads as buyable to a player who bought the weapon with Salvage. Buying it then adds 30
bursts / 6 rockets — not a scam, but misleading. That is a monetization-UI question, not this job.
