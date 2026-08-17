# Job #087 — Boat ride quality: diagnosis

**Project**: `roblox.jungle`
**Status**: ✅ **Closed — all three faults fixed and playtest-confirmed (2026-08-17).**
See [final-summary.md](final-summary.md) for what shipped. The root cause was the engine's own
`EnableFluidForces` fighting our buoyancy spring — the last open item on this document's own
*"Still to check before implementing"* list. Read below for the working, not for the current state.
**Measured**: live Studio game place, 2026-08-16, user driving

---

## Verdict

**The boat's physics is smooth. What you are seeing is the client rendering a pose it never
simulated.** Under identical steady-cruise conditions the server holds 50.7–53.2 studs/s while the
client's *rendered position* lands, on average, half a frame's travel away from where the boat's own
velocity says it should be — and at worst seven frames' worth away, in a single frame.

The hull is server-owned by deliberate design, so the driver's machine never simulates the boat. It
receives periodic snapshots and reconciles. At 52 studs/s those corrections are large enough to see.

---

## Measurements

### 1. At rest — the simulation is clean

```
Y peak-to-peak over 2s = 0.000 studs      velY noise = ±0.004
mass 991   awakeParts 60   physFPS 59.9   networkOwner = nil (server)
```

Rules out the buoyancy spring. A mistuned spring-damper would stand and oscillate. It does not.
Consistent with the code: damping is applied **outside** the up-only `math.max(spring, 0)` clamp
(`BoatServer:316-318`) and the cutoff sits at `WATER_Y + 12`, far above any bob. Both buoyancy traps
recorded in the `roblox-physics` skill — both learned on this boat — are already handled correctly.

### 2. Under way, server side, mid-channel at steady throttle — also clean

```
SPEED      min 50.7  max 53.2  avg 52.3      (5% variation)
HEIGHT     range 0.53 studs
sharpest deceleration in one step: -0.20 studs/s
touching = 0 at all times;  0 of 344 frames within 20 studs of a bank
```

Rules out bank scraping, obstacle collisions, and force instability. An earlier sample showed speed
dipping to 8.7 studs/s, but that was during acceleration and manoeuvring, not steady cruise.

### 3. Under way, client side, **same conditions** — this is the fault

```
SPEED (client)      avg 52.09   min 50.88   max 52.94   std-dev 1.4%
   -> velocity replicates FAITHFULLY; it matches the server almost exactly

POSITION RESIDUAL vs the boat's own constant-velocity prediction
   avg 0.4726 studs   max 7.1258   std-dev 0.6895
   as % of per-frame travel (0.95 studs):   avg 49.7%   max 749.6%

RENDERED YAW change per frame   avg 0.403°   max 3.956°
```

The velocity stream is clean. The **pose** is not. And the yaw figure is the clearest single proof:
3.956° in one frame at 55 fps is **218°/s**, while the boat's maximum turn rate is `TURN = 0.8 rad/s`
= **46°/s**. The boat cannot physically rotate that fast. That rotation was never simulated — it is a
correction being applied to the render.

### 4. What the middle measurement did *not* show

An intermediate sample found the pose changing on 97% of frames (~56 Hz against 58 fps) and I briefly
concluded replication was healthy. **That was wrong.** "The pose changed" and "the pose changed to a
correct value" are different questions; only measurement 3 separates them. Recorded here because the
same trap will catch the next person: a high update rate is not evidence of smoothness.

### 5. Incidental findings

- `ThrustMul = 1.625`, `CurrentMul = 0.85` — cruising at 52 studs/s against a base design cap of
  `THRUST/DRAG = 30` is **engine upgrades working**, not a bug.
- `EnableFluidForces = true` on the hull: the engine applies its own aerodynamic drag *and torque* to
  a 14×3×32 slab, on top of the custom `Drag` VectorForce, and unlike that force it is not
  horizontal-only. Not the cause of the snapping, but an untuned force nobody accounted for, and a
  likely contributor to the "clumsy" half of the complaint.
- `StreamingEnabled = true` with the boat covering ground at 52 studs/s — worth keeping in mind as a
  source of occasional hitches, though it cannot explain a sustained 50% residual.

---

## Why it is this way (and why the reason was good)

