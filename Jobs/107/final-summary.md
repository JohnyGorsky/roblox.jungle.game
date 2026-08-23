# Final Summary — Job #107

**Project**: `roblox.jungle` · **Place**: GAME (`Last River COOP Game`, 138141472932347)
**Closed**: 2026-08-23
**Status**: ⚠️ **Part 1 done and confirmed by the user. Part 2 implemented but NEVER RUN.**

### ✅ Auto-synced files

- `sync/ServerScriptService/World/CampDefs.luau` (part 1)
- `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` (part 1)
- `sync/ServerScriptService/Staging/StagingServer.server.luau` (part 2)
- `sync/ServerScriptService/Progression/AdminServer.server.luau` (part 2)
- `sync/StarterPlayer/StarterPlayerScripts/UI/AdminClient.local.luau` (part 2)

### ⚠️ Manual Studio copy required

- _none_

The **lobby tree was not touched** — verified with an empty `git diff -- lobby/`, which matters because
`AdminServer` and `AdminClient` both exist there as "identical copies".

---

# Part 1 — the trading post is the RobuxShop kiosk ✅

**Confirmed working by the user in gameplay** ("trading post now is ok"), after two rounds of fixes.

| | before | after |
|---|---|---|
| model | `BahayKubo7` | `RobuxShop` (same kiosk as the crash-site shop) |
| footprint | 40.2 × 25.8 × 50.2 | 24.5 × 21.3 × 19.4 |
| **parts per village** | **95** | **6** |

The size change is the point, not the look: Job #106's sign sits at `approach * 16`, which was *inside*
a 40 × 50 footprint. At 24.5 × 19.4 the TRADING POST board stands clear beside the shop.

## Two bugs shipped and then fixed — both found by the user, not by me

**1. The kiosk was placed lying on its side.**
Root cause: every one of the model's six parts is upright (`UpVector:Dot(Y) = +1.000`) but the MODEL
PIVOT reads `rot(90°, 0°, -90.5°)`, `upDot = -0.000`. `PivotTo` transforms geometry by
`target × pivot⁻¹`, so a rotated pivot lays the whole building over.

⚠️ `AssetPivots` does **not** catch this. It repairs pivot **position** (bounding-box centre) for models
more than a stud out and leaves **rotation** alone — correct for the rocks it was written for, silent
for this. Fixed with an opt-in `PropOpts.upright` flag on `prop()` that clears `PrimaryPart` (WorldPivot
is ignored while one exists — the same trap `AssetPivots` documents) and strips the rotation from
`WorldPivot` before placing. **Opt-in on purpose**: fixing rotation globally in `AssetPivots` would
re-orient all 22 repaired library models.

**2. A "ROBUX SHOP" billboard survived in the camp.**
I stripped by NAME (`EntrySign`) and the branding is in three places that do not share a parent:

```
EntrySign > Board > SurfaceGui > TextLabel    "ROBUX SHOP"
EntrySign > Board > SurfaceGui > TextLabel    "ROBUX SHOP"
Anchor    > BillboardGui > TextLabel          "ROBUX SHOP"   ← NOT under EntrySign
```

Now stripped **by type** — every `SurfaceGui` and `BillboardGui` in the clone — which a re-import moving
things around cannot defeat. Warns if it finds none. Done on the CLONE only, so `AssetLibrary` and
`Workspace.SpawnBase.Stands.RobuxShop` keep their own signage.

Also: the kiosk's invisible 1 × 1 × 1 `Anchor` is forced `CanCollide = false`, because `prop()` applies
one `collide` flag to every BasePart and it would otherwise be a solid block in the doorway.

## Not changed, as required

`MODEL.post` is referenced in exactly one place (`ExcursionServer`, `buildTradingPost`), so no other
building could be affected. `hut` (`BahayKubo5`), `hutAlt` (`BahayKubo1`) and `tent` are untouched.

---

# Part 2 — admin "TP to First Camp" ⚠️ UNVERIFIED

**Written, synced, analyzer-clean, statically wired — and never executed once.** Do not treat it as
working. It is recorded as **todo 0061**.

## The diagnosis (this part IS measured — observed live in Job #106's session)

The button already existed and did nothing from the spawn base, for three separate reasons:

1. **The camp cannot build.** `RiverBootstrap` keeps `AHEAD_CHUNKS` (7 ≈ 1800 studs) generated ahead of
   **the boat**. Moored at z ≈ −270 that reaches z ≈ 1530; the first landing is at **z = 1600**, and
   `terrainReadyAt` samples 150 further. Console, verbatim: `[Excursion] ForceFirstCamp: river terrain
   never reached the first landing — nothing built`.
2. **Even if built, the ground is culled** outside `[boat − 2, boat + 7]` chunks.
3. **The failure was invisible** — `AdminClient` did `pcall(function() rf:InvokeServer(a.action) end)`,
   discarded the result and closed the panel regardless.

## What was built

`tpFirstCamp` is now a sequence: release the moor → move the boat to the landing → build → pre-stream →
teleport → return a real status. The moor release is not optional: before the run starts, a Heartbeat
loop in `StagingServer` steers the hull back to its berth at up to **16 studs/s**, so a boat moved 1900
studs downstream would sail home and drag the generation window with it. It is released through a new
`ServerStorage.ForceStartRun` BindableFunction that calls StagingServer's own `startRun`, bypassing only
its "someone must be aboard" gate — copying its six side-effects into AdminServer would have rotted.

`AdminClient` now reads the result: the panel closes only on success, and a failure prints the reason
(`camp-not-built`, `no-landing`, `no-forcecamp`, `no-char`) on the button.

## Wiring verified statically (NOT behaviourally)

Button entry → client reads result → server branch → both hooks exist and are created by ExcursionServer
:2158 and StagingServer:242. Scope and RiverData APIs check out. **That only means nothing is nil.**

## Untested claims that could still be wrong

- `Player:RequestStreamAroundAsync` being callable from the server (wrapped in `pcall`, so worst case is
  a slower arrival, not an error)
- the boat surviving a `PivotTo` 1900 studs downstream without the physics assembly misbehaving
- `ForceFirstCamp` finishing inside its 30 s poll once the boat arrives
- the RemoteFunction blocking for those seconds without the client giving up
- ⚠️ `StagingServer` has a top-level `return` at line 59 if `SpawnBase` lacks `SpawnLocation` or
  `Dock.BoatPlace` — that halts the script **before** `ForceStartRun` is created. Harmless in this place
  (staging boots), but then the boat would not be released.

**Known side effect by design:** the jump moves the boat and starts the run, which moves anyone standing
or seated on it.

---

## Ground rules not met

- **§7 verification** — Part 1 was verified by the USER in gameplay, not by me; Part 2 was not verified
  at all. No before/after capture pair was taken for either.
- **§8 independent reviewer** — an agent was prepared and the user cancelled it on time grounds. Not run.

Both are recorded here rather than left implicit.
