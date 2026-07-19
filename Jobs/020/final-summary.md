# Final Summary — Job #020: Economy, progression & monetization proposal

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · Research/design only (no code).

## What this is
A full, numbers-first balance + monetization proposal — the deliverable is
[implementation-plan.md](implementation-plan.md). Synthesized from **4 parallel deep-research streams**
(Roblox monetization; comparable co-op/roguelite economies; skill-tree balance math; leaderboards/rank/
retention), all grounded in the locked GAME.md economy and the real in-code run (18,000 studs ≈ 8–9 min).

## Headline recommendations
- **Two earnable currencies:** in-run **Salvage** (resets) + rare persistent **Gold** (~10/finished run,
  never zero on a loss). Gasoline/Metal/Ammo stay *resources*, not money. Resist a 4th currency.
- **Completion premium** (+4 Gold at the finish) makes finishing the goal — fixing Dead Rails' farm-and-bail flaw.
- **10-skill tree (1→10)**, geometric cost ladder `4·1.3^(n-1)`: one skill = 171 Gold, whole tree = 1,710
  (~150–170 runs); first buy in ~1–2 runs. **Reconciled the two researchers' conflicting gold scales**
  onto the rare-gold line.
- **Visible boat modules** (~1,000 Gold) as one-time capability unlocks, separate from graded skills.
- **Robux:** cosmetics/convenience/revives **+ Gold packs** (locked decision — full Dead Rails model,
  Gold is buyable; P2W accepted, with fairness guardrails in §6.1). Armored boat = cosmetic skin (199).
- **Lifetime non-decaying "River Score" rank** (10 tiers Castaway→River Legend + prestige stars) shown on
  a lobby overhead tag; separate resettable season/daily score for competitors.
- **Server-authoritative scoring**, ProfileStore persistence, OrderedDataStore boards, daily-seeded runs.

## Key reconciliation made
The economy researcher (~10 Gold/win, ~2k max) and the skill-tree researcher (~50 Gold/win, ~21k max)
used different scales. Harmonized to the **rare-gold scale** per the user's "Gold is hard to get" intent;
skill costs rescaled so maxing the tree ≈ 150–170 runs (see plan §4.2 note).

## Decisions locked (2026-07-19, plan §12)
Salvage (cash name) · Gold = 10/win · **Gold sold for Robux (full Dead Rails P2W model, with
guardrails)** · battle pass built now / shipped after D1/D7 · boat = split (modules unlock, skills tune) ·
rank keeps the long top-end. **Skill list parked** — user will review per-skill effects and revisit.
Once the skill list is settled, each plan section (§11) becomes its own build job.

## Notes
- **Not committed.** No code changed. Pure planning artifact.
- Prototype the **completion premium** first — it's the load-bearing design bet.
- Also resolves several GAME.md open questions (currency split, pre-run upgrades/skills, Robux product
  list, revive monetization, leaderboard stats) — worth back-porting the decisions into GAME.md once confirmed.
