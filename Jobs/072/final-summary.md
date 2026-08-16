# Job #072 - Final summary

**Move the run start onto the hand-built SpawnBase.**

> WARNING: **Written retroactively on 2026-08-16** as part of Job #084's docs-debt sweep. The work
> shipped earlier; this summary is reconstructed from the intake and from the code as it stands today,
> so treat the *code* as authoritative where they disagree. The intake's checklist was never ticked
> and is stale.

## What shipped

`StagingServer` no longer generates a greybox crash-site hub. It binds to the hand-placed `SpawnBase`
helpers in the place file and publishes `Workspace.HubSpawn` from them, which is the seam the three
consumers already read - `PlayerCombat` (pre-run player placement), `PlaneServer` (intro fly-in and crew
drop) and `StartShopServer` (kiosk position). Re-pointing that one attribute moved all three.

Confirmed live in the console every run:

```
[Staging] bound to SpawnBase - wake at -266,21,-312 - boat docks at -149,-270
[Staging] crash-site hub + moored boat online (untie to start)
```

The greybox `HubPlatform`, `PlaneWreck` and `Jetty` are gone; `SpawnBase.Dock.Dock` is the real jetty and
`SpawnBase.Plane` the real wreck. The boat sits exactly where `BoatPlace` is, position **and** rotation -
drag or spin that marker in the editor and the moored boat follows with no code change.

## The one thing worth carrying forward

The mooring rewrite that came with this job is load-bearing, documented at `StagingServer:69-72` and
`:130-133`: the boat is moored **dynamically** with a plane-mode `LinearVelocity`, never anchored,
because anchoring an assembly and later unanchoring it with a client-owned player aboard makes the
physics explode - the old "boat disappears" bug. Job #084 hit the same trap in `DockServer` and had to
adopt this pattern; see that job's summary for the centre-of-mass caveat once the boat has modules.

## Not verified

The cinematic fly-in line (from `PlacePlace`, west, 258 studs up) has never been signed off on camera.
`PlacePlace` reads like a typo for `PlanePlace`; the code binds to the name as-is.
