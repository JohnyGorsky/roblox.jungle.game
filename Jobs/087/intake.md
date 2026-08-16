# Job #087: Boat ride quality: diagnose the vibration and clumsy feel

**Project**: `roblox.jungle`
**Created**: 2026-08-16 22:18:47
**Status**: Requirements Gathering (intake)

## Requirements / goal

UNDERSTAND-FIRST job (user direction 2026-08-16). Deliverable is a written diagnosis + options, NOT a code change. Nothing gets edited until the user approves a direction.

Problem: riding the boat glitches and vibrates; it does not feel smooth the way other Roblox games do, and it handles clumsily. Source: todo 0050.

Central question: NETWORK OWNERSHIP. BoatServer.server.luau:268 sets hull:SetNetworkOwner(nil) and the Heartbeat loop at :284-300 re-grabs server ownership every frame whenever a client takes it (Job 003 review, 2026-07-18: server-side buoyancy would bounce on lagged client positions, plus co-op exploit-resistance). The cost of that decision is that the driver never simulates their own boat -- they see it through replication + interpolation, which is the standard cause of input latency and visible jitter in a Roblox vehicle. Smooth-feeling vehicles hand ownership to the driver. The job must weigh both sides properly rather than assume either.

Method (per user: 'invoke all physics skills'): consult roblox-physics (constraints, assemblies, buoyancy, vehicles, network ownership), roblox-multiplayer (ownership + replication), roblox-optimization (physics stepping, mobile perf), and the official Creator Docs for anything fragile. MEASURE the real behaviour in a live playtest -- velocity/position traces, physics step rate, force magnitudes -- and do not tune constants by eye.

Also rule in or out: the buoyancy spring's stiffness/damping (a mistuned per-frame VectorForce spring reads as vertical vibration); the single AlignOrientation at :185 with MaxTorque toggled at :348/:390/:392; drag as a VectorForce opposing horizontal velocity (chatters near zero); Heartbeat force writes vs physics steps; DENSITY/CustomPhysicalProperties at :91 and the Massless welded superstructure.

Related: todo 0047 (turret + searchlight visual lag) shares the replication half of this problem and may be fixed by the same decision.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
