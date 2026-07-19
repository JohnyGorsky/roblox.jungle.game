# Final Summary — Job #044: Plane intro cinematic (board → fly-up hold → smoking descent → arrive at crash site)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Step 3 of the
game-intro-sequence (`Planned/game-intro-sequence.md`). Game place. Greybox.

## What
The opening beat: the crew rides a plane that goes down over the jungle and lands them at the crash-site hub —
all staged behind the loading-screen mask so it doubles as the join/world-gen wait. The hub's existing
`PlaneWreck` greybox reads as the crashed plane once they're on the ground.

## Implementation
- **`sync/ServerScriptService/Intro/PlaneServer.server.luau`** (new):
  1. Sets `Workspace.IntroActive = true` at startup (so `PlayerCombat` doesn't place players).
  2. Builds a greybox plane in the sky above `HubSpawn` (fuselage/wings/tail/nose + up to 6 open-top `Seat`s)
     and **force-seats every crew member** on spawn (`Seat:Sit`), queuing late joiners.
  3. **Hovers** (bob + slow rise) while the readiness gate holds (`IntroReady ~= true`, Job 043) — masked.
  4. On `IntroReady`: enables `Smoke` and does a smoothstepped **nose-down descent** toward the hub (the loader
     fades → the descending plane is revealed with the crew aboard).
  5. At impact: `IntroFade` → black, unseats everyone, places them at `HubSpawn`, destroys the flying plane,
     fades back in, `IntroActive = false`.
- **`sync/StarterPlayer/StarterPlayerScripts/UI/IntroFade.local.luau`** (new): full-screen black overlay,
  driven by the `ReplicatedStorage.IntroFade` RemoteEvent (`"out"`/`"in"`, duration) for the impact cut.
- **`sync/ServerScriptService/Combat/PlayerCombat.server.luau`**: skips its hub/boat placement while
  `IntroActive` (PlaneServer owns placement during the intro; normal respawns unchanged afterward).

## Verified (live in Studio — game place)
- [x] Analyzer-clean.
- [x] **Boarding (masked):** with the gate held, server read a seat `Occupant` = the player, `Humanoid.Sit=true`,
      plane at Y≈317; **player Y == plane Y** (rides the anchored plane via the seat weld).
- [x] **Reveal + descent:** forcing the gate open faded the loader and revealed the player seated in the plane
      descending through the sky (screenshot), then low over the hub.
- [x] **Arrival:** `IntroActive=false`, plane destroyed, player unseated on the ground at the hub (near the
      jetty/boat), free to play.
- [x] Test overrides reverted (`DESCENT_TIME` 12→4.5, `__DebugExpectedParty` cleared).

## Update (2026-07-19) — longer, predefined flight
Added a **predefined visible cruise** before the descent (user: "can we play much longer? like 10 seconds, then
just go down"). After the mask lifts the plane now flies level for `CRUISE_TIME` (10s, tunable) — smoothstepped
approach with a gentle bob + bank — then does the `DESCENT_TIME` (5s) nose-down descent. So airtime is a fixed
~15s regardless of how fast the readiness gate opened. Verified: masked hover shows the player seated and riding
(`Sit=true`, player Y == plane Y == 295), and the greybox plane visibly cruises in from distance before going down.

**Known caveat (→ next job):** during the long cruise the default camera doesn't ride smoothly with the
anchored, CFrame-moved plane (it can stay grounded and watch the plane fly). Fixing that is the **cinematic
camera** work in the next step — without it the long flight isn't showcased well.

**Direction fix (2026-07-19):** the nose sat at local -Z but the plane travels +Z toward the hub, so it flew
backward (user spotted it). Added a `FACE` 180° yaw to the build/cruise/descent CFrames so the nose leads.

## Notes / follow-ups
- **Not committed.**
- Camera just follows the seated character (no cinematic camera yet) and there's no prone wake-up — those +
  smoke/impact VFX polish are the **next job** (step: crash cold-open + wake at the boat/start-area shop).
- Seat welds carried a single rider through both a 4.5s and a 12s descent cleanly; if it turns flaky with a
  full 6-player crew at speed, fall back to welding HRPs directly to the fuselage.
- Overflow (>6 players) rides unseated near the hub — fine for POC; add rows if party cap grows.
- Placement scatters the crew ±6 studs around `HubSpawn`; readable but a touch loose — tighten in the polish job.
