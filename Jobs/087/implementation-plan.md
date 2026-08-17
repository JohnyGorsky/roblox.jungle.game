# Implementation Plan — Job #087

**Project**: `roblox.jungle`
**Status**: Planning (awaiting go-ahead)

Covers **both** faults found in [investigation.md](investigation.md), in one job by the user's
decision. Phase 1 is a certain fix; Phase 2 is a measured spike that ends in a decision, not a commit.

| Fault | What | Phase |
| --- | --- | --- |
| 2 | Gun + searchlight drift up to **6.38 studs** from the hull under power | 1 — implement |
| 1 | Hull's rendered pose is **0.47 avg / 7.13 max studs** off its own velocity | 2 — spike, then decide |

---

## Phase 1 — Gun and searchlight stop drifting

**Approach chosen: position them on the client.**

### Why this works, precisely

Both parts are `Anchored` and the **server** writes their CFrame every Heartbeat, derived from the
server's view of the hull. The client renders a *different* hull pose (interpolated), so the parts land
about one frame of travel out — measured at 1.14 studs average against 0.93 studs of per-frame travel.

The fix removes the mismatch by construction: compute the pose **on each client, from that client's own
hull pose**. There is already a perfect reference frame to build from — `GunBase` is welded into the
assembly and measured at **exactly 0.0000** drift. Same source, same frame, no lag possible.

It also survives whatever Phase 2 decides, because it never depends on who owns the hull.

### Steps

1. **`GunServer.server.luau`**
   - Publish **`GunPitch`** alongside the existing `GunYaw` (same 0.005 rad change-threshold, so this
     adds no replication traffic while the gun is still).
   - **Stop writing `barrel.CFrame`** in the Heartbeat loop. ⚠️ This is required, not optional — a
     server write replicates and would fight the client's local write every frame.
   - Keep `aimCFrame()` and the firing raycast **exactly as they are**. Hit detection stays
     server-authoritative and never reads the part's CFrame, so accuracy is unaffected.
   - Keep the recentre-when-unoccupied behaviour; it just publishes instead of posing.
2. **`BoatModules.server.luau`** — same treatment for `trackSearchlight`: stop the per-frame CFrame
   writes to `SearchlightHead` and its `Skin_searchlightHead`. Keep the weld removal and the
   `Anchored = true`, since the client will now pose them.
3. **New `sync/StarterPlayer/StarterPlayerScripts/Boat/BoatTurretVisual.local.luau`** — one
   `BindToRenderStep` at `Camera` priority that poses both, every frame, from local state:
   - barrel: `GunBase.CFrame * CFrame.Angles(pitch, yaw, 0) * CFrame.new(0, 0, -barrel.Size.Z/2)`
   - searchlight head: from the local `Hull.CFrame` and the yaw, then its skin from the head's own
     captured local offset — mirroring what the server does today.
   - ⚠️ **The local gunner uses their own input directly, not the replicated attribute.** Everyone else
     reads `GunYaw`/`GunPitch`. That gives the person aiming a zero-latency barrel and costs nothing.
4. Sounds stay parented to the barrel and keep working; the SpotLight stays parented to the head.

### Why client CFrame writes are safe here

A client writing to a server-owned anchored part changes only its own view — the write does not
replicate. That is exactly what we want: every client poses these two parts for itself, from the hull
pose it is actually rendering. Nothing is authoritative about a barrel's visual angle; the server keeps
the aim numbers and the raycast.

### Success criterion

Re-run the measurement harness from investigation §8 while driving straight at ~53 studs/s:

```
GunBarrel / SearchlightHead drift vs hull   -> avg < 0.01 studs   (today: 1.14 / 1.15)
GunBase / GunSeat                           -> stays 0.0000       (control, must not regress)
```

---

### ✅ Phase 1 RESULT (playtested 2026-08-17)

**User verdict: "mounts feels ok" · "lights also" · "but boat same".**

Phase 1 is **verified fixed**, and it did something more valuable than fix itself: it **removed the
confound**. Fault 2 and Fault 1 were within 10% of each other in magnitude (6.38 vs 7.13 studs), so
neither could be attributed on the evidence available. Now:

- the gun and searchlight are subjectively correct → **Fault 2 closed**, and `todo/0047` with it;
- the shaking is *unchanged* → **Fault 1 is the entire remaining problem**, not a contributor to it.

The earlier worry — that fixing the gun might account for most of the shaking — is answered: it
accounted for none of it. Phase 2 now proceeds against a clean signal.

---

