# Last River — Full Economy, Progression & Monetization Proposal

**Project**: `roblox.jungle` (working title "Last River") · **Job #020** · Research/design only, no code.
**Status**: Proposal for your review. Every number is a tunable recommendation with rationale; anything
needing your call is flagged in **§12 Decisions for you**. Built on the locked GAME.md economy (Dead
Rails three-tier, "fair, not pay-to-win") and the real in-code numbers (full run = **18,000 studs ≈
8–9 min**, boat cruise ≈ 35 studs/s, current placeholder `reward = floor(distance/10)`).

Backed by deep research into Dead Rails, Deep Rock Galactic, Risk of Rain 2, Lethal Company, Vampire
Survivors, Sea of Thieves, Slay the Spire, plus Roblox monetization/leaderboard docs — sources in §13.

---

## §0. TL;DR — the headline decisions

1. **Two earnable currencies, not more.** In-run **Salvage** (soft, resets each run) + persistent
   **Gold** (rare meta). Gasoline/Metal/Ammo are *resources*, not currencies. Robux is real money.
   Resist a 4th currency — fragmenting confuses players and dilutes each faucet.
2. **Gold is genuinely rare** — ~**10 per finished run** (Dead Rails Bonds precedent), never zero on a
   loss, up to ~18–20 on a mastery run. It's the *only* thing that buys power (skills + boat modules).
3. **The completion premium is the load-bearing mechanic.** Finishing pays a deliberate +4 Gold jump
   over dying at 99%, so players chase the *finish line* instead of farming-and-bailing (Dead Rails'
   actual flaw — it pays looting 10× more than finishing).
4. **10-skill tree, 1→10 each**, geometric cost ladder, maxing the *whole* tree ≈ **150–170 runs**;
   first meaningful buy in ~1–2 runs. Reconciled to the rare-gold scale (see §4).
5. **Gold IS sold for Robux** (full Dead Rails model — *your decision, 2026-07-19*). This makes the game
   pay-to-win by the strict definition; we counter the "greedy" perception with a generous free earn
   rate, no *exclusive* power behind Robux, and cosmetics kept as the headline sell (see §6 guardrails).
6. **Robux otherwise = cosmetics + convenience + consumable safety-nets.** The "armored boat" is a
   **cosmetic skin, identical stats**. Launch lean, expand after 2 weeks of data.
7. **Rank = a lifetime, non-decaying "River Score"** shown on an overhead lobby tag (10 named tiers
   mirroring the skill tree, Castaway → River Legend, then Legend ★ prestige). A *separate* resettable
   season/daily score serves competitors without ever knocking down someone's visible reputation.
8. **All scoring is server-authoritative** in the reserved gameplay server. The client never reports
   its own score (the Slay the Spire daily-leaderboard lesson).

---

## §1. Currency model

| Currency | Kind | Persistence | Earned by | Spent on | Note |
|---|---|---|---|---|---|
| **Salvage** (in-run cash) | Soft | **Resets each run** | Camp/dock loot + small distance drip | Dock shops: fuel, ammo, bandages, weapons, repair kits | Plentiful; creates "offense vs survival?" tension every run |
| **Gold** | Hard, earned | **Persistent** | Mainly *finishing* runs; partial on loss; rare nuggets | Lobby: skill tree + boat module unlocks | Deliberately rare; the *only* power currency |
| **Robux** | Real money | Persistent | Purchase | Cosmetics, convenience, consumable revives | Never buys Gold or power (§6) |

**Resources (NOT currencies):** Gasoline (move), Metal (repair), Ammo (fight) are in-run consumables
hauled to boat stations — keep them as physical resources, not spendable money.

**Why exactly two earnable currencies:** the proven pattern (Dead Rails Bonds/Money, DRG
credits/resources, RoR2 Lunar/gold) is one persistent + one resetting. More currencies fragment the
faucets and confuse new players. **Do not add a "seasonal token"** as a 3rd earnable currency — run the
battle pass off Gold + Robux directly (§9).

**Naming:** "Gold" per your brief. In-run cash I propose **"Salvage"** (fits the scavenging theme); if
you prefer plainer, "Cash" works. Open in §12.

