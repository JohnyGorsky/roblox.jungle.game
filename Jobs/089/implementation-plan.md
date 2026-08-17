# Implementation Plan — Job #089

**Project**: `roblox.jungle`
**Status**: Agreed — user said "implement 089" (2026-08-17)

Facade approach (Q3). 13 consumer scripts are **not touched**. Five files change, each in **both trees**.

## What the audit of ProfileStore v1.0.3 changed about the plan

Three findings from reading the actual module source, none of which were in the intake:

1. **ProfileStore registers its own `game:BindToClose`** (`ProfileStore.luau:2208`) and saves + releases
   every active profile there. **Our `ProfileServer` BindToClose becomes redundant and must go** — two
   shutdown handlers racing over the same profiles is worse than one.
2. **ProfileStore auto-saves internally every 300 s.** Our 60 s `AUTOSAVE_INTERVAL` loop must go too, or
   we do 5× the DataStore writes for no benefit.
3. **`Profile:Save()` and `Profile:EndSession()` do NOT yield** — both `task.spawn` the actual write.
   The old `Profiles.save()` *did* yield until the write landed. **This silently breaks the receipt
   path**: `MonetizationServer` returns `PurchaseGranted` immediately after `Profiles.save()`, which
   would now mean "granted" before anything is durable. Handled below — and it turns out to be an
   improvement, not just a repair.

Plus the one that decides the whole fallback design:

4. **When `DataStoreState ~= "Access"`, ProfileStore silently swaps in an in-memory mock store**
   (`:596`) and `StartSessionAsync` returns a **perfectly normal-looking Profile that persists nothing**.
   So "did we get a Profile?" is *not* the same question as "will anything be saved?", and the money
   guard has to ask the second one.

---

## 1. Vendor the module

`sync/ServerScriptService/Vendor/ProfileStore.luau` + the lobby copy. Unmodified, with a provenance
header noting version **1.0.3**, commit `9580f7c`, and *do not edit — re-vendor to update*.

Both `default.project.json` files map `ServerScriptService` → their own `sync/ServerScriptService`, so
this needs no Rojo change. `realm = "server"` in the module's own `wally.toml`; it stays out of
`ReplicatedStorage`.

## 2. `ProfileConfig.luau` — store names + retire dead tuning

- `STORE_NAME_DEV` → **`PlayerProfiles_ps_v1`** (Q2: start dev clean).
- `STORE_NAME_LIVE` → **`PlayerProfiles_live_ps_v1`**. The old live store is empty (Job #085, still
  Private), but ProfileStore's on-disk shape is not ours — a fresh name guarantees no key is ever read
  in the legacy format, and costs nothing.
- `AUTOSAVE_INTERVAL`, `LOCK_STALE_SECONDS`, `LOAD_RETRIES` are now ProfileStore's business. **Delete
  them** rather than leave constants that no longer control anything.
- `default()` and `migrate()` are **kept unchanged** and stay in `ReplicatedStorage` (client-safe).
  `migrate()` is used in preference to `Profile:Reconcile()` — it already deep-fills `stats` and
  *type*-checks `paint`, which `Reconcile` does not.

## 3. `Profiles.luau` — same 12 methods, ProfileStore underneath

`load` → `store:StartSessionAsync(key, {Cancel = player left})`, then `AddUserId` (GDPR),
`ProfileConfig.migrate(profile.Data)`, `data.__lock = nil` (defensive; the old format kept its lock
inside the data), and an `OnSessionEnd` hook.

`save(p, release)` → `EndSession()` when `release`, else `Save()`.
`get` / `getGold` / `addGold` / `trySpendGold` / `addRiverScore` / `setPaint` / `getPaint` / `isReady`
/ `unload` / `_publish` — **unchanged logic**, still operating on the in-memory table.

Two additive methods (additive = no call site breaks):

- **`Profiles.isPersisting(player)`** — `profile ~= nil` **and** active **and**
  `ProfileStore.DataStoreState == "Access"`. This is finding 4: the only honest answer to "will a write
  survive?"
- **`Profiles.isPurchaseSaved(player, pkey)`** — reads `Profile.LastSavedData.purchaseIds[pkey]`.

**Session lost mid-play** (`OnSessionEnd`, e.g. another server steals the session): match the old
behaviour — warn, stop saving, let them keep playing on the in-memory table. ProfileStore's convention
is to kick; we keep the fallback per Q4, and the money guard covers the dangerous half.

## 4. `ProfileServer.server.luau` — delete two things

Drop the 60 s autosave loop and the `BindToClose` block (findings 1 + 2). Keep `PlayerAdded` → load,
`PlayerRemoving` → `save(release = true)` + `unload`, leaderstats, and `_G.LR_Profiles`.

## 5. `MonetizationServer.server.luau` — the money guard

Two changes to `processReceipt`, both required by finding 3:

- **Refuse to consume a receipt that cannot be persisted.** `if not Profiles.isPersisting(plr) then
  return NotProcessedYet end`. Covers the fallback profile *and* the mock store. This is the step the
  intake called for.
- **Adopt ProfileStore's documented receipt pattern.** Grant into `Data`, call `Save()`, and return
  **`NotProcessedYet`** — then on Roblox's retry, `isPurchaseSaved()` sees the id in `LastSavedData`
  and *that* call returns `PurchaseGranted`.

  This is stricter than what it replaces. Today the code returns `PurchaseGranted` the moment
  `purchaseIds[pkey]` is set **in memory**; if the server dies before the write lands, the receipt is
  consumed and the player's Gold is gone. Keying the decision on `LastSavedData` means a receipt is
  only ever consumed once the grant is **on disk**. The player still sees their Gold instantly — the
  in-memory grant and `_publish` are unchanged.

## Verification

`tools/luau-analyze.sh` and `tools/luau-analyze.sh --lobby` must both be clean. Everything else is the
intake's verification plan and needs a human in a real session — contention across the teleport, a real
purchase, and a forced failed load.