## Phase 2 — Hull rendering: two spikes, then a decision

**Approach chosen: prototype both, measure, bring numbers back before committing.**

Nothing here ships without a second go-ahead. Both spikes are throwaway.

### Spike A — constraint / native flotation

Can the scripted buoyancy spring go away entirely? The hull is already `density 0.70` in terrain water
with `EnableFluidForces = true`, so the engine can float it natively; damping would come from a
constraint rather than a per-frame `buoy.Force =` write.

If it works, **the reason for server ownership disappears** — nothing reads the body's state each
frame, so there is no feedback loop and the driver can own the hull.

⚠️ The `roblox-physics` skill explicitly warns *"Don't rely on terrain-water auto-buoyancy alone
(density<1 floats, but it's hard to tune/keep stable)"*. This is the option most likely to fight us,
which is exactly why it gets measured rather than assumed.

### Spike B — force loop on the driver's client

Keep the buoyancy maths **exactly as tuned today** (known-good, verified stable at 0.000 studs at rest)
and run it on the driver's client, with `SetNetworkOwner(driver)` to match. Less novel physics risk;
more client-side surface, and it needs server-side bounds checks because the client would then author
the boat's motion — GAME.md flags that real money rides on this game's authority model.

### What gets measured, for both

Using the harness already built and proven this session:

| Metric | Today | Target |
| --- | --- | --- |
| Rendered position residual vs constant velocity (cruise) | avg **0.47** / max **7.13** studs | avg < 0.05 |
| Rendered yaw change per frame | max **3.96°** (physical max 46°/s ≈ 0.8°/frame) | ≤ 0.8° |
| Hull Y peak-to-peak, at rest | 0.000 studs | ≤ 0.01 — **must not regress** |
| Hull Y range, cruising mid-channel | 0.53 studs | ≤ 0.6 |
| Sustained bounce while driven (the Job 003 failure) | none | **none** — hard gate |
| Mobile: same residual on a phone profile | unmeasured | measured before any commit |

### ⚠️ The one rule that must not be broken

**Do not change network ownership without also moving the force loop off the server.** A server loop
computing buoyancy from a client-owned body's lagged state *is* the Job 003 bounce — verified on this
boat, recorded in the `roblox-physics` skill. Either spike must move both together or neither.

---

## Testing aid already added (todo 0051 — temporary)

At the user's request, so boat work doesn't cost a walk from the spawn base every Play:

- `Intro/PlaneServer.server.luau` — `DEV_SKIP_INTRO` flag, early-returns down the existing
  missing-helper path (`IntroActive = false`).
- `Dev/DevSpawnAtBoat.server.luau` — **new**, drops you beside `SpawnBase.Dock.BoatPlace` on spawn.

Both are gated on `RunService:IsStudio()` **as well as** their own flag, so a published server cannot
take either path even if a flag is left on. **`todo/0051` tracks reverting them** — search the
codebase for `todo 0051` to find every touched line.

---

## Files

| File | Phase | Sync |
| --- | --- | --- |
| `sync/ServerScriptService/Combat/GunServer.server.luau` | 1 | ✅ auto |
| `sync/ServerScriptService/Boat/BoatModules.server.luau` | 1 | ✅ auto |
| `sync/StarterPlayer/StarterPlayerScripts/Boat/BoatTurretVisual.local.luau` | 1 — **new** | ✅ auto |
| `sync/ServerScriptService/Boat/BoatServer.server.luau` | 2 — spike only | ✅ auto |

All in the GAME tree; no lobby copies, no cross-place edit.

## What I need from you

- [ ] **Go-ahead for Phase 1** (the gun/searchlight fix).
- [ ] **A driving playtest after Phase 1** so I can re-run the drift measurement — and, importantly, so
      you can tell me **how much of the shaking is left**. Fault 2's magnitude (6.38 studs) was close to
      Fault 1's (7.13), so removing it may account for more of what you felt than I can currently
      separate.
- [ ] **A second go-ahead before Phase 2** — I bring spike numbers first; nothing is committed on my
      judgement alone.

## Verification

- [ ] Analyzer clean on every edited file.
- [ ] Drift harness: barrel + searchlight < 0.01 studs vs hull at cruise; `GunBase` still 0.0000.
- [ ] The gun still hits what it points at (server raycast unchanged) and the recentre-when-empty and
      night searchlight sweep both still work.
- [ ] The local gunner's barrel tracks their aim with no perceptible lag.
- [ ] Your subjective read on the ride after Phase 1, before any Phase 2 work begins.
