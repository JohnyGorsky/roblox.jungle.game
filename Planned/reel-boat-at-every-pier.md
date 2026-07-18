# Reel the boat in with the rope at EVERY pier

**Source:** Job #016 (crash-site staging built the winch/rope reel-in). **User request (2026-07-18):** the
pull-the-rope-to-reel-the-boat-in mechanic should work at the river docks too, not just the start pier.

## Scope
- The river **docks** (`World/DockServer.server.luau`) currently only tie/untie (anchor hold). Give them the
  same **winch + pull-to-reel** behaviour built for the crash-site pier in #016.
- **Do it via a shared module** — extract "moor + winch reel" (the `LinearVelocity` plane-hold that leaves
  Y to buoyancy + the pull/reel + release) out of `StagingServer` into something both StagingServer and
  DockServer require, so the physics-correct hold isn't duplicated.

## Why it matters
Consistent, physics-safe docking everywhere; lets players pull up neatly to refuel/disembark at any dock.

## Watch out (hard-won in #016 — see the roblox-physics skill)
- **Never anchor** the boat to hold it (explodes on release with a rider aboard). Use the constraint hold.
- Hold must **not touch Y** (buoyancy owns it, or it bounces).
- Keep the boat **server-owned** while held/driven.

→ Promote to a job.
