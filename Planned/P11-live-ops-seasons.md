# P11 — Live-ops: seasons, battle pass & daily-seeded runs

**Source:** Job #020 (economy/monetization proposal). **Depends:** #021 (persistence), #026
(River Score/leaderboards), #028 (retention base). **Deferred past POC** — build once D1/D7 retention is healthy.

Deferred live-ops layer, beyond the POC:
- **Season / Battle Pass** — free + premium track (799 R$), premium = cosmetics/emotes/Salvage+Gold/titles.
  Build the framework, ship after D1/D7 are healthy (user decision, Job #020 §12).
- **Daily-seeded runs** — shared server-generated seed from the UTC date → fair competitive leaderboard
  (MemoryStore SortedMap → dated OrderedDataStore archive). Top-10% grants a River Score bonus.
- **Weekly board** + **Fastest Full-Run** board (Job #020 §7.2, later tier).
- **Season score** — a *separate resettable* ladder; lifetime River Score never resets.

→ Promote to jobs when the POC loop is proven and retention warrants live-ops.