---

## §2. Gold — the earn side (rare, finish-weighted)

Split the 18,000-stud run into **4 zones** with checkpoints at 25/50/75/100%. Gold is awarded
server-side on run end, scaled by the farthest zone reached, so even a wipe pays a token.

| Run outcome | Distance | Base Gold | + Objectives | + Nuggets (avg) | Typical total |
|---|---|---|---|---|---|
| Wiped early | 0–25% | **1** | — | ~0.3 | **~1** |
| Wiped mid | 25–50% | **2** | +0–1 | ~0.4 | **~2–3** |
| Wiped late | 50–75% | **4** | +0–2 | ~0.5 | **~4–6** |
| Died near end | 75–99% | **6** | +0–2 | ~0.6 | **~6–8** |
| **Full finish (WIN)** | 100% | **10** | — | ~0.7 | **~10–11** |
| **Full finish + all objectives** | 100% | **10** | **+6–8** | ~0.7 | **~17–19** |

- **Completion premium:** the 6→10 jump at the finish line (+65%) is intentional — it makes *finishing*
  the rational goal and fixes Dead Rails' "loot then bail" behavior (it pays finishing only 10 Bonds vs
  ~100–130 for looting a whole map).
- **Zone-stepped, not `floor(distance/10)`:** keeps Gold legible and rare — "reach the next zone = +2
  Gold" is a clear carrot, and quitting mid-run visibly leaves Gold on the table (loss aversion).
- **Optional run objectives (+6–8 Gold, full run only):** e.g. *no crew deaths*, *raid all camps*,
  *finish before nightfall*, *boat >50% HP at end*. These are Dead Rails-style self-set challenges — the
  cheapest-to-author, highest-value replay boost.
- **Gold nuggets (found):** rare world spawns at camps — tune to **~0.5–1 expected per full run** (each
  of ~5 camps ~15% chance to hold a 1-Gold nugget). **Cap 3/run** so looting can't eclipse finishing.

**Net:** casual finisher ≈ **10 Gold/run**; engaged/mastery ≈ **15–19**; failed run **1–8** (never zero).
Gold stays scarce and the finish is unambiguously the best source.

---

## §3. In-run Salvage economy + dock shop

Repurpose the existing `floor(distance/10)` as a small distance **drip** (~300/full run) and put the
bulk of Salvage into **camp/dock loot**, so cash rewards the on-foot raid loop, not passive driving.

