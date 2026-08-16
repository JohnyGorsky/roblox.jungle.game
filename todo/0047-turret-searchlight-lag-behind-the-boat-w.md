# TODO 0047: Turret + searchlight lag behind the boat while moving, snap back when stopped

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-16 22:14:26

Reported 2026-08-16 playtest: the mounted gun and the searchlight appear detached / trailing while riding; they return to position the moment the boat stops.

ROOT CAUSE (verified): sync/ServerScriptService/Combat/GunServer.server.luau:74 makes the barrel `Anchored = true`, and :148 sets `barrel.CFrame` every Heartbeat ON THE SERVER from `hull.CFrame`.

The hull is SERVER-owned -- BoatServer.server.luau:268 calls `hull:SetNetworkOwner(nil)` and :284-300 re-asserts it every Heartbeat, deliberately (Job 003 review, 2026-07-18), because buoyancy is computed server-side. So the mismatch is NOT server staleness. It is that the two objects reach the viewer by two different routes:

  - the HULL is a replicated physics assembly, which every client SMOOTHS/INTERPOLATES between updates;
  - the BARREL is an anchored part whose CFrame arrives as discrete replicated writes, applied as-is.

While the boat moves, the interpolated hull and the stepped barrel drift apart on screen; when the boat stops, both converge on the same pose and the barrel snaps home. That is exactly the reported symptom.

(Earlier note in this file misread the Output line `Boat -> navy (1 parts, johnygorsky10) [pass ownership resolved]` as network ownership. It is BoatModules.server.luau:464 logging a GAME-PASS paint check. Corrected.)

The searchlight is the same shape of bug: BoatModules.server.luau:102 sweeps the beam from the boat's GunYaw attribute (GunServer:164 publishes it), also server-side.

FIX DIRECTION (not decided): drive the barrel from a physical constraint welded into the boat assembly instead of a server CFrame write, so it rides the assembly natively -- or move the visual pose to the client. Consult roblox-physics (network ownership / assemblies) before choosing. Compare the boat-rider carry rule already learned: rely on native assembly behaviour, never a manual per-frame follow.
