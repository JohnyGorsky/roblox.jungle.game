# TODO 0017: Migrate persistence to ProfileStore (BEFORE REAL-MONEY LAUNCH)

**Project:** `roblox.jungle`
**Status:** resolved (2026-08-17) — resolved in Job #089 (2026-08-17) - ProfileStore 1.0.3 vendored behind the Profiles facade in both trees; playtest-confirmed that progress survives the lobby->river teleport and a rejoin. The receipt half is tracked separately in todo 0055 so the launch checklist reads honestly: persistence done, purchases untested.
**Created:** 2026-07-19 23:07:00

Swap the simplified custom session-locked profile service for community ProfileStore before any real-money launch (dupe/rollback safety, robustness).

## 2026-08-17 — Job #089: done, and what was carved off

ProfileStore 1.0.3 is vendored and live behind the `Profiles` facade in both trees; both analyzers are
clean; the user's playtest confirmed progress survives the lobby → river teleport and a rejoin — the
session handover that the old 90-second lock timer handled badly, and the whole reason for this item.

**Carved off, not forgotten:** the Robux receipt path has never actually run a purchase. It is tracked
as **[todo 0055](0055-robux-receipt-path-untested-job-089-prof.md)** so the launch checklist stays
honest — *persistence done, purchases untested* — rather than this item sitting open and implying the
migration itself is unfinished.
