# Job #072: Move the run start to the hand-built SpawnBase

**Project**: `roblox.jungle`
**Created**: 2026-08-02
**Status**: Requirements Gathering — **plan below, awaiting go-ahead**

## What you asked for

> *"Because we created starting place we need to move where we start. I added helper objects where boat
> should spawn and where plane flies to crash. Also players must wake up at spawn point somewhere. So
> this will be our spawn base. Plane must fly in from direction I added. As you can see we have crashed
> plane at the land, so I say we hide it, when we fall we show it and let's add particles with fire and
> smoke around plane."*
> …and: *"for flying plane we use the same plane model."*

---

# Part 1 — What is there now

## 1.1 Your helper objects (read live)

| Object | Position | Role |
|---|---|---|
| `SpawnBase.SpawnLocation` | **−266, 18, −312** | players wake here |
| `SpawnBase.Dock.BoatPlace` | **−162, 12, −270** | boat spawn — sits exactly on `WATER_Y = 12` ✅ |
| `SpawnBase.Dock.PlacePlace` | **−760, 258, −238** | plane fly-in start (high, far west) |
| `SpawnBase.Plane` | **−303, 27, −288**, 88 × 34 × 94 | the crashed wreck |
| `SpawnBase.Dock.Dock` | −173, 11, −303 | the jetty |

**Flight vector**: from `PlacePlace` to the wreck is **+457 X, −231 Y, −50 Z** — the plane enters from
the west at 258 studs up and descends ~231 studs eastward into the crash site. Good cinematic line.

