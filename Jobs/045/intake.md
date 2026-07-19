# Job #045: Intro cinematic camera + crash cold-open (wake up at the crash site)

**Project**: `roblox.jungle`
**Created**: 2026-07-19 18:55:56
**Status**: Requirements Gathering (intake)

## Requirements / goal

Step 4 of game-intro-sequence. Client IntroCameraClient takes a Scriptable camera during the intro: a chase/tracking shot that rides Workspace.IntroPlane through the 10s cruise + descent (reads the plane pivot each RenderStep, so it's smooth despite the anchored CFrame movement). Impact fade (existing IntroFade) cuts to the crash COLD-OPEN: PlaneServer lays the crew prone at the hub (PlatformStand + lying CFrame, movement locked), fades back in, camera does a low ground shot that slowly rises as they wake (~2.5s), then the character stands and control+normal camera return (IntroWake flag). Greybox (no real prone/get-up animation yet - art later). Not committed.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
