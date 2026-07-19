# Final Summary — Job #022: Run rewards → Gold (zone-stepped + nuggets)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Design source: Job #020 §2.
Depends on #021 (persistence).

## What was built
The run now pays **real, persistent Gold** (credited to the #021 profile), replacing the display-only
`floor(distance/10)` placeholder.

### `RunServer.server.luau` (edit)
- **Zone-stepped reward** `goldForRun(distance, endDist, won)` — <25%→1, 25–50→2, 50–75→4, 75–99→6,
  **finish→10**. The 6→10 jump at the line **is the +4 completion premium** (finishing beats farming).
- On run end, **credits every crew member** in the server (incl. the dead who are spectating) via
  `Profiles.addGold`, and folds in run stats: `totalRuns`, `runsFinished` (win), `totalDistance`,
  `bestDistance`, `farthestZone` (0–4). Sends the Gold amount in the `RunEnded` payload.
- Removed `REWARD_DIV`.

### `ExcursionServer.server.luau` (edit)
- **Rare gold nuggets** at camps: ~25% chance per camp, **1 Gold each, hard-capped at 3/run**
  (`Workspace.NuggetsSpawned`). Grab prompt → `Profiles.addGold(player, 1)`. Keeps "found gold" lucky,
  not farmable (avoids the Dead Rails loot-eclipses-finishing trap).

### `RunClient.local.luau` (edit)
- Results screen reward line now reads **"+ N Gold"**.

## Verified (live in Studio, Game place)
- [x] Reward curve matches Job 020 §2 exactly (inline check: 0/10%→1, 25/40%→2, 50/60%→4, 75/90/99%→6,
      100%→10, win→10).
- [x] **WIN credits +10 Gold** — the player's `Gold` attribute, `leaderstats.Gold`, the **GoldHud
      ("GOLD 10")**, and the **results screen ("+ 10 Gold")** all updated (screenshots). Attribute +
      leaderstats are set only by the game's `addGold`→`_publish`, so this proves the real profile was
      credited.
- [x] Analyzer-clean (all three files).
- [~] **Partial payouts + stats persistence** — the credit/stats code runs in the same block as the
      proven `addGold`; math is proven inline. Not separately walked through a mid-run death (headless).
- [~] **Gold nuggets** — construction-verified (same `addGold` path); not walked to a camp headlessly.

## Testing gotchas learned (see workspace memory)
- **MCP `execute_luau` runs in a separate Luau context** → its `require()` gets a *fresh* module instance
  with its own cache, so `Profiles.getGold` there reads 0 even when the game credited gold. **Verify via
  shared Instances** (player attributes, leaderstats, DataStore), not module internals.
- **Studio Play-mode vs Edit-mode DataStore access don't share the same data**; clear test profiles from
  the *Play* server context. A non-stale leftover lock makes load fall to the (non-saving) in-memory
  fallback — use clean profiles when testing.

## Notes / follow-ups
- **Not committed.**
- **Run objectives** (+6–8 Gold bonus, Job 020 §2) need an objective system — deferred (part of #028 /
  a later run-objectives job). Hook point: add to `goldEarned` in `endRun`.
- Robustness (pre-existing #021 trade-off): a transient DataStore error / non-stale foreign lock at load
  → permanent non-saving fallback for that session. Fine for POC; revisit with ProfileStore pre-launch.
- Ready for the spend side: **#025 Boat modules** next (uses `Profiles.trySpendGold`).
