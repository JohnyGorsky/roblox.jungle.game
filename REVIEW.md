# Last River — Base-Mechanics Review & Decisions (2026-07-19)

Full review of the POC after Jobs #001–#058 + the river journey overhaul + Medic + solo tuning.
Cross-checked GAME.md + all Planned/ docs + every job summary against the actual code tree.

## Verdict
**All base mechanics are in place as a verified greybox POC.** The full core loop runs end-to-end
(lobby → party → teleport → plane-crash intro → varied paced river run → docks/camps → win/lose →
results → return to lobby) with economy, monetization, progression, retention, leaderboards, roles,
and solo/co-op scaling.

## Base mechanics → status
Boat + physics ✅ · modular boat ✅🟡 · fuel/scavenge/haul ✅ · safer-while-moving ✅ · docks + mooring ✅ ·
excursions/camps ✅🟡 · two-domain time-aware threats ✅🟡 · day/night + lights ✅ · 4 escalating zones ✅ ·
resources + stations ✅ · roles + Medic ✅ · weapons (melee/gun/turret) + inventory ✅🟡 · boat HP + down/revive ✅ ·
win/lose ✅ · seeded terrain + forks/current ✅ · crash intro ✅🟡 · lobby→teleport ✅ · 3-tier economy + rank ✅ ·
progression/persistence/leaderboards/retention ✅ · monetization ✅ (IDs set). (🟡 = greybox art.)

## Decisions (this review)
1. **Towed trailer** — dropped. On-boat cargo deck stays (better physics). No action.
2. **Role suitability icon above player** (from skills) — TODO 0011.
3. **Ranged enemies** — deferred as a future feature — TODO 0012.
4. **Run objectives** — WANTED, expand now → **Job (build)**.
5. **River set-pieces** (waterfalls / real ramps / log-dam blockages) — WANTED, logged — TODO 0013.
6. **Custom mobile boat controls** — before publish — TODO 0014.
7. **Reel-the-boat at every pier** — TODO 0015.
8. **Purchasable inventory slots + cosmetic visuals** (grant the perks) — TODO 0016.
9. **Commits** — user commits everything (standing rule; treated as done).
10. **DEV flags off** — do now → **Job (build)** (DEV_RAMPS, RampTest, BoatDBG logs, DEV_STARTER_GUNS, Torch starter).
11. **Leftover scaffold** (Demo/Test "Hello world") — remove now → same cleanup **Job**.
12. **Memory leak** (landing sites/camps never culled) — fix now → **Job (build)**.
13. **Robux IDs** — ALREADY SET (Job #027): Gold packs 3610663250/288/341/385; passes armoredBoat 1919001295,
    boatPaint 1919355255, cosmeticBundle 1918077339. (Review's "needs IDs" flag was outdated.)
14. **ProfileStore migration** — before real-money launch — TODO 0017.

## Build now (from this review)
- **Run objectives** (expand) — per-run bonus objectives feeding Gold/Salvage/score + weeklies.
- **Pre-launch hygiene** — disable DEV flags + delete leftover scaffold scripts.
- **Memory-leak fix** — cull far landing-site basins/camps (`built[index]` never cleared).

## Still deferred (not gaps in the foundation)
Ranged enemies (0012), river set-pieces (0013), mobile controls (0014), reel-at-every-pier (0015),
purchasable slots + cosmetic visuals (0016), ProfileStore (0017), role icons (0011), and the whole
**P9 art/audio pass** + P10 endless + P11 live-ops.

## Known caveats to remember
- Simplified persistence → ProfileStore before real money (0017).
- Many prompt flows (revive/tie/loot/deposit/trade/gunner) + real Robux + cross-place teleport are only
  fully testable in a 2-player Team Test / published place.