`BoatServer:268` claims `SetNetworkOwner(nil)` and the Heartbeat loop at `:284-300` re-grabs it every
frame whenever a client takes it. From the Job 003 review, 2026-07-18, and recorded in the
`roblox-physics` skill as a verified lesson from this very boat:

> **Server-computed force on a client-owned body = delayed-feedback instability.** If a server loop
> computes a force from the body's position/velocity (a buoyancy spring-damper), the body MUST be
> server-owned — otherwise the server reads lagged replicated state and applies the force a round
> trip late, so the spring pumps energy instead of removing it and the boat bounces higher and higher.

That is real, it was measured, and **any fix that simply hands ownership to the driver without moving
the force computation will re-break it.** The buoyancy loop and the ownership are one decision, not
two.

---

---

## 9. Bisect log (2026-08-17) — disabling suspects one at a time

The user's approach after Phase 1, and it is producing better answers than more measurement was.

| # | Disabled | Result | Reading |
| --- | --- | --- | --- |
| 1 | Gun + searchlight server posing (**Phase 1**, shipped) | "mounts feels ok · lights also · **but boat same**" | Fault 2 fixed; **contributed 0%** to the shake. Confound removed. |
| 2 | `BoatCamera` chase cam (`DEV_DISABLE_BOAT_CAM`) | **"a little bit better, like 50%, sometimes it still lags"** | The camera is roughly **half** the perceived shake — and about half remains without it. |
| 3 | Buoyancy spring (`DEV_BUOYANCY_SLIDE`) | **"now it is perfect, feel smooth"** | **The buoyancy spring is the main cause.** |

## ✅ CAUSE FOUND — the buoyancy spring, limit-cycling under way

With the spring replaced by a velocity-level hold, the ride is smooth. The chain:

| State | Feel |
| --- | --- |
| Everything on | shakes |
| Camera off | ~50% better, still shakes |
| Camera off **+ spring off** | **perfect** |

### The evidence was already in the measurements, and was explained away

Measurement 3 recorded, while driving:

```
VERTICAL: range = 1.696 studs, direction changes = 5  (~0.6 Hz bob)
```

and an earlier pass at 2.061 studs. **A 1.7–2.1 stud vertical heave at ~0.6 Hz on a boat 3 studs tall
is the spring oscillating.** It was noted as "a slow heave, not a vibration" and set aside because the
frequency was low — the wrong test. Amplitude, not frequency, is what the eye reads on a 32-stud hull.

### Why the at-rest reading was so misleading

Measurement 1 gave **Y peak-to-peak = 0.000 studs at rest** and that was treated as clearing buoyancy
entirely. It does not: it clears buoyancy *at rest*. The `roblox-physics` skill warns specifically
about **"two buoyancy traps that make a MOVING boat bounce forever"** — the failure mode is
under-way-only by definition. Both documented traps were checked in the source and found already
handled, which made the dismissal feel safe. There is evidently a third path to the same limit cycle
that neither trap describes.

⚠️ **Lesson for the next person: a spring that is stable at rest tells you nothing about a spring under
load.** Always measure the vertical axis while driving, and judge it on amplitude.

### Is the camera independently at fault? — ✅ ANSWERED: YES

Bisect step 4 restored the camera while leaving the spring bypassed. Result: **"now it shakes
again."**

So the camera is **not** merely following a bobbing hull — it is a **second, independent cause**. With
the spring gone the hull's vertical oscillation is gone too, and the camera *still* produces the shake
on its own.

**Mechanism.** `update()` builds `desired` from the **raw** `hull.Position` each frame and only then
eases `currentPos` toward it. The hull's rendered position carries a replication residual of **0.47
studs average / 7.13 max** (§3) — small enough to be unobtrusive on the boat itself, but the camera
turns it into motion of the *entire view*, where the eye is far more sensitive to it. A smoothed follow
of a jittery point is not a smooth camera.

⚠️ The file header claims the earlier fix ensured "nothing the camera uses is a raw replicated value".
**That is not true of the current code** — the aim point and forward vector were smoothed, but the
position target was not. That is the gap.

### FINAL: two independent causes, both confirmed by bisect

