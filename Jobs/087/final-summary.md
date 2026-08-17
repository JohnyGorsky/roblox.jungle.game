# Final Summary — Job #087

**Project**: `roblox.jungle`
**Completed**: 2026-08-17
**Status**: ✅ Completed — **confirmed in playtest by the user: boat, gun and camera all ride smoothly.**

Started as an UNDERSTAND-FIRST job (deliverable = a diagnosis, not a change). It ended up shipping the
fix too, because the bisect that produced the diagnosis also produced the answer. Full working is in
[investigation.md](investigation.md); this is the outcome.

---

## The complaint

> *"riding the boat glitches, riding is not smooth, it vibrates somehow. Lots of Roblox games feel
> smooth; this does not."* — 2026-08-16, [todo 0050](../../todo/0050-boat-ride-is-not-smooth-vibrates-glitche.md)

## Three faults, not one — which is why no single measurement found it

| # | Fault | How it was proven | Fix |
| --- | --- | --- | --- |
| 1 | **Engine fluid forces fighting our buoyancy spring** | bisect: spring bypassed → *"now it is perfect"* | `hull.EnableFluidForces = false` |
| 2 | **`BoatCamera` amplifying the hull's replicated pose residual into the whole view** | bisect: camera restored with the spring still bypassed → *"now it shakes again"* | chase camera retired; default camera + FOV swell kept |
| 3 | **Gun barrel + searchlight posed by server CFrame writes** | measured **1.14 avg / 6.38 max** studs drift under power vs **0.0000** on welded parts | posed per-client from `GunBase` |

Each one alone was enough to make the ride feel bad. That is why three rounds of measurement kept
clearing the wrong things — and why the bisect found all three in minutes.

---

## What shipped

### Fault 1 — `EnableFluidForces = false` on the hull (`BoatServer.server.luau`)

**The actual root cause, and it was hiding in a property nobody set.** `EnableFluidForces` defaults to
`true`, so the *engine* was applying its own buoyancy and drag to the hull at the same time as our
`Buoy` spring. Density is 0.7 — lighter than water — so Roblox floats the hull natively whether we ask
it to or not. Two independent systems driving the same DOF is the `roblox-physics` skill's first
gotcha, and it produces exactly this.

The arithmetic clears the spring by itself: at `FLOAT_K = 8` / `FLOAT_D = 8` the damping ratio is
`8 / (2·√8) = 1.41`. **Above 1 is overdamped — it cannot oscillate on its own.** The 1.7–2.1 stud
heave measured at ~0.6 Hz sat right beside the spring's 0.45 Hz natural frequency: the signature of an
overdamped system *being driven*, not of a mistuned spring.

It only showed up under way because at rest both systems settle to one shared equilibrium — measured
**0.000 studs peak-to-peak**, which is precisely what made buoyancy look innocent for three rounds.
Under power the engine's fluid force varies with velocity and submerged volume, so it becomes a driver
and drives our spring near its resonance.

⚠️ The investigation's own *"Still to check before implementing"* list had **"whether
`EnableFluidForces` should be disabled on the hull, measured rather than assumed"** as an open item. It
was the answer.

### Fault 2 — the chase camera is retired (`BoatCamera.local.luau`)

`update()` built `desired` from the **raw** `hull.Position` each frame and only then eased toward it.
The hull is a server-owned physics body carrying a replication residual of **0.47 studs average / 7.13
max** at cruise — unobtrusive on the boat, but the camera converted it into motion of the entire view,
where the eye is far more sensitive. A smoothed follow of a jittery point is not a smooth camera.

`USE_CHASE_CAMERA = false`; the boat now uses Roblox's default camera.

- ⚠️ **Not a dev toggle and not Studio-gated.** An earlier revision of this flag *was* Studio-gated,
  which would have shipped the retired camera to real players while looking fixed in Studio.
- **What survived:** the speed-based FOV swell, split out as `BoatSpeedFov.local.luau`. Safe on its own
  — FOV is not a position and cannot amplify jitter.
- **What was given up:** auto-follow of the boat's heading (the player swings the view around bends
  themselves) and the raised follow height / look-ahead. Judged acceptable in playtest —
  *"i like camera now… it is prod ready"*.
- The file keeps a full revival note: fix the position target first, or the shake comes back with it.

### Fault 3 — gun and searchlight posed per-client (Phase 1)

Both parts are `Anchored` and the **server** wrote their CFrame every Heartbeat from the server's view
of the hull, while the client renders an interpolated one — so they landed about one frame of travel
out. At 53.3 studs/s and 57 fps the boat covers 0.93 studs/frame and the measured average drift was
**1.14 studs**: almost exactly one frame.

