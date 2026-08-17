# TODO 0017: Migrate persistence to ProfileStore (BEFORE REAL-MONEY LAUNCH)

**Project:** `roblox.jungle`
**Status:** open — code shipped in [Job #089](../Jobs/089/) (2026-08-17), **held open until playtested**
**Created:** 2026-07-19 23:07:00

Swap the simplified custom session-locked profile service for community ProfileStore before any real-money launch (dupe/rollback safety, robustness).

## 2026-08-17 — Job #089: code complete, guarantee not yet proven

ProfileStore 1.0.3 is vendored and live behind the `Profiles` facade in both trees; both analyzers are
clean. **Deliberately NOT resolved yet** — the entire value of this item is behaviour under contention,
and none of it has been exercised by a human. Resolve it only after the six checks in
[Jobs/089/final-summary.md](../Jobs/089/final-summary.md) pass, especially:

1. the lobby → game teleport with a profile actually held (the case this replaces);
2. a real Robux purchase settling exactly once;
3. Studio-with-API-off **refusing** a purchase rather than consuming it.
