# Final Summary — Job #089

**Project**: `roblox.jungle`
**Completed**: 2026-08-17
**Status**: ✅ **COMPLETE (2026-08-17)** — playtest-confirmed by the user: progress survives the
lobby → river teleport and a rejoin. ⚠️ **One half is NOT confirmed — see "Still to verify" below.**

Persistence moved off the hand-rolled session lock (Job 021) onto **ProfileStore 1.0.3**. The facade
held: **13 progression scripts were not touched.**

---

## What shipped

### 1. Vendored `ProfileStore.luau` — `ServerScriptService/Vendor/`, both trees

v1.0.3, commit `9580f7c` (2025-03-25), verbatim under a provenance header. `--!nocheck --!nolint` so
four upstream lint warnings can't hide a real finding in our own code. Both `default.project.json`
files already map `ServerScriptService`, so no Rojo change was needed.

### 2. `Profiles.luau` — same 12 methods, ProfileStore underneath

The whole point of the facade. `load` starts a session, `save(p, release)` maps to `Save()`/
`EndSession()`, and every getter/setter still works on the in-memory table exactly as before.

Two additive methods, both for the money path:

- **`isPersisting(p)`** — the honest answer to "will a write survive?"
- **`recordPurchase(p, id, grant)`** — grant a dev product once, then yield until it is on disk.

### 3. `ProfileServer.server.luau` — two blocks deleted

The 60 s autosave loop and the `BindToClose` handler are gone. ProfileStore owns both.

### 4. `ProfileConfig.luau` — fresh stores, dead knobs removed

`PlayerProfiles_ps_v1` / `PlayerProfiles_live_ps_v1`. `AUTOSAVE_INTERVAL`, `LOCK_STALE_SECONDS`,
`LOAD_RETRIES` deleted — ProfileStore owns all three. `default()`/`migrate()` unchanged and still
client-safe in `ReplicatedStorage`.

### 5. `MonetizationServer.server.luau` — receipts rewritten

`processReceipt` now delegates to `Profiles.recordPurchase` and got shorter, not longer.

---

## Four things the code review of ProfileStore changed, that the intake did not know

**These are the reason the job was not a mechanical swap.** Each was found by reading the vendored
source, and each would have shipped a real bug.

### 1. `Profile:Save()` does not yield — and that silently broke the receipt path

`Save()` and `EndSession()` both `task.spawn` the actual write (`ProfileStore.luau:1172`, `:1090`).
The **old** `Profiles.save()` yielded until the write landed, which is what made
`MonetizationServer`'s `save(); return PurchaseGranted` defensible.

Ported literally, that same line would confirm a purchase **that had not been stored**, and
`PurchaseGranted` is a one-way door — Roblox never delivers that receipt again. A server crash in the
gap takes the player's Gold with it.

Fixed by adopting ProfileStore's official `PurchaseIdCheckAsync` pattern: grant into memory, then
**yield inside `ProcessReceipt`** until `LastSavedData` proves the write landed.
`MarketplaceService.ProcessReceipt` tolerates yielding — documented by ProfileStore from observed
Roblox behaviour. The player still sees their Gold instantly; only the receipt settles late.

### 2. A Profile can exist and persist nothing

When `DataStoreState ~= "Access"` (Studio with API services off, or no internet) ProfileStore silently
swaps in an **in-memory mock store** (`:596`) and `StartSessionAsync` returns a profile that looks
completely normal — `IsActive()` true, saves "succeed", nothing written.

So `profile ~= nil` is **not** the same question as "will this survive", and neither is `IsActive()`.
`isPersisting()` checks `DataStoreState` as well, and `recordPurchase` refuses outright when it is
false. Without this, a Studio purchase would consume a real receipt into nothing.

### 3. Passing `Cancel` disables ProfileStore's own timeout

`StartSessionAsync` applies `START_SESSION_TIMEOUT` (120 s) **only when `params.Cancel == nil`**
(`:1612`). A `Cancel` that just tests "did they leave?" therefore means that during a DataStore outage
the call retries **forever** for a player who is still sitting there — `load` never returns, `isReady`
never goes true, and the fallback profile that Q4 chose is never reached.

Our `Cancel` carries its own 60 s deadline. **60 and not less**: ProfileStore resolves a normal session
conflict by stealing at `SESSION_STEAL = 40 s`, and the lobby → game teleport *is* a session conflict on
every single run. Giving up sooner would hand players an unsaved profile in the ordinary case.

### 4. ProfileStore registers its own `BindToClose`

`:2208` — it saves and releases every active profile and yields until the writes finish. Keeping ours
would have been two handlers racing over the same profiles. Deleted, with a note in `ProfileServer`
explaining why it must not come back.

---

## One scope call I made, and why

**`purchaseIds` changed shape: dict `{[id] = true}` → FIFO array capped at 100.**

The official receipt pattern uses `table.find` over an array, and it caps the cache because profiles
have a **4 MB ceiling** while receipt ids accumulate for the life of the account. The old dict grew
without bound.

I took this now because **both stores were being renamed in this same job and start empty, so the
change is free today and never will be again.** `migrate()` also *resets* a leftover dict rather than
tolerating it — a dict reaching `table.find` would never match, and every receipt would grant twice.

The trade-off, stated plainly: after 100 purchases the oldest ids drop off, so a receipt Roblox
re-delivers after 100 further purchases could be granted a second time. That is the accepted trade in
the official pattern.

---

## Verification

- [x] `tools/luau-analyze.sh` — **GAME clean**
- [x] `tools/luau-analyze.sh --lobby` — **no new diagnostics.** Four pre-existing ones remain
      (`PilotIdle` ×3 `SameLineStatement`, `InventoryService` unknown require); confirmed identical by
      stashing this job's changes and re-running, so they are not from #089.
- [x] All five files byte-identical across `sync/` and `lobby/sync/` (sha256-checked)

### ✅ Confirmed by the user's playtest, 2026-08-17

Saving works end to end: progress survives the lobby → game teleport and a rejoin. That exercises the
session handover — the case the old 90-second lock timer handled badly and the whole reason for the job.

### ⚠️ STILL NOT CONFIRMED — the money path

**No Robux purchase was made during this playtest**, so the part of #089 with the highest consequence
is unproven in practice. It is the strictest code in the job and the most changed. Before the
experience goes Public, run these three deliberately:

1. **Buy a Gold pack.** The Gold should appear immediately and the receipt settle once.
2. **Buy the same pack again.** It should grant again (a second purchase is a second grant).
3. **Studio with API services OFF.** A purchase there must be **refused**, not consumed — finding 2 in
   this summary is precisely the case where a receipt could be eaten into a mock store.

### Remaining (lower risk)

1. **Round trip of every field.** Gold, modules, skills, paint, streak, weekly progress and stats out of
   the lobby, through a run, and back. The teleport itself is confirmed; the full field set is not.
2. **Failed load.** Force one; confirm the session is playable, never written, and refuses purchases.

⚠️ Verify through shared Instances (attributes / leaderstats / a real Play session), **not** by reading
module internals from the command bar — Studio and live DataStores differ.

## Not done

`todo 0017` is **resolved** — the persistence migration itself is confirmed. The unproven remainder is
the **receipt path** specifically, tracked in `todo 0055` rather than by holding 0017 open, so the
launch checklist reads honestly: persistence done, purchases untested.
