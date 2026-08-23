# Implementation Plan — Job #107

**Project**: `roblox.jungle`
**Place**: GAME (`Last River COOP Game`, 138141472932347) — `sync/` only. Lobby untouched.
**Created**: 2026-08-23
**Status**: CLOSED. Part 1 done + user-confirmed. Part 2 implemented but NEVER RUN (todo 0061). See final-summary.md.

Two independent parts, one job because you asked for them together.

---

# Part 1 — the trading post becomes the RobuxShop kiosk

## What's there now

`buildTradingPost` clones `CampDefs.MODEL.post`, which is `"BahayKubo7"`. Measured in this place:

| model | bounding box | parts |
|---|---|---|
| `BahayKubo7` (now) | 40.2 × 25.8 × 50.2 | **95** |
| `RobuxShop` (proposed) | 24.5 × 21.3 × 19.4 | **6** |

The kiosk is **already in the library** at `ServerStorage.AssetLibrary.Structures.RobuxShop` — same
model the crash-site kiosk uses, identical bounding box and baked scale (1.564). Nothing to import.

The oversized stilt house is the root cause of Job #106's whole problem: the sign at `approach * 16`
landed *inside* a 40 × 50 footprint. At 24.5 × 19.4 the sign now stands clear, beside the shop —
which is what you asked for.

## Changes

1. **`CampDefs.MODEL.post` → `"RobuxShop"`**, with the part count comment corrected (95 → 6).
   ⚠️ `hut`, `hutAlt` and `tent` are **not touched** — `MODEL.post` is referenced in exactly one place
   (`ExcursionServer:1582`), so no other building can be affected. Verified by grep.
2. **Strip the kiosk's own `EntrySign` from the camp clone** (your call). It reads "ROBUX SHOP" on two
   SurfaceGuis and an **AlwaysOnTop BillboardGui** — wrong text for a salvage trader, and Job #077
   removed exactly that kind of billboard from world signage because it renders through terrain.
   Done on the **clone**, so `AssetLibrary` and `SpawnBase.Stands.RobuxShop` are untouched.
3. **The kiosk's `Anchor` part gets `CanCollide = false`.** `prop()` sets `CanCollide` on every BasePart
   from one `collide` flag, so this invisible 1 × 1 × 1 marker would otherwise become an invisible
   obstacle at the shop door.

## Things checked so they don't bite

- **Scale survives.** `prop()` does `clone:ScaleTo(clone:GetScale() * scale)` and skips the block
  entirely when there is no `CampDefs.SCALE` entry, so the baked 1.564 is preserved. No SCALE entry
  needed — a bare `ScaleTo(1.0)` would have shrunk it, which is the trap that comment warns about.
- **Pivot is already handled.** `RobuxShop` has `PrimaryPart = RobuxhShop` and a pivot **4.76 studs**
  off its bounding centre. `AssetPivots` repairs any library model over 1 stud out at boot (clears
  PrimaryPart, rewrites WorldPivot), and it runs over the whole library, so this is automatic. It
  touches `ServerStorage` only — the editor-placed SpawnBase kiosk is not affected.
- **Downstream numbers re-derive themselves.** Gold-chest standoff and the Job #106 prompt reach are
  both computed from the model's bounding box, so they follow the smaller building automatically
  (reach becomes ~22 instead of 35.1).

---

# Part 2 — "TP to First Camp" lands you in a rendered camp

## Why it fails today

The button already exists (`AdminClient:130` → `AdminServer` `tpFirstCamp` → `ForceFirstCamp`). Three
separate reasons it does nothing useful from the spawn base:

1. **The camp cannot build.** `RiverBootstrap` keeps `AHEAD_CHUNKS = 7` (~1800 studs) generated ahead
   of **the boat**. Moored at z ≈ −270, that reaches z ≈ 1530. The first landing is at **z = 1600**,
   and `terrainReadyAt` samples ±150 further. Observed live: `[Excursion] ForceFirstCamp: river terrain
   never reached the first landing — nothing built`, and the call returns nil.
2. **Even if built, the ground goes away.** The generation window culls anything outside
   `[boat − 2, boat + 7]` chunks, so terrain under a far-off camp is removed and you fall.
