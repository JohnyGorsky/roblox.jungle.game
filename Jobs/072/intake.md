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

## Open questions

1. **Flight timing** — currently 10 s cruise + 5 s descent after the loading mask lifts. Keep, or make
   the approach longer now that it's a proper 900-stud descent?
2. **Does the crew ride the plane, or is the intro a fly-over they watch?** Current code force-seats
   everyone. Your `SpawnLocation` suggests they wake on the ground either way.
3. **Should the wreck burn forever, or fade out** after the first minute? Permanent fire is a constant
   particle cost on mobile.

## Checklist

- [x] Helper objects + current system read
- [ ] Plan agreed (Part 2) + open questions answered
- [ ] Staging bound to SpawnBase
- [ ] Boat spawn moved
- [ ] Intro flies the real plane model
- [ ] Wreck hidden → revealed on impact
- [ ] Fire + smoke VFX
- [ ] Verified in Play
- [ ] Final summary + changelog
