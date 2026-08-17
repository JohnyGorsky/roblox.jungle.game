# Job #089: Migrate persistence to ProfileStore before real-money launch

**Project**: `roblox.jungle`
**Created**: 2026-08-17
**Status**: <span style="color:#2e9c3f">✅ **COMPLETE** (2026-08-17)</span> — playtest-confirmed by the user
(saving + teleport). ⚠️ The Robux receipt path is NOT separately confirmed — see `final-summary.md`.
See [`implementation-plan.md`](implementation-plan.md) · [`final-summary.md`](final-summary.md).

**Source:** [todo 0017](../../todo/0017-migrate-persistence-to-profilestore-befo.md) (open since 2026-07-19),
raised again as a launch blocker in the 2026-08-17 readiness review.

## Requirements / goal

Replace the hand-rolled session-locked profile service (`Profiles.luau`, Job 021) with the community
**ProfileStore** module, in **both places**.

## Why this is a blocker, stated plainly

Real Robux is **already wired and has live product ids**: 4 Gold packs (`3610663250/288/341/385`),
the Self Revive dev product (`3612677893`), and 3 passes. Those sit on top of **~260 lines of custom
DataStore session-locking that no player has ever exercised**.

The specific exposure is `purchaseIds` — `ProfileConfig.default()` carries a `purchaseIds` table that
makes `ProcessReceipt` idempotent. **That idempotency is only as good as the save layer underneath it.**
If a profile rolls back, granted purchase ids roll back with it, and the same receipt can be granted
twice — or, worse for the player, Gold they paid for disappears. Every other bug in the project costs
someone a run; this one costs someone money.

## What exists today (audited 2026-08-17)

| File | Lines | Role |
| --- | --- | --- |
| `ServerScriptService/Progression/Profiles.luau` | 260 | the service being replaced — `GetDataStore` + one `UpdateAsync` transaction per op |
| `ServerScriptService/Progression/ProfileServer.server.luau` | 75 | lifecycle: `PlayerAdded` → load, autosave heartbeat, `PlayerRemoving` → save+release |
| `ReplicatedStorage/Progression/ProfileConfig.luau` | 117 | **client-safe** schema, defaults, `migrate()`, store names, tuning |

All three exist as **byte-identical copies** under `sync/` and `lobby/sync/` — one experience, one
DataStore. They are copied, not separately edited, and must stay identical.

### The custom lock, and what it does *not* do

`transact()` runs one `UpdateAsync` with `mode ∈ {load, beat, release}`, storing `__lock =
{session, heartbeat}` inside the profile itself. `LOCK_STALE_SECONDS = 90` lets a newer session
**steal** a lock whose heartbeat has gone quiet.

That steal is the weak point, and it is the exact scenario this game creates constantly: the
**lobby → reserved game server teleport** hands one player between two servers, so a load races a
release on every single run. ProfileStore's whole purpose is to resolve that conflict correctly (it
does it in a single call and can be driven by `MessagingService` so the losing server yields promptly),
rather than by waiting out a 90-second timer.

### The API surface to preserve — 15 call sites

`Profiles` is required by 15 server scripts (7 in `sync/`, 8 in `lobby/sync/`), using **12 methods**:

```
isReady 21 · get 19 · save 14 · getGold 13 · addGold 13 · unload 8
addRiverScore 7 · load 6 · getPaint 5 · trySpendGold 4 · setPaint 3 · getRiverScore 2
```

Call sites: `RunServer`, `ObjectiveServer`, `MonetizationServer`, `AdminServer`, `ExcursionServer`,
`BoatModules`, `ProfileServer` (game) · `LobbyBoat`, `ModulesServer`, `PaintServer`, `SkillServer`,
`RetentionServer`, `MonetizationServer`, `AdminServer`, `ProfileServer` (lobby).

**Leading approach: keep `Profiles.luau` as a facade.** Same 12 methods, same signatures; swap the guts
from `GetDataStore`/`UpdateAsync` to ProfileStore. All 15 call sites then need **zero changes**, and the
blast radius is one file × 2 places instead of fifteen. To confirm in planning: whether every method can
be expressed synchronously over `Profile.Data` the way the current ones are — `isReady` and the
fallback-profile path are the two that need checking, since ProfileStore's session-lost callback has no
equivalent in the current design.

### Two behaviours that must survive the swap