*(`PlacePlace` reads like a typo for `PlanePlace`; I'll bind to the name as-is and note it.)*

## 1.2 The system it has to replace

`StagingServer` currently **generates a greybox crash-site hub procedurally** at `HUB_Z = Z_START + 40`
(≈ world Z 40), derived from `RiverData.centerlineX/widthAt`. It builds a platform + a `PlaneWreck`
greybox, computes the boat's moored position, and publishes **`Workspace.HubSpawn`**.

Its own header already called this temporary:

> *"the greybox hub here is a PLACEHOLDER — the human will hand-build the real crash-site hub + startup
> river; a later job points the procedural generator at HANDOFF_Z."*

**Three systems consume `HubSpawn`**, which is the seam to re-point:

| Consumer | Use |
|---|---|
| `PlayerCombat` | places players at the hub before the run starts |
| `PlaneServer` | flies the intro plane in relative to it, and drops the crew there on impact |
| `StartShopServer` | positions the Robux kiosk |

`BoatServer` is separate: `START = RiverData.positionAt(Z_START + 40) + (0,2,0)` — mid-channel at Z 40.

`PlaneServer` today builds a **greybox plane** from parts and flies it on offsets from `HubSpawn`
(`+240 Y, −360 Z` → `+205, −70` → `+32, +40`), then deletes it and leaves the hub's greybox wreck.

`IntroCameraClient` already rides `Workspace.IntroPlane` and has a `IntroWake` ground shot — **no camera
work needed**, it follows whatever the plane model is.

---

# Part 2 — The plan

## Step 1 — `StagingServer`: bind to SpawnBase instead of generating

Find the helpers by name; **stop building the greybox platform and `PlaneWreck`**. Publish
`HubSpawn` = `SpawnLocation` position. Everything downstream then follows for free.

**Fail loudly, don't fall back.** If `SpawnBase` or a helper is missing, `warn` and halt staging rather
than silently generating a greybox hub 300 studs away in the river — a silent fallback here would be
very confusing to debug.

## Step 2 — Boat spawns at `BoatPlace`

`BoatServer.START` → `Dock.BoatPlace` position. It already sits on the waterline, so no Y maths.
`StagingServer`'s reel/mooring logic (which computes a docked X from the channel edge) must also read
the dock instead of the procedural bank.

## Step 3 — `PlaneServer`: fly the real plane model

- **Clone `SpawnBase.Plane`** for the flight instead of building a greybox. Anchor it, make every part
  `CanCollide = false`, and add up to 6 seats so the crew rides it (the current seat logic is reusable).
- Path: **`PlacePlace` → hover → descent → wreck position**, using the real world points rather than
  offsets from `HubSpawn`, and orienting along the flight vector so the nose leads.
- On impact: destroy the clone, **reveal the static wreck**, place the crew at `SpawnLocation`.

## Step 4 — Hide the wreck until the crash

The wreck is a Model of MeshParts. Hiding it means **`Transparency = 1` + `CanCollide = false` on every
descendant**, restoring the original values on reveal — *not* re-parenting to `ServerStorage`, which
would break anything holding a reference and lose the exact placement.

⚠️ **Store each part's original transparency**, since the plane's meshes may not all be 0.

## Step 5 — Fire and smoke VFX at the wreck

On reveal: `Fire` + `Smoke` + an ember `ParticleEmitter` + a warm flickering `PointLight`, attached to a
few points along the fuselage/engines. Mobile budget per STYLEGUIDE §8 — a handful of emitters, not one
per part.

The lobby's campfire VFX (`ASSETS.md` §1.10) is the closest existing reference for the look.

---

# Part 3 — Things I need to flag before building

## 🔴 The start is now at NEGATIVE Z, and distance maths assumes Z ≥ 0

`RiverData.Z_START = 0` and `worldToDistance(z)` measures from there; `RiverBootstrap` clamps with
`math.max(0, …)`. With the boat starting at **Z −270**, `BoatDistance` reads **0 until the boat crosses
Z 0** — the first ~270 studs of travel don't count.

That is arguably *correct* (the run "begins" at the junction where the generated river starts) but it
is a behaviour change worth agreeing rather than discovering later. `RunServer` wins at 18000.

## 🟠 The old hub is 300+ studs away, inside the generated river

`HUB_Z = 40` sits in generator-owned territory. Once staging stops building there, nothing should
remain — but the greybox platform/wreck it used to create must actually stop being built, or there will
be a stray platform in the river at Z 40.

## 🟠 `StartShopServer` will move with `HubSpawn`

The Robux kiosk follows the hub attribute, so it lands at the new spawn base automatically. Worth a
look to check it doesn't end up inside your plane or the sandbag wall.

## Decisions (2026-08-02)

| # | Decision |
|---|---|
| 1 | **The crew rides the plane down** and wakes at `SpawnLocation`. Keeps the existing force-seat logic — the crash happens *to* the player, which is the stronger cold-open. |
| 2 | **10 s cruise + 9 s descent.** Only the descent is stretched, so the ~900-stud approach from `PlacePlace` reads as a glide (~100 studs/s) rather than a drop, without adding much to the pre-run wait. |
| 3 | **Burn hard, then settle.** Full fire + smoke + embers for ~45 s after impact, then flames fade and a smoke column remains — dramatic when players are looking at it, cheap for the rest of the run, and the smoke still marks the camp on the horizon. |
| 4 | **Distance keeps measuring from Z 0** — the counter stays at 0 while the boat is in the start bay and begins at the junction. No code change; `END_DISTANCE = 18000` keeps its meaning, and the zone boundaries + Gold checkpoints at 25/50/75% stay as tuned. The ~270 studs in camp are the intro, not the run. |
| 5 | **Build step at a time**, describing each before implementing and verifying in Play before moving on. |

---

# Part 4 — SOUND SHOPPING LIST (user sources via Pixabay, GROUND-RULES §4)

Ordered by when it plays. **2D** = non-positional (heard inside the cabin / in your head);
**positional** = attached to the plane or wreck so it moves and falls off with distance.

## ✅ ALL SOURCED + UPLOADED by the user, 2026-08-02 — registered in `audio.md`

| Role | Name | rbxassetid |
|---|---|---|
| engine drone (2D loop) | `plane_flying` | `131906456545456` |
| stall (2D one-shot) | `engine_fail` | `109868059978369` |
| alarm (2D short loop) | `stall_alarm` | `112730854260419` |
| dive rush (2D loop, fade in) | `wind_rush` | `96421007219531` |
| 🔴 impact (2D one-shot) | `crash_sound` | `107234930559671` |
| debris (positional @ wreck) | `metal_debris` | `139877854727588` |
| ear ringing (2D, fading) | `ear_ringing` | `134266191078049` |
| fire (positional @ wreck, loop) | `fire_sound` | `99475771894138` |

Only the optional #9 (distant fly-over) was skipped. **No asset id goes in a script** — these resolve
through a lookup table the way `Theme.sound` does in the lobby.

*On "we had fire already": we have `crackle-campfire` (`113774133604878`, live in the lobby), but it is
a small domestic fire and reads far too thin for a burning aircraft. Keep it as a **layer underneath**
`fire_sound` for close-up crackle rather than a replacement.*

### Original shopping list (kept for reference)

| # | Sound | Moment | Type | Length | Notes |
|---|---|---|---|---|---|
| 1 | **Prop engine drone — loop** | whole cruise, inside the cabin | 2D loop | 5–15 s seamless | The bed the whole intro sits on. Wants a *heavy piston/prop* drone, not a jet. Must loop without a click |
| 2 | **Engine sputter / stall** | the moment it goes wrong | 2D one-shot | 2–4 s | The story beat. Coughing, misfiring, losing power — cues the descent |
| 3 | **Cockpit warning alarm** | from stall until impact | 2D short loop | 1–2 s | Repeating tone/buzzer. Keep it quiet under the engine, or it grates |
| 4 | **Wind rush / dive** | during the 9 s descent | 2D loop, volume rising | 4–10 s | Sells speed. Fade it *in* across the descent rather than playing flat |
| 5 | **🔴 CRASH IMPACT** | the hit | 2D one-shot | 2–5 s | The single most important one. Big metal impact + tearing + debris. Everything cuts to black on this |
| 6 | **Debris / metal settling** | ~1–2 s after impact | positional @ wreck | 3–6 s | Creaking, groaning, small pieces falling. Sells the aftermath |
| 7 | **Ear ringing (tinnitus)** | as you wake | 2D one-shot, fading | 6–12 s | High thin tone fading out. Cheap and extremely effective for a crash wake-up — strongly recommend |
| 8 | **Large fire — loop** | burning wreck, first ~45 s | positional @ wreck | 5–15 s seamless | Bigger and rougher than a campfire. See "already own" below |
| 9 | **Distant plane pass** *(optional)* | before it appears | 2D one-shot | 4–8 s | Foreshadows the plane before it's visible over the ridge |

## Already owned — do not re-source

| Have | Where | Use for |
|---|---|---|
| `crackle-campfire` `113774133604878` | registry `audio.md` (wired in the lobby) | usable as a **secondary layer** under #8 — but too small on its own for a burning aircraft |
| `wind-breeze` `93331028777865` | registry `audio.md` | a bed layer, **not** the dive rush (#4) — it's a gentle ambient loop |
| `boat_on_fire.mp3` | `assets/Objects/Boat/Sounds/` | ⚠️ **check this one first** — it may cover #8 outright. Local mp3, not yet uploaded |
| `boat_destroyed.mp3` | `assets/Objects/Boat/Sounds/` | ⚠️ possible stand-in for #5 — audition before sourcing new |
| `metal_hit_1_sec.mp3` | `assets/Objects/Boat/Sounds/` | possible layer for #5/#6 |

**Priority if the list is too long:** #5 (impact), #1 (engine loop), #8 (fire) carry the whole scene.
#7 (ear ringing) is the cheapest big win. #3 and #9 are polish.

**Format:** mp3, upload in Studio → Asset Manager → Audio, then hand over the IDs. They go to registry
[`audio.md`](../../roblox.workspace/Assets/registry/audio.md) and are wired through `Theme.sound`-style
lookup — **no asset id written into a script**.

---

# Part 6 — Build log

## ✅ Step 1 — `StagingServer` bound to SpawnBase

Greybox hub generation removed (`HubPlatform`, `PlaneWreck`, `Jetty` all gone). `HubSpawn` now published
from `SpawnLocation`; mooring geometry derived from `Dock.BoatPlace` and the dock's own facing rather
than an assumed +X bank. **Halts loudly** if a helper is missing instead of regenerating a hub 300 studs
away in the river.

Verified in Play: `HubSpawn = −265, 21.5, −311`; no greybox left. *(The winch this step built was later
removed entirely — see "The boat is the marker" below.)*

## ✅ Step 2 — boat spawns at the dock

`BoatServer.START` reads `Dock.BoatPlace`. Verified: hull at −166, 13, −270, **4 studs** from the marker,
floating, `Tied = true`. Removes the ~19 s self-sail from Z 40 that step 1 alone would have left.

Unlike staging, this one **falls back** to the old mid-channel spawn if the helper is missing — a boat in
the wrong place is recoverable, a run with no boat is not.

## ✅ Kiosk fix

`StartShopServer` used a fixed `+Z` offset from the hub and so landed **inside the plane wreck**. It now
derives the offset direction *away from the wreck*, so it stays clear if either is moved later.
Verified: −255, 20, −318, outside the plane's bounds, touching nothing.

## ✅ Steps 3–5 — the crash cold open

`PlaneServer` rewritten: clones `SpawnBase.Plane` and flies it `PlacePlace → wreck` (513 studs, 26.4°
descent), 10 s cruise + 9 s dive, with all 8 sounds. Impact fades to black, destroys the clone, reveals
the real wreck, and lights it up.

### 🔴 The orientation bug — and why the first fix was wrong

The user spotted it three times running: *"we flied wrong angle, like sideways"*, then *"plane was
already nose down"*, then *"it was flying wrong, then started saund, then started dive, and same wrong
position."* That last one was the key: the **sequence** was right, so the attitude was wrong for the
whole cold open, not just the dive.

**The first fix (`MESH_ROLL = −90°`) treated a symptom.** It was found by photographing clones from
*behind*, down the flight line — the one angle where pitch is nearly invisible. It made the wings look
level in that shot without ever putting the nose where it belonged.

**The measured cause.** The mesh does not use the standard Roblox axes: its nose is local **+X**, not
−Z. Proof, from a side-on shot against a neon horizon bar (the angle the first pass never took):

- posed with plain `CFrame.lookAt` and the −90° roll, the plane hangs **nose straight down**
- `flatDir:Dot(cf.RightVector)` returns **1.000** — the nose is `+X`, unambiguously

**The fix is one CFrame, and where it goes matters more than what it is:**

```lua
local MESH_FIX = CFrame.Angles(math.rad(90), 0, 0) * CFrame.Angles(0, 0, math.rad(-90))
lookAt(...) * CFrame.Angles(pitch, 0, roll) * MESH_FIX   -- ✅ pitch/roll act in the FLIGHT frame
lookAt(...) * CFrame.Angles(pitch, 0, roll + MESH_ROLL)  -- ❌ roll then swings the NOSE, not the wings
```

With the nose on local `+X`, rotating about local Z moves the nose — so folding the correction into the
roll term (what the first pass did) corrupted every banked frame. `MESH_FIX` must be **innermost**.

Verified at (0, 0), (0, +25°) and (−20°, +15°), photographed side-on against the horizon bar *and* from
behind: level is level, bank is bank, and a **negative** pitch is nose-down. Then confirmed in Play.

**Knock-on: the chase camera.** `IntroCameraClient` derived "forward" from `GetPivot().LookVector`. With
`MESH_FIX` applied that vector points straight **up**, so flattening it yields zero and the shot
collapses. The server now publishes `Workspace.IntroPlaneDir` — one authority for the heading, and no
baked-axis knowledge duplicated in the client.

*Lesson for the next mesh:* measure the model's axes before posing it, and photograph from a view where
the error is visible. A shot from behind cannot falsify a pitch error.

### 🔴 The hidden wreck kept its collision

The analyzer flagged
`d.CanCollide = hidden and false or o.c` as always taking the second branch — an and-or can never yield
`false`. Players would have walked into an invisible plane. Replaced with if-expressions.

### 🟠 Two presentation bugs the user caught in playback

**World billboards showed during the cold open.** *"why these labels visible? Medic etc?"* The MEDIC
crate tag and the ROBUX SHOP kiosk tag are `AlwaysOnTop = true`, so they rendered **through** the terrain
and the fuselage while the crew was still in the air. `IntroHudGate` only swept **ScreenGuis in
PlayerGui**; these are `BillboardGui`s in Workspace, so nothing touched them. The gate now also hides
world billboards — one initial scan plus a `DescendantAdded` hook (both servers build theirs at start-up,
which can land after the gate begins), restoring only the ones it disabled. Client-local, so it never
disturbs the server copies or other players. A per-frame `Workspace:GetDescendants()` sweep was the
obvious alternative and is far too expensive for a whole game world.

**The engine droned over the loading screen.** *"plane sound started to play through loading screen."*
The engine `Sound` was played where the plane is *built* — script start — but the plane then hovers
behind the loading mask for several seconds. It now starts at the **same gate the cruise does**, faded in
over 1.2 s so it reads as the cabin coming up around you rather than snapping on.

### 🔴 The crew rode the intro sitting outside the plane

*"all graat, excep plyers sitting outside and wrong angle."* Same root cause as the flight attitude, one
layer deeper: the seat rig was built from `flyer:GetPivot()`, which carries `MESH_FIX`, so it was working
in the **mesh** frame where `Y` points out of the left wing and `Z` points at the sky.

Measured, level, in each frame:

| | X | Y | Z |
|---|---|---|---|
| model `GetBoundingBox()` (what the seat code read) | 88.2 | 95.0 | 34.3 |
| **body frame** (what it meant) | 95.0 width | 34.3 height | **88.2 length** |

So the three "rows" used `size.Z * 0.12` — 12% of the **height** — and spread the crew 4 studs apart
*vertically*; the two "columns" (`dx = ±2.2`) spread them fore-and-aft; and the `−1.5` "down" offset
pushed everyone **sideways out through the wing root**. Hence passengers in mid-air, on their side.

Fix: added an explicit `bodyCF()` (standard axes — nose −Z, up +Y, right +X) and built the seats from
`flyer:GetPivot() * MESH_FIX:Inverse()`. Rows now run along body Z at −11 / 0 / +11, columns straddle the
centreline at ±2.2, all at `SEAT_Y = −3` so the fuselage shell hides them.

Verified live, sampled mid-cruise from inside the running server:

```
PlaneSeat1 body(x -2.2, y -3.0, z -11.0) occupant=johnygorsky10
PLAYER root body(x -2.2, y -1.3, z -11.0) Sit=true upright=1.00 facing=-1.00
```

`upright = 1.00` (character up ≡ aircraft up) and `facing = −1.00` (nose-forward) — no tilt, and the root
sits inside the fuselage (body extents are x ±47.5, y −17.2…+17.1, z −44.2…+44.1). Chase-cam screenshot
confirms nobody is visible outside the aircraft.

**The rule this keeps re-teaching:** with `MESH_FIX` in the pivot, *nothing* may reason about the
aircraft from `flyer:GetPivot()` or `GetBoundingBox()` — go through `bodyCF()`.

### 🔴 The wreck never caught fire — two bugs in one block

*"no smoke and fire yet, will it be added now?"* The `Fire`/`Smoke` objects existed all along (an earlier
check counted 3 + 3), they were just nowhere near the crash. Measured live: **wreck at −303, 28, −288 ·
emitters at −512, 249, −593** — 200 studs away and 220 studs in the air.

**1. Parenting order.** The docs confirm `Fire` renders on a `BasePart` *or* an `Attachment`, so the
parent type was never the problem. The order was:

```lua
a.WorldPosition = wreckCF * off   -- Attachment has NO parent yet -> stored as a LOCAL position
a.Parent = anchor                 -- now reinterpreted as an offset from anchor.CFrame
```

Parent **first**, then set `WorldPosition`.

**2. The offsets were meaningless anyway.** They came from `GetBoundingBox()` in the wreck's own frame,
but the wreck lies nose-down with the tail in the air, so its oriented box (88.2 × 34.3 × 95.0) says
nothing about how it occupies the world — the real AABB is X 89 · Y **85** · Z 95, spanning Y −15 to
Y 70. `GetExtentsSize()` is no help: it returned the *oriented* size (34.3 tall) too. The world AABB is
now measured from the part corners and the flames placed in world space, near the sand line so they
start outside the hull instead of burning invisibly inside an opaque mesh.

Verified live — emitters now 4 / 19 / 19 studs from the wreck, and the screenshot shows flame, a smoke
plume and firelight on the hull.

### 🔴 Players could bail out of the plane mid-flight

*"players can jump out of plane while flying, disable input till we land."* Jump unseats a character, so
the crew could step out at altitude. Locked from both ends:

- **Server** (`lockPassenger`) — `SetStateEnabled(Jumping, false)` plus `JumpHeight/JumpPower/WalkSpeed`
  zeroed. The state toggle is the part that matters: seat-exit is driven by the jump **input**, not by
  the jump force, so zeroing `JumpPower` alone does *not* stop it. A `Humanoid.Seated` watcher re-seats
  anyone who comes loose while `IntroActive` and not yet `IntroWake`.
- **Client** (`IntroInputLock.local.luau`, new) — sinks `Enum.PlayerActions.CharacterJump` and the four
  movement actions at High priority. Using `PlayerActions` rather than raw `KeyCode`s means it also
  covers gamepad and the mobile touch buttons.

Both release at the wake-up. Verified live: in flight `Sit=true, jumpStateEnabled=false`, and **forcing
`Humanoid.Jump = true` did not unseat**. After the wake: `WalkSpeed=16, JumpHeight=7.2,
jumpStateEnabled=true, Sit=false` — controls fully handed back.

### 🟢 Confirmed intentional — red patch at the crash site

The glowing red patch on the sand is **terrain painted `CrackedLava`** (19 voxels). Confirmed by the user
as deliberate scorch under the wreck — leave it.

### 🔴 The boat hung in the air, and the tow went with the fix

*"see how it floats?"* — the moored boat sat with its keel **above** the waterline. It read as a buoyancy
bug and was not one.

**The mooring rope was holding it up.** `RopeConstraint Length=11.46` against a live distance of `11.48`
— taut. The winch post sat at Y 17.2, ~5 studs above the water, and the rope had been cut from the hull's
**build-time** position (`WATER_Y + 2`). The moment buoyancy tried to lower the boat the distance to the
winch grew past the rope length, so the rope suspended it like a crane. Two false leads on the way:
`BoatPlace` looked like a shelf under the hull (a raycast hits it because rays use `CanQuery`, not
`CanCollide` — it was already non-collidable), and a first fix measuring to the *floating* position was
still wrong because staging then drives the boat out to `startPos = dockedPos + awayDir * REEL_OFFSET`,
away from the winch, re-shortening the rope by ~3 studs.

**The user's call replaced the whole mechanism** — *"you place boat exactly where that boat place is,
also you follow rotation of that object… remove tow to pier, because no towing to pier is required."*

- `BoatServer` takes `BoatPlace`'s **yaw** as well as its position (`START_CF`), yaw only — never the
  marker's pitch/roll, or the hull would start listing and `AlignOrientation` would fight it upright.
  The old heading came from `CFrame.lookAt(START, START + downstream(START.Z))`, which is only right out
  on the generated river; at the sculpted spawn base the tangent is a flat +Z, which parked the boat
  crosswise across a pier that runs at −47°.
- `StagingServer`: `REEL_OFFSET` gone (`startPos = dockedPos`), winch post gone, rope gone, `reel()` /
  `refreshRope()` / `mooringLength()` / the `docked` stage all gone. The untie prompt moved onto the
  hull and goes straight to **"Untie rope — START"**; `UntieButton` still covers the seated driver.
  Dead code removed with it: the `block()` helper and the `dockModel` lookup.
- `StagingHint` banner → *"Board the boat & untie to START"*.

Verified live against the marker transform the user had just set:

```
BoatPlace  -149.00, -269.84  yaw -115.8
hull       -149.00, -269.84  yaw -115.8
OFFSET      0.00 studs,  yaw diff 0.0 deg
keel Y 10.48 -> -1.52 vs water   (sitting IN the water)
ropes on boat = 0 · winch post = gone · StagingArea children = 0
```

**`Dock.BoatPlace` is now the single control** — drag or rotate it in the editor and the moored boat
follows. Nothing computes a berth.

### 🟡 Open — the crash lighting may be too hot

Three `PointLight`s at `Brightness 4 · Range 42` overlap on the wreck. In the verification screenshot the
plane's green camo reads as bright yellow and the sand around it is blown out. It plainly says "on fire",
but it may be worth dropping to ~2 brightness or two lights. Not changed — the user has not seen it yet.

### Verified in Play (post-impact state)

- wreck revealed — transparency **0**, `CanCollide true`
- **3 Fire · 3 Smoke · 3 PointLight · 2 Sound** attached
- burn→settle worked: after 45 s the fire is `enabled false`, lights at 0, smoke settled to opacity 0.22,
  `fire_sound` ducked to 0.12 — the smoke column still marks the camp
- crew woke at **−270, 22, −314** (SpawnLocation), walkSpeed restored
- flight orientation verified by placing a clone with the **shipped** `flightCF` and photographing it

## Checklist

- [x] Helper objects + current system read
- [x] Sounds sourced by the user (Part 4) — all 8, registered in `audio.md`
- [x] Staging bound to SpawnBase
- [x] Boat spawn moved
- [x] Intro flies the real plane model
- [x] Wreck hidden → revealed on impact
- [x] Fire + smoke VFX
- [x] Verified in Play
- [x] Flight attitude corrected (`MESH_FIX`) + chase camera repointed at `IntroPlaneDir`
- [x] World billboards hidden during the intro, restored after
- [x] Engine sound moved behind the loading gate
- [x] Seats rebuilt in the body frame — crew rides inside, upright, facing forward
- [x] User watched the cold open — *"all feel great"*
- [x] Crash fire + smoke actually land on the wreck (parenting order + world AABB)
- [x] Input locked in flight — crew can't jump out, controls returned at the wake
- [x] `CrackedLava` patch confirmed intentional scorch
- [x] Boat sits exactly on `Dock.BoatPlace` — position **and** rotation (0.00 studs / 0.0° offset)
- [x] Boat floats properly — the mooring rope, not buoyancy, was suspending it
- [x] Tow-to-pier removed — no winch, no rope, no reel; untie is one step on the hull
- [ ] User re-checks: engine-sound timing, seated crew, fire/smoke, in-flight input lock, boat mooring
- [ ] Decide whether the crash point-lights are too bright (3 × Brightness 4 · Range 42)
- [ ] Final summary + changelog
