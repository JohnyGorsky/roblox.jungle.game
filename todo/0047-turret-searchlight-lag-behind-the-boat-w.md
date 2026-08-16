# TODO 0047: Turret + searchlight lag behind the boat while moving, snap back when stopped

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-16 22:14:26

Reported 2026-08-16 playtest: the mounted gun and the searchlight appear detached / trailing while riding; they return to position the moment the boat stops.

ROOT CAUSE (verified): sync/ServerScriptService/Combat/GunServer.server.luau:74 makes the barrel Anchored = true, and :148 sets barrel.CFrame every Heartbeat ON THE SERVER from hull.CFrame. But the hull is physics-driven and NETWORK-OWNED BY A CLIENT (the playtest Output line 'Boat -> navy (1 parts, johnygorsky10) [pass ownership resolved]' confirms it). So the server is deriving the barrel pose from its own LAGGED copy of the hull, then replicating that anchored CFrame back out. The faster the boat moves, the bigger the offset; at rest the hull converges and the barrel snaps home. Classic anchored-part-driven-from-a-client-owned-assembly mismatch.

The searchlight is the same shape of bug: BoatModules.server.luau:102 sweeps the beam from the boat's GunYaw attribute (GunServer:164 publishes it), also server-side.

FIX DIRECTION (not decided): drive the barrel from a physical constraint welded into the boat assembly instead of a server CFrame write, so it rides the assembly natively -- or move the visual pose to the client. Consult roblox-physics (network ownership / assemblies) before choosing. Compare the boat-rider carry rule already learned: rely on native assembly behaviour, never a manual per-frame follow.
