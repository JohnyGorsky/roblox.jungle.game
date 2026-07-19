# Job #044: Plane intro cinematic (board -> fly-up hold -> smoking descent -> arrive at crash site)

**Project**: `roblox.jungle`
**Created**: 2026-07-19 18:37:05
**Status**: Requirements Gathering (intake)

## Requirements / goal

Step 3 of game-intro-sequence. New PlaneServer (game): sets Workspace.IntroActive=true at startup, builds a greybox plane in the sky above the crash-site hub with up to 6 seats, force-seats every crew member on spawn, hovers while the readiness gate (IntroReady, Job 043) is open=false, then on IntroReady does a greybox smoking nose-down descent toward the hub, fades to black at impact, unseats + places everyone at HubSpawn, IntroActive=false (hub's existing PlaneWreck becomes the crashed plane). PlayerCombat defers its hub/boat placement while IntroActive. Client IntroFade black overlay for the impact cut. Greybox; wake-up cold-open + cinematic camera are the next job. Not committed.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