3. **The failure is silent.** `AdminClient` does `pcall(function() rf:InvokeServer(a.action) end)` and
   throws the result away, then closes the panel. A failed jump is indistinguishable from a working one.

## Changes

**a. `StagingServer` exposes `ServerStorage.ForceStartRun`** (BindableFunction), calling its existing
`startRun()` but bypassing the "someone must be aboard" gate. Needed because while the run has not
started, a Heartbeat loop steers the boat back to its berth at up to **16 studs/s** — move the boat
without releasing the `Moor` LinearVelocity and it simply sails 1900 studs home. Exposing the existing
function beats copying its six side-effects (RunStarted, Moor destroyed, Tied, prompt, HubSpawn) into
AdminServer where they would rot.

**b. `AdminServer.tpFirstCamp` becomes a sequence with a real status:**

1. release the moor via `ForceStartRun` if `Workspace.RunStarted` is false;
2. move the boat to the first landing's dock (hull at `WATER_Y + 2`, in the channel at
   `RiverData.centerlineX(dock.z)`), zeroing velocity so the assembly doesn't carry momentum;
3. poll `ForceFirstCamp` — it already refuses until `terrainReadyAt` passes and retries for 30 s;
4. **`player:RequestStreamAroundAsync(campPos)`** so the client has the camp streamed in before arrival
   — this is the "must be rendered" half;
5. move the character;
6. return `{ ok = true, … }` or a specific reason.

**c. `AdminClient` surfaces the outcome** instead of discarding it — the button reports success or the
failure reason rather than the panel closing on nothing.

## Open risk, stated not hidden

Moving the boat **moves anyone standing or seated on it** and starts the run. That is what a dev jump
means, but it is a real side effect on a co-op server, so the returned status will say the run was
started. If you would rather it never touched the boat, say so and I'll build the chunk-pin variant
instead — it is the option you passed on, and it is not too late.

---

## Files

| file | part |
|---|---|
| `sync/ServerScriptService/World/CampDefs.luau` | 1 |
| `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` | 1 |
| `sync/ServerScriptService/Staging/StagingServer.server.luau` | 2 |
| `sync/ServerScriptService/Progression/AdminServer.server.luau` | 2 |
| `sync/StarterPlayer/StarterPlayerScripts/UI/AdminClient.local.luau` | 2 |

All auto-synced per `.jobconfig.json`. `AdminServer` is described in its own header as an "IDENTICAL
copy in both trees" — **the lobby copy will NOT be touched**, and the divergence gets a comment saying
why (`tpFirstCamp` is game-only; the lobby has no `ForceFirstCamp`, which its own comment already notes).

## Independent review (GROUND-RULES §8)

Skipped again per your standing instruction this session. Recorded, not glossed.

## Verification — gates (GROUND-RULES §7)

Closed early at the user's request. Honest status:

- [x] **Part 1 a/b — kiosk stands where the stilt house did, sign clear of it** — confirmed by the USER
      in gameplay ("trading post now is ok"), not by me.
- [x] **Part 1 c — no "ROBUX SHOP" text in the camp** — FAILED first (user screenshot showed the
      billboard), then fixed by stripping Surface/Billboard GUIs by type. User confirmed after the fix.
- [~] **Part 1 d — the shop still opens** — NOT re-verified after the model swap. The prompt is attached
      to the sign board, which this job did not touch, so it is very likely fine. Not proven.
- [x] **Part 1 e — no other building changed** — `MODEL.post` has exactly one reference, so nothing else
      can be affected. Verified by grep, which is a real check here.
- [~] **Part 1 f — kiosk seated on the ground** — not measured. It was also placed ON ITS SIDE at first
      (pivot rotation), which no measurement of mine caught; the user's screenshot did.
- [ ] **Part 2 a-d — ALL UNVERIFIED.** Never executed. Static wiring check only. See todo 0061.

### What went wrong in this job's process

Both Part 1 bugs reached the user because I verified by reading numbers instead of looking at the thing.
The bounding box measured 24.5 x 21.3 x 19.4 whether the building stood up or lay on its side, and
enumerating `EntrySign` said nothing about a billboard parented to `Anchor`. A single screenshot of the
placed kiosk would have caught both before shipping.
