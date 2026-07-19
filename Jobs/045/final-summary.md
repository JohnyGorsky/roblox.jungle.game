# Final Summary — Job #045: Intro cinematic camera + crash cold-open

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Step 4 of the
game-intro-sequence (`Planned/game-intro-sequence.md`). Game place. Greybox.

## What
Makes the plane intro actually *look* cinematic and lands the crash cold-open: a camera that rides the plane
through the fly-in + descent, then a low ground shot of the crew lying at the crash site slowly waking up,
then control + the normal camera return. Realises the user's "plane crashed, we're on the ground and slowly
wake up" beat.

## Implementation
- **`sync/StarterPlayer/StarterPlayerScripts/Boat/IntroCameraClient.local.luau`** (new): while
  `Workspace.IntroActive`, takes a **Scriptable** camera —
  - **Cruise + descent:** a stable 3/4 **chase shot** that reads `Workspace.IntroPlane`'s pivot each
    `RenderStepped` and frames it (`CFrame.lookAt`), so it tracks smoothly despite the anchored, CFrame-moved
    plane (the default camera couldn't — it stayed grounded, Job 044's caveat).
  - **Wake (`Workspace.IntroWake`):** a low shot on the local character that **rises** (smoothstepped height +
    pull-back) over `WAKE_TIME` as they come to.
  - **End:** on `IntroActive=false`, restores `CameraType=Custom` + `CameraSubject` and disconnects. Waits up
    to 5s for the intro to be claimed at join (avoids a race); inert if there's no intro.
- **`sync/ServerScriptService/Intro/PlaneServer.server.luau`** (impact section rewritten): after the descent,
  fade to black → destroy the plane → set `IntroWake=true`, lay every crew member **prone** (`PlatformStand`
  limp + horizontal CFrame, movement locked) at the hub → fade back in on the crash scene → hold 2.6s → stand
  them upright, restore movement → `IntroWake=false`, then `IntroActive=false`. (Keeping `IntroActive` true
  through the wake means `PlayerCombat` still defers placement during the cold-open.)

## Verified (live in Studio — game place)
- [x] Analyzer-clean.
- [x] **Chase cam:** captured a clean 3/4 tracking shot of the greybox plane flying over the river during the
      cruise (the fly-in now reads as cinematic, not a grounded fly-by).
- [x] **Cold-open:** captured the character lying collapsed in the grass at the crash site under the low
      wake-up camera.
- [x] **Hand-off:** after the sequence — `IntroActive=false`, `IntroWake=false`, `CameraType=Custom`,
      `PlatformStand=false`, `WalkSpeed=16` (player stands, awake, normal camera + control).
- [x] Test timings reverted (`CRUISE_TIME` 10, `DESCENT_TIME` 5, wake hold 2.6).

## Notes / follow-ups
- **Not committed.**
- The prone pose is a **greybox limp ragdoll** (no real crash/get-up animation) — reads as "knocked out" but a
  proper prone→get-up animation is part of the later art pass.
- Chase-cam offset is a fixed world vector (`+40,+16,-48`); fine for the current straight-in path. If the
  flight path changes to bank/turn, make the offset relative to the plane's facing.
- Remaining for the sequence: the start-area **Robux shop** by the boat, then the **art pass** (real plane,
  smoke/impact VFX, environment, animations) that swaps every greybox.
