# Implementation Plan — Job #107

**Project**: `roblox.jungle`
**Place**: GAME (`Last River COOP Game`, 138141472932347) — `sync/` only. Lobby untouched.
**Created**: 2026-08-23
**Status**: Planning (awaiting go-ahead)

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

Play only. `screen_capture` cannot show ProximityPrompt bubbles ([[job #106]]), so prompt state comes
from `#PlayerGui.ProximityPrompts:GetChildren()` and from pressing the key.

- [ ] **Part 1 — before/after from the same camera**: the trading post is the kiosk, the TRADING POST
      board stands clear beside it, and **no "ROBUX SHOP" text exists anywhere in the camp**
      (enumerate every TextLabel under the LandingSite — failure = a stray ROBUX SHOP label).
- [ ] **Part 1 — the shop still works**: walk up, hold E, `OpenShop` fires and the panel opens.
- [ ] **Part 1 — nothing else changed**: enumerate camp buildings before/after; `BahayKubo5`,
      `BahayKubo1` and `Tent` counts must be identical. Failure = any other building swapped.
- [ ] **Part 1 — the kiosk is seated on the ground**, not floating or sunk (measure base vs terrain).
- [ ] **Part 2 — press the actual button in the actual panel** from a fresh Play at the spawn base,
      before untying. Failure = landing in the void, falling, no camp, or a silent close.
- [ ] **Part 2 — the camp is RENDERED on arrival**: the client can see the kiosk and the sign within a
      second of landing (assert the instances exist client-side, not just server-side).
- [ ] **Part 2 — `RequestStreamAroundAsync` is actually callable from the server** — verified live, not
      assumed from memory.
- [ ] Every check above states what failure looks like.