| # | Cause | Evidence | Status |
| --- | --- | --- | --- |
| 1 | **Buoyancy spring** oscillating under way (1.7–2.1 studs @ ~0.6 Hz) | spring bypassed + camera off → "perfect" | needs a real fix |
| 2 | **`BoatCamera`** amplifying the hull's replicated pose residual into the view | camera restored, spring still bypassed → "shakes again" | needs its own fix |
| — | Gun + searchlight drift | fixed in Phase 1; shake unchanged → **contributed 0%** | ✅ shipped |
| — | Network ownership / input latency | present in slide mode, which felt perfect → **not the shake** | out of scope |

Each on its own is enough to make the ride feel bad, which is why no single measurement isolated
either of them and why bisecting found both in minutes.

### Re-ranking the earlier diagnosis

The pose-snapping measured in §3 (0.47 studs average residual) is **real but was never the main
cause** — it is present in slide mode too, and slide mode feels perfect. Network ownership, options A
and B, and the whole Phase 2 redesign are therefore **not required to fix the shake**. They remain
open questions about *input latency* only, which is a separate and much milder complaint.

### ⚠️ The game is currently in a DIAGNOSTIC state, not a fixed one

`DEV_BUOYANCY_SLIDE` is **not a fix and must not ship**. It replaces real buoyancy with server-authored
kinematic control of the vertical axis, which discards ramp jumps, wave response and any future water
dynamics. It only proved where the fault is. The real fix is to make the spring itself stable under
way — see the follow-up job.

**Finding 2 matters a great deal**, because `BoatCamera` had *already* been patched for this exact
complaint. Its own header records the earlier report — *"when i drive i have feeling that screen like
cant keep up and like shakes"* — and the response was to smooth the aim point and forward vector so
"nothing the camera uses is a raw replicated value". That patch was **incomplete**: `desired` is still
built from the raw `hull.Position` each frame and only then eased, so the camera is a smoothed follow
of a jittery point rather than a smooth camera.

⚠️ Also note that comment asserts the hull's replicated CFrame "steps at roughly 20 Hz". Measurement 4
disproves that — the pose changes on **97% of frames (~56 Hz)**. The camera's tuning was chosen against
a wrong model of the problem, which is a good reason to re-derive it rather than nudge the constants.

**So the remaining ~50% is split between the camera's residual follow error and the hull's own rendered
pose.** Bisect 3 tests whether the buoyancy spring contributes to the latter.

## Options

### A. Move the force loop to the owner, and give the driver ownership

The standard answer for a Roblox vehicle that must feel good. The driver's client simulates the boat
locally: zero input latency, zero reconciliation, nothing to snap. The server validates rather than
drives.

- **Fixes:** the snapping and the input latency, for the driver — the person judging "feel".
- **Cost:** the buoyancy/thrust/drag/orientation loop moves client-side, which is a real redesign of
  `BoatServer`, not a toggle. Needs server-side sanity checks (position/speed bounds) because the
  client now authors the boat's motion — and GAME.md calls out that real money rides on this game's
  authority model.
- **Caveat:** passengers still receive a replicated body and will still see some reconciliation. It is
  the driver's experience that improves most.
- **Mobile:** local simulation runs at the phone's frame rate. Better than today (a phone currently
  reconciles the same snapshots with fewer frames to hide them), but worth measuring.

### B. Remove the *reason* for server ownership, then hand it over

The elegant version of A. The server loop exists mainly to compute buoyancy. If flotation becomes
**constraint-driven** — no per-frame script reading the body's state — then nothing needs the
un-lagged view and ownership can move to the driver with no feedback loop to re-create.

The hull is already `density 0.7` in terrain water with `EnableFluidForces = true`, so the engine can
float it natively; damping would come from a constraint rather than a scripted spring.

