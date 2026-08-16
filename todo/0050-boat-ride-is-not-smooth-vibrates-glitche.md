# TODO 0050: Boat ride is not smooth: vibrates/glitches, feels clumsy

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-16 22:16:23

User direction 2026-08-16: 'riding the boat glitches, riding is not smooth, it vibrates somehow. Lots of Roblox games feel smooth; this does not. Understand how to make it smooth so riding feels ok.' Explicitly asked that the physics skills be consulted properly rather than guessed at.

PRIME SUSPECT (from a first read of BoatServer.server.luau, NOT yet proven): THE BOAT IS SERVER-OWNED ON PURPOSE. :268 claimServerOwnership() calls hull:SetNetworkOwner(nil), and the Heartbeat loop at :284-300 RE-GRABS ownership every frame whenever a client holds it. The header at :21-23 records why: buoyancy is computed server-side, so a client-owned hull would feed the spring LAGGED replicated positions and bounce; plus exploit-resistance for co-op. Decided in the Job 003 review, 2026-07-18.

That decision is the thing to re-examine, because it is also the standard reason a Roblox vehicle feels bad to drive: the driver never simulates their own vehicle. They see it only through replication + interpolation, so they get input latency and visible jitter, while games that 'feel smooth' hand network ownership to the driver and let the vehicle run locally at the client's frame rate.

OTHER CANDIDATES to rule in/out during the investigation, not conclusions:
  - the buoyancy spring itself (a per-frame VectorForce spring can oscillate if stiffness/damping are mistuned -- would read as vertical vibration);
  - one AlignOrientation (:185) driving the whole hull attitude, MaxTorque toggled at :348/:390/:392, fighting the water;
  - drag applied as a VectorForce opposing horizontal velocity (:10) -- sign/magnitude errors here chatter around zero velocity;
  - Heartbeat-driven force writes vs physics steps (adaptive stepping / step rate);
  - DENSITY + CustomPhysicalProperties at :91 and the Massless welded superstructure (:132, :154).

SCOPE NOTE: this is an UNDERSTAND-FIRST job. Consult roblox-physics (constraints, assemblies, network ownership, buoyancy, vehicles), roblox-multiplayer (ownership + replication), roblox-optimization (physics stepping, mobile) and the official docs before proposing any change. Measure the actual behaviour in a playtest -- do not tune constants by eye. Related: todo 0047 (turret/searchlight visual lag) shares the replication half of this problem.
