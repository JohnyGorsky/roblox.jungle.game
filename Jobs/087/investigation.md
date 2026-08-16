# Job #087 — Boat ride quality: investigation notes

**Project**: `roblox.jungle`
**Status**: In progress — measured on the live Studio server 2026-08-16
**Deliverable**: diagnosis + options. No code changes until a direction is approved.

---

## Measurements taken (live game place, Studio server)

### At rest — the physics is clean

```
mass = 991          awakeParts = 60      physFPS = 59.9
networkOwner = nil (server)              Tied = false   Anchored = false
Y      peak-to-peak over 2s = 0.000 studs
velY   min -0.003  max 0.004             (numerical noise, not oscillation)
```

**The buoyancy spring is not the problem.** A mistuned spring-damper would show as a standing
oscillation in `Y` even at rest, and there is none — the hull is dead flat to three decimal places.

This is consistent with the code: `BoatServer.server.luau:316-318` applies the damping term
**outside** the up-only `math.max(spring, 0)` clamp, and the buoyancy cutoff is `WATER_Y + 12`, far
above any bob amplitude. Both of the buoyancy traps recorded in the `roblox-physics` skill (both
learned on this very boat) are already correctly handled. Ruled out.

### Configuration found

```
StreamingEnabled          = true
InterpolationThrottling   = Default
Gravity                   = 196.2
Hull  Size 14×3×32   density 0.70   AssemblyMass 991   EnableFluidForces = TRUE
Hull movers  VectorForce:Buoy, :Thrust, :Current, :Drag   AlignOrientation:Level
assembly parts = 61
anchored parts inside Boat = 3  { GunBarrel, SearchlightHead, Skin_searchlightHead }
```

### Still needed

A **moving** sample: client-rendered frame-to-frame displacement while the boat is under way, to
separate "the simulation is unsteady" from "the simulation is fine and the client is seeing it
badly". Attempted; timed out because the boat was never driven above 4 studs/s during the window.

---

## Candidate causes, ranked

### 1. Server ownership → the driver never simulates their own boat *(prime suspect)*

`BoatServer.server.luau:268` sets `hull:SetNetworkOwner(nil)`, and the Heartbeat loop at `:284-300`
**re-grabs** server ownership every frame whenever a client takes it. Confirmed live:
`networkOwner = nil`.

That was a deliberate, well-reasoned decision (Job 003 review, 2026-07-18) and the reasoning is
recorded in the `roblox-physics` skill as a verified Jungle lesson: buoyancy is computed in a server
loop, and **a server-computed force on a client-owned body is a delayed-feedback loop** — the spring
pumps energy and the boat bounces higher and higher. That is real and it must not be re-broken.

But it has a cost that was never priced in: the driver sees their own vehicle only through
replication. Every other smooth-driving Roblox vehicle hands network ownership to the driver so the
vehicle simulates locally at the client's frame rate with zero input latency. Server-owned means:

- **input latency** — throttle → server → force → physics → replicate back → render;
- **interpolation artefacts** — the hull's pose arrives in discrete updates and is smoothed by the
  engine, not simulated;
- **the rider mismatch** — the player's own character *is* client-owned and simulates locally, while
  the platform under their feet arrives interpolated. A locally-simulated character standing on a
  remotely-simulated platform is a classic source of foot jitter and micro-vibration.

The third point deserves emphasis because it matches the reported symptom ("it vibrates somehow")
better than input latency does, and it is invisible to any server-side measurement.

**The trade-off to resolve is not "which is better" but "how do we get local simulation without
re-creating the feedback loop".** The standard answer is to move the force computation to the owner:
if the driver owns the hull, the buoyancy/thrust/drag loop must run on the driver's client, with the
server validating rather than driving. That is a real redesign, not a toggle.

### 2. `InterpolationThrottling = Default` *(cheap to test, possibly significant)*

This property governs how aggressively the engine throttles the smoothing of replicated parts. Under
load it *reduces* interpolation quality — and because the boat is server-owned, the boat is precisely
a replicated part. `Disabled` forces full interpolation.

This does not fix input latency, and it is not a substitute for #1, but if the vibration is partly a
throttled-interpolation artefact it is a one-property change. Worth measuring before anything else
because it costs nothing to try.

### 3. `EnableFluidForces = true` on the hull *(likely contributor to "clumsy", not to "vibrates")*

The engine applies its own aerodynamic drag **and torque** to the hull, on top of the custom `Drag`
VectorForce at `:374`. On a 14×3×32 slab that is a substantial, orientation-dependent force the
tuning never accounted for — and because it produces torque as well as drag, it fights the
`AlignOrientation` during banked turns. Most vehicle recipes turn it off and do their own drag.

The custom drag is horizontal-only by design (`:374`, "Y left to buoyancy"); the engine's fluid force
is not, so it also injects vertical force the buoyancy spring then has to absorb.

### 4. Forces are applied in `Heartbeat` (post-simulation), not `PreSimulation`

`RunService.Heartbeat:Connect` at `:284` computes and writes every force **after** the frame's
physics step, so each force value is one frame stale relative to the step it affects. For a stiff
spring this adds phase lag. Worth checking against the current Creator Docs guidance on where vehicle
force updates belong — but it is a refinement, not the headline, and the at-rest measurement shows it
is not currently destabilising anything.

### 5. Ruled out

- **Buoyancy spring tuning** — 0.000 studs peak-to-peak at rest (see above).
- **Assembly splitting by anchored parts** — the three anchored parts (`GunBarrel`,
  `SearchlightHead`, `Skin_searchlightHead`) are *not* welded into the hull assembly, so they are not
  splitting it. They are independent CFrame-driven parts. That is a separate visual bug, `todo/0047`.
- **Physics throttling / step rate** — `physFPS = 59.9` with 60 awake parts; the simulation is not
  starved.

---

## Next steps

1. Capture the moving sample (needs the boat driven for ~10s).
2. Compare client-rendered displacement against server-reported velocity in the same window — this is
   the measurement that distinguishes cause #1 from cause #2.
3. Consult the Creator Docs on network ownership for driven vehicles and on `InterpolationThrottling`
   before proposing, per the job's method note.
4. Write the diagnosis + options for approval.