New **`BoatTurretVisual.local.luau`** poses both every frame from local state, built off `GunBase` —
welded into the assembly and measured at **exactly 0.0000** drift. `GunServer` publishes `GunPitch`
alongside `GunYaw` and stops writing `barrel.CFrame`; `BoatModules` stops writing the searchlight head.
Hit detection is untouched and stays server-authoritative — the raycast never reads the part's CFrame.

The local gunner poses from their own input rather than the replicated attribute, so the person aiming
gets a zero-latency barrel for free.

**Phase 1 shipped first and changed the shake by 0%** — worth recording, because it removed a confound
and made the bisect that followed readable.

---

## Files changed

| File | Change |
| --- | --- |
| `sync/ServerScriptService/Boat/BoatServer.server.luau` | `EnableFluidForces = false` + the reasoning; `DEV_BUOYANCY_SLIDE` back to `false` |
| `sync/StarterPlayer/StarterPlayerScripts/Boat/BoatCamera.local.luau` | chase camera retired behind `USE_CHASE_CAMERA = false` |
| `sync/StarterPlayer/StarterPlayerScripts/Boat/BoatSpeedFov.local.luau` | **new** — the FOV swell, kept from the retired camera |
| `sync/StarterPlayer/StarterPlayerScripts/Boat/BoatTurretVisual.local.luau` | **new** — client posing of barrel + searchlight head |
| `sync/ServerScriptService/Combat/GunServer.server.luau` | publishes `GunPitch`; stops writing `barrel.CFrame` |
| `sync/ServerScriptService/Boat/BoatModules.server.luau` | stops writing `SearchlightHead` CFrame |
| `sync/StarterPlayer/StarterPlayerScripts/Combat/GunClient.local.luau` | feeds local aim to the visual |
| `sync/ServerScriptService/Intro/PlaneServer.server.luau`, `Dev/DevSpawnAtBoat.server.luau` | `DEV_SKIP_INTRO` scaffold added for testing, then **deleted** (todo 0051) |

## Verification

- [x] Playtested by the user, 2026-08-17 — boat, gun and camera all smooth; camera called *"prod ready"*
- [x] `DEV_BUOYANCY_SLIDE = false` (diagnostic only; must stay false to ship)
- [x] `USE_CHASE_CAMERA = false` is the shipped behaviour, not Studio-gated
- [x] `DEV_SKIP_INTRO` scaffold and `sync/ServerScriptService/Dev/` removed (todo 0051)
- [ ] **Not yet checked on a phone.** The investigation flagged a mobile capture as required and it has
      not been done. Retiring the chase camera changes what a touch player sees on every bend, so this
      needs the Device Emulator or a real device — it rides with [todo 0014](../../todo/0014-custom-mobile-boat-controls-before-publi.md).

## Lessons recorded

Both are in [investigation.md](investigation.md) in full; they are the ones worth carrying:

1. **A spring that is stable at rest tells you nothing about a spring under load.** `0.000` studs
   peak-to-peak at rest cleared buoyancy for three rounds. The failure mode is under-way-only by
   definition — measure the vertical axis *while driving*, and judge it on **amplitude, not frequency**.
   A 1.7-stud heave on a 3-stud hull is enormous however slow it is.
2. **"The pose updated on 97% of frames" is not evidence of smoothness.** Updating every frame and
   updating to the *correct* value are different questions; only a residual against the body's own
   velocity separates them.
3. **Bisecting beat measuring.** Three rounds of instrumentation found the wrong culprit twice. Turning
   suspects off one at a time found all three faults in minutes, and was the user's call.

## What this job did NOT do

**Network ownership was not changed, and does not need to be.** The hull stays server-owned
(`SetNetworkOwner(nil)`), which was the central question in the intake. The 0.47-stud pose residual is
real, but it is present in slide mode too — and slide mode felt perfect. Ownership therefore affects
**input latency only**, a separate and much milder complaint, and the Phase 2 redesign is not required.

⚠️ The caution stands for whoever reopens it: **do not hand ownership to the driver without also moving
the buoyancy force loop off the server.** A server loop computing force from a client-owned body's
lagged state is the Job 003 bounce, and it will come straight back.

## Closes

- [todo 0050](../../todo/0050-boat-ride-is-not-smooth-vibrates-glitche.md) — boat ride not smooth
- [todo 0047](../../todo/0047-turret-searchlight-lag-behind-the-boat-w.md) — turret/searchlight lag (Phase 1)
- [todo 0051](../../todo/0051-revert-dev-skip-intro-spawn-at-boat-togg.md) — revert the dev skip-intro scaffold