1. **The fallback profile.** `Profiles` currently sets `fallback = true` when a load fails, serving an
   in-memory profile that is **never saved**. The player gets a playable session instead of a kick, and
   cannot corrupt their real save. ProfileStore's convention is to kick on a failed load — **we keep
   the fallback** (Q4 below), so this is a deliberate divergence from the module's idiom, not drift.
2. **`ProfileConfig` is client-safe and required from `ReplicatedStorage`.** The schema, `migrate()`
   and `DATA_VERSION` must stay there. ProfileStore itself is **server-only** and must not be reachable
   from the client — do not collapse the two modules together.

### Already done, and not in scope

**Job #085 split the stores by `RunService:IsStudio()`.** `STORE_NAME_DEV = "PlayerProfiles_v1"` (Studio,
carries our test progress) and `STORE_NAME_LIVE = "PlayerProfiles_live_v1"` (published, **brand new and
empty**). That split is correct and stays. It also has a happy consequence for this job — see Q1.

## Decisions (user, 2026-08-17)

- **Q3 → FACADE.** Keep `Profiles.luau`'s 12-method API and swap its internals. The 15 call sites are
  not touched. This is the shape of the job: one module, two places.
- **Q4 → KEEP THE FALLBACK PROFILE.** A failed load still serves a playable, never-saved in-memory
  profile rather than kicking the player.
  > ⚠️ **One consequence the plan must handle.** With real money live, a fallback session must never
  > *consume* a purchase: if `ProcessReceipt` grants Gold into a profile that is never written, the
  > player pays and receives nothing. The fix is small and needs no new UI — **`MonetizationServer`
  > must return `NotProcessedYet` (never `PurchaseGranted`) whenever the profile is `fallback`**, so
  > Roblox re-delivers the receipt on a later session that has real data. Make this an explicit step in
  > the plan, not an afterthought.
- **Q2 → START DEV CLEAN.** New empty dev store; existing Studio test progress is re-granted through
  `AdminServer`. Bonus: the brand-new-player path then gets exercised on every fresh test.

## Open questions (settle during planning)

**Q1 — Live migration: is there anything to migrate?**
`PlayerProfiles_live_v1` is new and empty, and the experience is still **Private**. If no real player
has ever saved, ProfileStore can simply start on a fresh store name and **no data migration exists**
— which removes the single riskiest part of a persistence swap. Needs confirming rather than assuming.

**Q5 — How does ProfileStore get into the tree?** Rojo syncs scripts only, so this is a normal source
file — but decide where it lives (`ServerScriptService/Vendor/`?), how the version is pinned and
recorded, and confirm it must be present and identical in **both** places.

## Verification plan (this cannot ship on static analysis)

The whole point of the job is behaviour under contention, and none of it can be read off the code:

- **Two-server contention** — the lobby → game teleport with a profile actually held. This is the case
  the custom lock handles with a 90-second timer.
- **Purchase idempotency** — buy a Gold pack, force a session conflict, confirm the grant happens
  exactly once and `purchaseIds` survives.
- **Data survives a round trip** — Gold, modules, skills, paint, streak, weekly progress, stats out of
  the lobby, through a run, and back.
- **Failed-load path** — force a load failure, confirm the fallback profile is playable, is never
  written, and that a purchase attempted during it returns `NotProcessedYet` and is re-delivered later.
- ⚠️ **Studio and live DataStores differ** (project rule): verify via shared Instances — attributes /
  leaderstats / a real Play session — not by reading module internals from the command bar.

## Checklist

- [x] Requirements reviewed (this intake) — audit complete
- [x] Q2–Q4 answered by the user (2026-08-17)
- [x] Q1 — moot: BOTH stores renamed to fresh ProfileStore-format names, so nothing is migrated
- [x] Q5 — vendored at `ServerScriptService/Vendor/ProfileStore.luau` (v1.0.3, commit 9580f7c), both trees
- [x] Implementation plan created & agreed
- [x] Implementation completed (⏳ not yet playtested)
- [x] Final summary + changelog written

## Reference

- [ProfileStore docs](https://madstudioroblox.github.io/ProfileStore/) ·
  [DevForum thread](https://devforum.roblox.com/t/profilestore-save-your-player-data-easy-datastore-module/3190543)
- ProfileStore is loleris's **successor to ProfileService**, which is no longer supported. Improved
  session-conflict handling, a 300 s default autosave (~10× fewer DataStore calls), and Luau types.
- Consult the `roblox-data` skill (session locking, the load/autosave/`PlayerRemoving`/`BindToClose`
  lifecycle, budgets) and `roblox-monetization` (the `ProcessReceipt` idempotency pattern) in planning.