- **Target Salvage per full run: ~800–1,500** (≈300 drip + ~500–1,200 loot by raid aggression).
- Enough for ~1 weapon + a few consumables, **or** heavy fuel/repair — never everything. It **resets**
  each run, so the pressure restarts (Lethal Company's tight store math against a small start balance).

| Dock item | Salvage | Role |
|---|---|---|
| Bandage (revive/heal) | **50** | Core survival, spammed |
| Fuel can (gasoline) | **120** | Mandatory sink — gates distance |
| Ammo box | **90** | Scales with combat intensity |
| Repair kit (metal) | **150** | Boat HP; competes with fuel |
| Basic weapon (rifle/shotgun) | **400** | ~1/run affordable |
| Weapon upgrade / better gun | **750** | Aspirational; needs a good loot run |

A ~1,000-Salvage run ≈ 8 fuel cans **or** 2 weapons + 3 bandages — real trade-offs, all wiped next run.

---

## §4. The skill tree (1→10, per-player, Gold-bought)

**10 skills** mirroring the "1–10 points" theme. Each level costs Gold and grants a bounded bonus.
Baselines for worked numbers: cruise 35 studs/s, boat HP 1000, run 18,000 studs.

### 4.1 Bonus curves

Most skills use **linear-additive %** (readable, no runaway stacking). Two use **multiplicative decay**
so they soft-cap and never trivialize their loop (fuel, reload).

| # | Skill | Group | Per level | L10 cap | Curve |
|---|---|---|---|---|---|
| 1 | **Twin Motors** (top speed + accel) | Boat | +3% speed | +30% → 45.5 studs/s (~6.6 min run) | Linear |
| 2 | **Rudder Tuning** (turning) | Boat | +2.5% turn rate | +25% turn, less drift | Linear |
| 3 | **Hull Plating** (boat HP) | Boat | +5% (flat +50) | +50% → 1500 HP | Flat additive |
| 4 | **Diesel Efficiency** (fuel) | Boat | ×0.975 burn | −22% burn (never 0) | Mult. decay |
| 5 | **Cargo Rigging** (capacity) | Boat | +5% capacity | +50% carry | Linear |
| 6 | **Field Repair** (repair speed) | Crew | +5% | +50% faster repair | Linear |
| 7 | **Fuel Handling** (refuel speed) | Crew | +5% | +50% faster refuel | Linear |
| 8 | **Combat Medic** (revive) | Crew | +4% speed, +2.5pp revived HP | +40% speed, ally revives at 50% HP | Linear |
| 9 | **Gun Discipline** (reload/handling) | Crew | ×0.965 reload | −30% reload + steadier recoil | Mult. decay |
| 10 | **Scavenger's Instinct** (loot + nugget) | Crew | +3% loot, +0.5pp nugget | +30% loot, +5pp nugget odds | Linear (bounded) |

**Why these caps:** +30% speed / +50% HP / −22% fuel make a maxed boat clearly stronger but not
invincible. **Tune the hardest zones (3–4) against a ~L5–L7 boat, not a maxed one**, so maxing feels
great but late zones still bite (the roguelite meta-progression rule: never trivialize skill).
Scavenger's nugget bonus is tiny by design — it feeds the Gold faucet, so letting it snowball would
break the "Gold is rare" pillar.

### 4.2 Cost ladder (RECONCILED — supersedes the raw research numbers)

> **Reconciliation note.** The two researchers used different gold scales (one ~10 Gold/win with a
> ~2,000-Gold max; the other assumed ~50 Gold/win with a ~21,000 max). I've harmonized to the **rare-gold
> scale** (§2: ~10 Gold/win) because "Gold is hard to get" is your explicit intent. Costs below are
> rescaled so maxing the whole tree ≈ 150–170 runs — matching the earn-side target — using
> `cost(n) = round(4 · 1.3^(n-1))`.

| Level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | **One skill maxed** |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Cost | 4 | 5 | 7 | 9 | 11 | 15 | 19 | 25 | 33 | 43 | — |
| Cumulative | 4 | 9 | 16 | 25 | 36 | 51 | 70 | 95 | 128 | **171** | **171 Gold** |

- **Max ONE skill (L1→L10): 171 Gold.**
- **Max ALL 10 skills: 1,710 Gold.**
- **Bring all 10 to L5 (soft-max): 360 Gold.**

### 4.3 Time-to-goal (at ~10–12 Gold per engaged win)

| Goal | Gold | ≈ Runs | Feel |
|---|---|---|---|
| First real buy (a skill to L3) | 16 | ~1–2 wins | Hooks in session 1 (protects D1) |
| Max one key skill | 171 | ~14–17 wins | A weekend goal (protects D7) |
| All skills to L5 (soft-max) | 360 | ~30–36 wins | The "competent crew" milestone |
| **Max the whole tree** | 1,710 | **~150–170 wins** | Long-tail chase (protects D30) |

Because the ladder is geometric, players naturally **buy breadth early** (L1–4 are 4–9 Gold) and
**specialize late** (L8–10 are 25–43) — giving short/mid/long "next unlock" horizons.

### 4.4 First buys & co-op specialization

Your three loss conditions are **stranded (fuel)**, **boat destroyed (HP)**, **crew wipe**. First buys
insure against them:
1. **Diesel Efficiency** — counters "stranded"; stretches every fuel dock. Best survival ROI.
2. **Hull Plating** — counters "boat destroyed"; flat HP is the most reliable survival stat.
3. **Field Repair** — turns Metal into uptime faster; multiplies Hull Plating.

**Co-op note:** skills are per-player, so a 6-crew should **spread specializations** (one maxes Repair,
one Guns, one Medic, one Refuel) rather than all buying the same tree. This makes roles matter and is the
strongest fairness + teamplay outcome.

---

## §5. Boat modules — the visible "start small → full boat" progression

GAME.md's core fantasy: a bare hull grows into a bristling river craft. Keep this **separate from the
graded skills** to avoid double-dipping:

- **Modules = one-time Gold unlocks that ADD a capability/slot** (a visible physical part).
- **Skills = graded 1–10 tuning of stats.** (You *unlock* the searchlight module, then *level* Night
  handling; you *unlock* the 2nd motor mount, then Twin Motors tunes thrust.)

| Module (one-time) | Gold | Adds |
|---|---|---|
| 2nd Motor mount | 150 | A second engine slot (more thrust; clears bigger ramps) |
| Reinforced Hull kit | 200 | Visible armor plating (base HP tier up) |
| Searchlight rig | 120 | Night visibility (pairs with night sections) |
| Extended Fuel Tank | 150 | Larger gasoline capacity (fewer stops) |
| Cargo Trailer | 180 | The towed barge (haul more loot; also a target) |
| Mounted Gun upgrade | 200 | Stronger turret for the gunner |

**Modules total ≈ 1,000 Gold.** With the skill tree (1,710), full 100% completion ≈ **2,700 Gold ≈
225–270 runs** — a healthy long tail that always has a next visible purchase. Modules are the "see your
boat physically grow" dopamine; skills are the fine-tuning underneath.

---

## §6. Robux monetization (fair, not pay-to-win)

**Model (locked 2026-07-19): the full Dead Rails economy — Gold is buyable with Robux.** This is
pay-to-win by the strict definition. PvE softens it (no opponent to outspend; buying power only
trivializes your *own* PvE, which the community tolerates far more than in PvP), and Dead Rails proves
the model earns at scale. The job now is to keep it feeling *fair, not greedy* via the guardrails below.

### 6.1 Guardrails that keep a "buy Gold" game from feeling greedy

1. **Everything is earnable free, generously.** Gold drops every run (even losses); the free faucet must
   stay satisfying so buying is a *shortcut*, not a *requirement*. Never balance the game around purchased Gold.
2. **No EXCLUSIVE power.** Nothing bought with Robux is unobtainable free — Robux only buys *time*
   (skip the grind) plus cosmetics/convenience. This is the line the community actually polices.
3. **Cosmetics stay the headline sell.** Lead the store with skins/the armored boat, not Gold packs.
4. **No aggressive pop-ups / no randomized paid crates** (see Compliance in §6.3). Sell directly.
5. **Tune difficulty against a free ~L5–L7 player**, so a payer isn't *required* and a free player can finish.

### 6.2 Gold packs (Robux → Gold) — benchmarked to Dead Rails' Bonds (5/10/20/50 = 49/79/129/199 R$)

| Gold pack | Type | Robux | ≈ Runs saved | Note |
|---|---|---|---|---|
| 10 Gold | Dev product | **49** | ~1 win | Entry / impulse |
| 25 Gold | Dev product | **99** | ~2.5 wins | +2 Gold bonus vs 2×49 |
| 60 Gold | Dev product | **199** | ~6 wins | Best mid value |
| 150 Gold | Dev product | **449** | ~15 wins | Whale tier; ~1 skill maxed |

Currency top-ups are **developer products** (repeatable). Keep prices Bonds-parity so the value read is
familiar to genre players. (Optionally add a permanent **+25–50% Gold boost** game pass later; fine now
that Gold is sold anyway.)

### 6.3 Cosmetic / convenience catalog (benchmarked to Dead Rails & comparable hits)

| # | Product | Type | Robux | Rationale |
|---|---|---|---|---|
| 1 | Self-Revive Token (single) | Dev product | **35** | Consumable safety-net; keep in-run bandage revives strong so it's never required |
| 2 | Self-Revive 5-pack | Dev product | **149** | ~15% volume discount → lifts ARPPU without raising per-use price |
| 3 | +Cargo Slots (permanent) | Game pass | **99** | Convenience; mirrors Dead Rails "+5 Storage" (79). Also earnable via the Cargo Trailer module, so not exclusive |
| 4 | **Armored Boat Skin** | Game pass | **199** | Your ask — **cosmetic metal-plated hull, identical stats**. Premium skin tier. Sell the *look*, never armor value |
| 5 | Boat Paint pack (3–5 colorways) | Game pass | **99** | Entry cosmetic, the "gold standard" fair sell |
| 6 | Cosmetic bundle (trails + wake FX + searchlight color + emote) | Game pass | **249** | Mid-tier bundle lifts value/buyer |
| 7 | Starter Pack (cosmetic hull + 3 revives + captain outfit + first-run Salvage head start) | Dev product, first-purchase | **149** | New-player conversion; cosmetic + convenience only |
| 8 | Starter Weapon **skin** | Game pass | **99** | Cosmetic reskin of the earnable starter weapon — stat-identical (frame "starter weapon" without exclusive power) |
| 9 | Captain's Pass VIP (lobby cosmetics + name tag + 1 free daily self-revive) | Game pass | **399** | Whale-friendly permanent tier; recurring value via daily revive (convenience) |
| 10 | Season / Battle Pass (free + premium; premium = cosmetics, emotes, Salvage/Gold, titles) | Game pass/season | **799** | Industry-standard price. **Build now, ship after D1/D7 healthy** (your call). Premium track may include Gold + cosmetics |

**Launch lean:** ship a Gold pack (§6.2 — 99 R$), the Armored Boat Skin (#4, 199), and a cheap Boat
Paint (#5, 99) first; measure conversion ~2 weeks, then expand. Lead the store with the *skin*, not Gold.

**Compliance:** **no randomized paid crates** — Roblox now requires per-item odds disclosure globally
(Korea loot-box law). Sell cosmetics directly; it's cleaner legally and reputationally.

### 6.4 Developer economics (so pricing is grounded)

- Marketplace fee **30%** → you keep **70%**. DevEx **$0.0038/Robux** (post-2025-09-05; min cash-out
  50,000 Robux). **Net ≈ $0.00266 USD per listed Robux** (0.70 × 0.0038).
- So a 199-Robux pass nets ≈ **$0.53**; a 799 battle pass ≈ **$2.12**.
- **Revenue ≈ DAU × retention × conversion**, not per-item price. Typical: 1–3% pay; top ~1% can drive
  >50% of revenue. Plus **Creator Rewards** pay you for retaining co-playing spenders — so **fair,
  finish-with-friends design *is* the monetization strategy.**

---

## §7. Leaderboards & the stats we persist

**Persistence:** ProfileStore-style profiles (session locking + `UpdateAsync` + `BindToClose`).
**Global boards:** `OrderedDataStore` (integer values only; `GetSortedAsync` pages of ≤100).
**Live daily board:** MemoryStore `SortedMap` → archived to a dated OrderedDataStore key.
**Period resets:** new dated store per period (`Daily_YYYY_MM_DD`, `Board_YYYY_Www`) — never wipe.

### 7.1 Stats to persist (R = feeds rank, B = bragging/board only)

| Field | R/B | Why |
|---|---|---|
| `totalRuns` | B | Grind proof / win-rate denominator |
| `runsFinished` (wins) | **R** | Core mastery signal (reaching the END) |
| `totalDistanceStuds` | **R** | Lifetime grind / smooth XP faucet |
| `bestDistanceStuds` | B (+ tiebreak) | Best-distance board |
| `farthestZone` | **R** | Depth/escalation reached |
| `enemiesKilled` | R (light) | Combat contribution |
| `campsRaided` | R (light) | On-foot engagement |
| `revivesPerformed` | R (light) | **Co-op reward** |
| `nightsSurvived` | R (light) | Survival pressure |
| `fastestFullRunMs` | B | Speed board (finished only) |
| `totalGoldEarned` / `bestGoldRun` | B | Economy bragging (≠ spendable Gold) |
| `riverScore` | **R = the rank metric** | Lifetime accumulator (§8) |
| `dailySeedId` / `dailyBestScore` | B (competitive) | Fair-seed result |
| `dailyStreak` / `loginStreak` / `lastLoginDate` | — | Retention engine |
| `seasonId` / `seasonScore` | B (competitive) | Resettable season ladder |

Keep **spendable Gold** as its own field, separate from `totalGoldEarned` (stat) — one source of truth.

### 7.2 Boards to ship

| Board | Backing | Reset | Priority |
|---|---|---|---|
| Global All-Time — River Score | OrderedDataStore | never | **Launch #1** (it *is* the rank) |
| Best Distance — all-time | OrderedDataStore | never | **Launch #1** |
| Friends | filter global via `GetFriendsAsync` | live | **Launch #1** |
| Daily Seeded Run | MemoryStore → dated OrderedDataStore | 00:00 UTC | Launch #2 |
| Weekly | dated OrderedDataStore | Mon 00:00 UTC | Launch #3 |
| Fastest Full-Run | OrderedDataStore (ms) | never | Later |

---

## §8. Player rank — "River Score" (the badge on your head)

**A lifetime, non-decaying mastery rank** — because "anyone can see how good a player is" is a
*reputation*, not a volatile ladder. Computed **server-side** per run and folded into the profile:

```
runScore =  floor(distanceStuds / 100)          // full run 18,000 = 180
          + zonesReached        * 50
          + (finished ? 300 : 0)                 // the win
          + enemiesKilled       * 2
          + campsRaided         * 25
          + nightsSurvived      * 40
          + revivesPerformed    * 15             // co-op
          + objectivesCompleted * 100
          + dailyParticipation  * 25
          + (dailyTop10pct ? 200 : 0)
riverScore += runScore     // never decreases
```

Expected: early death ≈ 80–150; solid mid-run ≈ 250; full win with raids ≈ 700–1000.

### 8.1 Tier ladder (10 tiers, ~250 XP/run assumed)

| # | Tier | River Score | ~Runs | Color | Flair (cosmetic only) |
|---|---|---|---|---|---|
| 1 | Castaway | 0 | 0 | Grey | Default nameplate |
| 2 | Drifter | 500 | ~2 | Bronze | Bronze border |
| 3 | Rafter | 1,500 | ~6 | Lt bronze | Raft charm icon |
| 4 | Riverhand | 4,000 | ~16 | Silver | Silver border |
| 5 | Navigator | 9,000 | ~36 | Teal | Compass icon + name glow |
| 6 | Rapids Runner | 18,000 | ~72 | Cyan | Water sheen on tag |
| 7 | Whitewater | 35,000 | ~140 | Blue | Boat paint unlock |
| 8 | Riverboat Captain | 65,000 | ~260 | Purple | Captain's-hat cosmetic |
| 9 | Delta Master | 120,000 | ~480 | Magenta | Animated tier icon |
| 10 | River Legend | 220,000 | ~880 | Gold | Golden name + lobby particle wake |

**Prestige past cap:** every +100,000 beyond Legend = a **Legend ★** (★, ★★, ★★★…), so the top 1%
always has a next goal without renaming the tier.

**Why a blend, not one metric:** distance alone rewards passive grinding; wins alone lock out newbies.
The blend (distance + depth + finishes + combat + co-op + objectives) rewards the whole loop and can't be
farmed one cheap way. **Flair is strictly cosmetic** — rank-granted *power* would trivialize skill and
inflate the economy.

### 8.2 Lobby display

- **Overhead tag** (`BillboardGui` on Head, **lobby only** for mobile perf): Line 1 = tier icon + TIER
  NAME in tier color with a black `UIStroke`; Line 2 = display name; right pill = `Lv`/River Score
  short-form (`65.0k`). `TextScaled`, `UIAspectRatioConstraint`, `MaxDistance ≈ 60`. Legend gets a
  subtle animated sheen. **In-run** uses minimal nameplates only (no heavy Billboards).
- **Lobby board object:** a dock signpost `SurfaceGui` = Global Top 10 by River Score + a pinned
  "YOU — #rank" row, plus a full `ScreenGui` panel with tabs **Global · Friends · Daily · Weekly**.

---

## §9. Retention layer (why they come back)

**Daily login — escalating, forgiving (1-day grace so a miss doesn't reset):**

| Day | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Gold | 10 | 15 | 20 | 30 | 40 | 50 | **100 + cosmetic token** |

Cycle repeats; **Day-30 milestone** = 250 Gold + exclusive lobby cosmetic (anchors the 28-day discovery
window). Note: day-7 = 100 Gold is a big injection relative to ~10/run — that's fine as a *habit* reward,
but watch it doesn't undercut the run economy; tune down if login-farming outpaces playing.

**Weekly objectives (rotate Mondays, pick 4–5), Dead-Rails Challenge-Board style:** travel 50k studs
(60 Gold + 300 score) · finish 3 runs (80 + 500) · raid 20 camps (40 + 200) · reach Zone 4 in one run
(50 + 250) · survive 10 nights (40 + 200) · revive 8 teammates (40 + 250, co-op pull).

**Daily seeded run:** everyone gets the *same* server-generated seed (from the UTC date) → fair skill
competition → top-10% grants a River Score bonus that permanently advances your visible rank. This is the
flywheel: **daily = fresh + fair; rank = permanent + social; streak/weekly = habit.**

**Seasons (only after D1/D7 healthy):** 8–12 weeks, a **separate resettable `seasonScore`** board +
season-exclusive cosmetics. **Lifetime River Score never resets** — competitors get fresh ladders, nobody's
reputation is knocked down.

**Anti-cheat (non-negotiable):** all run stats, Salvage, Gold, and River Score computed server-side in
the reserved gameplay server; client never reports its own numbers; daily seed derived server-side.

---

## §10. The progression narrative — why finish, why repeat

**Why they FINISH:** the completion premium makes the finish the rational goal (not a farm detour);
permadeath + an 8-min boat you kept alive triggers loss aversion; a finite END gives a real "I beat it"
win state; zone-stepped Gold makes quitting mid-run visibly cost you.

**Why they REPEAT:** every run advances *something* (Gold even on a loss; River Score always) so failure
= progress (the core roguelite re-queue driver); randomized camps/zones/night let skill express as
mastery; the skill tree + boat modules always show a next purchase (short/mid/long horizons); optional
objectives make run #50 differ from run #1; 1–6 co-op with shared boat + bandage revives generates
stories; and the daily-seed + rank + streak + weekly layer pulls players back across days.

**The player journey:**
- **Session 1:** learn the loop, finish or die, earn ~10 Gold, buy a skill to L3 → immediate progress.
- **Week 1:** max a survival skill, hit Navigator (T5), start chasing weekly objectives.
- **Month 1:** boat physically grown (modules), soft-maxed tree, Rapids Runner+, daily-seed regular.
- **Long term:** max tree + modules (~250 runs), climb toward River Legend, prestige stars, seasons.

---

## §11. Suggested build phasing (when we implement — separate jobs)

1. **Economy core:** replace `floor(distance/10)` reward with the §2 zone-stepped Gold + persistent
   profile (Gold, stats). Salvage + dock shop (§3). *(Foundational — everything hangs off persistence.)*
2. **Skill tree UI + effects (§4)** in the lobby; wire bonuses into boat/crew systems.
3. **Boat module unlocks (§5)** — visible parts + Gold gate.
4. **Leaderboards + River Score + overhead rank (§7–8).**
5. **Robux catalog (§6)** — launch lean (3 items).
6. **Retention (§9)** — daily/streak/weekly, then daily-seed, then seasons.

Each becomes its own job with a real implementation plan; this doc is the balance spec they cite.

---

## §12. Decisions — LOCKED 2026-07-19

1. ✅ **In-run currency name = "Salvage".**
2. ✅ **Gold per finished run = 10** (rare, Dead Rails-parity).
3. ✅ **Gold IS sold for Robux** — full Dead Rails model (P2W accepted; guardrails in §6.1). Gold packs
   priced Bonds-parity (§6.2).
4. ✅ **Battle pass at 799 — build now, ship after D1/D7 are healthy.**
5. ✅ **Boat upgrades = split model** — modules unlock a capability/part, skills tune the stat (§5).
6. ✅ **Rank ladder — keep the long top-end** (River Legend ≈ 880 runs) + prestige stars (§8).
7. 🔸 **Skill list — parked.** Keep the 10 as listed for now; user will review the per-skill effects and
   revisit (may add a Night Vision skill or trim). Revisit before the skill-tree build job.

---

## §13. Sources

**Economies/retention:** Dead Rails Bonds — [TheGamer](https://www.thegamer.com/roblox-dead-rails-bonds-farming-guide/),
[GuideBros](https://guidebros.com/roblox/dead-rails/how-much-bonds-per-winning/), [Wiki](https://deadrails.fandom.com/wiki/Bonds);
[Deep Rock Credits](https://deeprockgalactic.wiki.gg/wiki/Credits)/[Promotion](https://deeprockgalactic.wiki.gg/wiki/Promotion);
[Lethal Company Quota](https://lethal-company.fandom.com/wiki/Profit_Quota); [RoR2 Lunar Coins](https://riskofrain2.wiki.gg/wiki/Lunar_Coins);
[Vampire Survivors PowerUps](https://vampire.survivors.wiki/w/PowerUps); [Sea of Thieves Renown](https://rarethief.com/sea-of-thieves-how-to-raise-your-season-renown-level/);
[Bugnet roguelite meta-progression](https://bugnet.io/blog/how-to-design-a-roguelite-meta-progression); [Roblox retention docs](https://create.roblox.com/docs/production/analytics/retention);
[Supersonic D30 playbook](https://supersonic.com/learn/blog/d30-playbook-retention/).

**Balance math:** [Davide Aversa — level progression math](https://www.davideaversa.it/blog/gamedesign-math-rpg-level-based-progression/);
[Game Developer — Math of Idle Games](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-i) & [Idle Idol balancing](https://www.gamedeveloper.com/design/balancing-tips-how-we-managed-math-on-idle-idol);
[TV Tropes — Diminishing Returns for Balance](https://tvtropes.org/pmwiki/pmwiki.php/Main/DiminishingReturnsForBalance); [Bruno Dias — On Power Creep](https://brunodias.dev/2021/11/27/power-creep.html).

**Monetization:** [Roblox Passes](https://create.roblox.com/docs/production/monetization/passes) &
[Creator Rewards](https://devforum.roblox.com/t/introducing-creator-rewards-earn-more-by-growing-the-community/3777628) &
[DevEx](https://en.help.roblox.com/hc/en-us/articles/13061189551124-Developer-Exchange-Help-and-Information-Page) &
[paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items);
Dead Rails passes — [Rolimon's](https://www.rolimons.com/gamepass/1654583610), [Wiki](https://deadrails.fandom.com/wiki/Gamepasses), Bonds prices [Beebom](https://beebom.com/how-to-get-and-use-bonds-in-dead-rails/);
[BedWars Battle Pass 799](https://robloxbedwars.fandom.com/wiki/Battle_Pass); [pass pricing guide](https://generalistprogrammer.com/tutorials/roblox-game-pass-pricing-guide).

**Leaderboards/rank:** [Roblox OrderedDataStore leaderboard](https://create.roblox.com/docs/tutorials/use-case-tutorials/data-storage/create-leaderboard),
[DataStore limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits), [MemoryStore SortedMap](https://create.roblox.com/docs/cloud-services/memory-stores/sorted-map);
[Overhead Rank GUI](https://devforum.roblox.com/t/overhead-rank-gui/470651); [Slay the Spire daily scoring](https://spire-codex.com/mechanics/score-formula);
[League ranks](https://esportsinsider.com/league-of-legends-ranks); [Rogue Legacy 2 mastery](https://www.destructoid.com/rogue-legacy-2-mastery-levels-play-every-class-rank-up-passive-bonuses/).

**Caveats:** DR run-time (8–9 min is *our* target, not DR's ~15–50 min) and DRG per-mission credits lack
single canonical sources; third-party conversion/whale figures are directional (Roblox publishes none).
All Last River numbers are tunable proposals — prototype the **completion premium** first; it's the
load-bearing design bet.