- **Fixes:** same as A, with a smaller client-side surface and less to get wrong.
- **Cost:** the `roblox-physics` skill explicitly warns *"Don't rely on terrain-water auto-buoyancy
  alone (density<1 floats, but it's hard to tune/keep stable)"*. This option is the most attractive on
  paper and the one most likely to fight us in practice. It needs a prototype before it is trusted.

### C. Keep server ownership; smooth the pose on the client

Render the boat through a client-side visual that follows the replicated pose with critical damping,
so snapshots stop being visible directly.

- **Fixes:** the visible snapping only.
- **Does not fix:** input latency, and it does not help a player *standing on the deck*, who collides
  with the real hull rather than the smoothed visual — so the rider experience is unchanged.
- **Cheapest and least risky.** A stopgap, not an answer.

### D. Weld the gun and searchlight into the assembly *(new — likely the actual fix)*

Added after the user narrowed the report to *"only light and gun jiggles"*. Stop driving those parts
by server CFrame writes and let them ride the boat assembly natively, the way `GunBase` and `GunSeat`
already do (measured offset drift: exactly 0.0000). Aim would come from a constraint — a
`HingeConstraint` servo for the turret yaw/pitch — rather than a per-frame `barrel.CFrame =` write, so
the barrel is part of the physics body and replicates with it.

- **Fixes:** the jiggle the user actually reports, and `todo/0047`, together.
- **Cost:** far smaller than A or B. No ownership change, no buoyancy redesign, no new exploit surface.
- **Risk:** turret aim becomes a constraint rather than a direct CFrame set, which changes how
  `GunServer` drives it; and an anchored part becoming part of the assembly alters the assembly's mass
  properties unless kept `Massless`.
- ⚠️ **Verify first.** The mechanism is confirmed but the magnitude at rest is only 0.002 studs. Take
  the under-throttle position+rotation measurement before committing.

### Recommendation — FINAL

**There are TWO independent faults, both real, both only visible under power. Fix both: D first
because it is trivial, then A/B because it is the one the user objects to.**

The user's reports and the measurements agree once they are matched by condition, which is what took
this investigation three passes to get right:

| Condition | User report | Measurement |
| --- | --- | --- |
| At rest / floating | "as a passenger it feels smooth" | hull Y 0.000; anchored-part drift 0.002 studs |
| Under throttle | **"whole boat was just shaking, i do not like that"** | hull rendered residual **avg 0.47 / max 7.13 studs** |
| Under throttle | "only light and gun jiggles" | anchored-part drift **avg 1.14 / max 6.38 studs** |

**Fault 1 — the hull's rendered pose (the main complaint).** Proven in measurement 3: at cruise the
client renders the hull half a frame's travel away from its own velocity prediction on average, and up
to seven frames' worth at worst, with yaw snaps of 3.96°/frame against a physical maximum of 46°/s.
The physics is smooth (measurement 2); it is the *rendering of a server-owned body* that is not.
Requires **A or B**.

**Fault 2 — the gun and searchlight.** Proven in measurement 8: anchored parts driven by server CFrame
writes drift up to 6.38 studs from a hull whose welded parts hold exactly 0.0000. Requires **D**.

**Do not do C.** It smooths the hull's visual but leaves a player standing on the deck colliding with
the real, unsmoothed hull — and it fixes neither fault at the source.

⚠️ **The A/B caution stands and is the most important line in this document:** do not change network
ownership without also moving the force loop off the server. A server loop computing buoyancy from a
client-owned body's lagged state is the Job 003 bounce, and it will come straight back.

### A note on how this investigation went wrong twice

Recorded because the same traps are waiting for the next person:

1. **"The pose updated on 97% of frames" was read as "replication is healthy."** Updating every frame
   and updating to the *correct* value are different questions. Only a residual against the body's own
   velocity separates them.
2. **A subjective report was applied outside the condition it was gathered in.** "Smooth as a
   passenger" came from a floating boat and was used to discount a fault that only appears at 52
   studs/s. Always record the condition alongside the impression.

---

## 6. The passenger test — driver vs passenger

**User report, 2026-08-16, asked directly and confirmed twice: "as a passenger it feels smooth."**
Not smoother — smooth. That is the most decisive datum in this investigation, and it re-ranks
everything above.

Server ownership costs two different things, and the two roles pay differently:

| | sees pose snapping | feels input latency | reported feel |
| --- | --- | --- | --- |
| Passenger | yes | no | **smooth** |
| Driver | yes | yes | glitchy, vibrating, clumsy |

⚠️ **BUT THE PASSENGER TEST WAS NOT RUN UNDER THROTTLE, AND THAT LIMITS WHAT IT PROVES.** The user
plays solo: to stand on the deck they had to leave the driver's seat, so "passenger feels smooth" was
observed on a **floating or coasting** boat, never at cruise. It therefore does **not** clear the
snapping measured at 52 studs/s. The user flagged this themselves — *"maybe passenger will feel it
with throttle, I had to jump out of seat"* — and they are right.

What the passenger report does establish: **a stationary or slow boat feels fine.** Everything
objectionable happens under power.

**The user then narrowed it much further: "only light and gun jiggles."** Not the hull — the mounted
gun and the searchlight. Those are exactly the three anchored parts found earlier (`GunBarrel`,
`SearchlightHead`, `Skin_searchlightHead`), which sit *outside* the 61-part assembly and are driven by
a server-side CFrame write every Heartbeat while the hull replicates as an interpolated physics body.
That is `todo/0047`'s mechanism, and it may be the whole of the visible complaint.

### 7. Anchored-part drift, measured while floating

```
75 frames over 5s, boat stationary (hull Y peak-to-peak 0.000)

part              anchored   movement relative to the hull
GunBarrel         true       avg 0.0022 / max 0.0101 studs
SearchlightHead   true       avg 0.0010 / max 0.0046 studs
GunBase           false      avg 0.0000 / max 0.0001 studs
GunSeat           false      avg 0.0000 / max 0.0001 studs
```

The mechanism is **confirmed** — the anchored parts drift ~20× more than the welded ones, which hold
a mathematically constant offset. But at rest the magnitude is 0.002 studs: invisible. So this
measurement proves the *pathway* exists without yet proving it is the visible fault.

### 8. Anchored-part drift **under throttle** — the fault, quantified

Taken riding straight, so turning cannot account for it (max hull yaw change 1.089°/frame):

```
341 frames over 6s (57 fps)   speed avg 53.3 studs/s (range 0.5)

part              anchored   POSITION drift                    ROTATION drift
GunBarrel         true       avg 1.1427 / max 6.0795 studs     avg 0.231 / max 4.855 deg
SearchlightHead   true       avg 1.1538 / max 6.3765 studs     avg 0.231 / max 4.855 deg
GunBase           false      avg 0.0000 / max 0.0002 studs     avg 0.000 / max 0.000 deg
GunSeat           false      avg 0.0000 / max 0.0001 studs     avg 0.000 / max 0.000 deg
```

**This is the visible fault, and it is now unambiguous.** The anchored parts wander over a stud on
average and up to 6.4 studs — on a barrel roughly 8 studs long — while the welded parts hold a
mathematically perfect zero offset. Against the same measurement at rest (0.0022 studs), being under
power makes it **~500× worse**, which is precisely the reported "jiggles while riding, snaps back when
stopped".

The magnitude identifies the mechanism exactly: at 53.3 studs/s and 57 fps the boat covers 0.93 studs
per frame, and the average drift is 1.14 studs — **almost exactly one frame of travel.** The parts are
being placed from a hull pose one step out of date with the one the client renders.

**Conclusion: the hull is not the problem. Two anchored parts are.**

⚠️ **The instrumented rider test was inconclusive and should not be quoted.** Sampling the player's
position in the hull's frame while standing produced 0.245 studs/frame of movement, but the metric
cannot distinguish replication jitter from a character genuinely sliding on an accelerating deck, and
the large x/y/z spreads (0.33 / 2.43 / 4.10) came from 108 clean frames scattered across 25 s in
*different standing spots* rather than from vibration. A first attempt was also contaminated by the
player walking (movement input averaged 0.562). Rebuild it as a fixed-spot, fixed-heading capture if
the question ever needs a number; for now the subjective report is the better evidence.

## Still to check before implementing
- Whether `EnableFluidForces` should be disabled on the hull, measured rather than assumed.
- A mobile capture, since the fix must hold on a phone.

## Related

`todo/0047` — the turret and searchlight lag is the **same fault seen from another angle**: anchored
parts whose CFrame is written server-side each frame, replicating as discrete writes alongside an
interpolated hull. Whatever is decided here should resolve that too, and it was deferred from Job #086
for exactly this reason.
