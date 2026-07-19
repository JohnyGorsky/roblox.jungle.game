# Final Summary — Job #052: Fix weak boat light + slide-off-seat on moving boat

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Two playtest bugs. Game place.

## Bug 1 — boat night light too weak (couldn't see)
The default bow light was `Range 55 / Brightness 2.5` — with the moon removed (Job 049), nights were too dark
to see the path.

**Fix — `sync/ServerScriptService/Boat/BoatModules.server.luau`:**
- Bow `SpotLight` boosted to `Angle 80 / Range 95 / Brightness 9` (a wide, strong forward beam).
- Added a `PointLight` glow (`Range 34 / Brightness 2.5`) on the bow head so the **deck + immediate
  surroundings** are lit, not just the forward cone. Both tagged `NightLight` (night-only).
- Searchlight **module** (the upgrade) boosted to `Range 130 / Brightness 11`.

## Bug 2 — leaving the driver seat on a moving boat → slide off
Leaving a `VehicleSeat` launches the character with the seat's velocity. On a moving boat that inherited speed
stacked with the per-frame rider-carry (Job 040), so the player slid forward faster than the boat and off the
deck.

**Fix — `sync/StarterPlayer/StarterPlayerScripts/Boat/BoatRideClient.local.luau`:**
- While on the boat and **not actively walking** (`Humanoid.MoveDirection.Magnitude < 0.1`), zero the
  character's **horizontal** velocity each frame (keep Y for gravity/jump). The carry then becomes the only
  horizontal mover, so residual/inherited launch velocity can't slide you off. Walking still works (velocity
  allowed when there's input).

## Verified (live in Studio — Play at night)
- [x] Analyzer-clean.
- [x] Light: bow Spot `Range 95 / Bright 9 / Angle 80` + Glow PointLight built & enabled at night; screenshot
      shows the water lit well ahead and the deck visible.
- [x] Slide: injected a 45-stud/s forward "launch" on an unseated character standing on the boat →
      horizontal velocity fell to **0.0** and it **slid 0.0 studs** relative to the deck (stayed aboard).
- [x] Test `START_CLOCK` reverted to 8.

## Notes / follow-ups
- **Not committed.**
- Light values are tunable in BoatModules if it's now too bright.
- The velocity-zeroing only triggers when standing still on the boat; walking is unaffected. Jumping straight
  up on the boat also gets planted horizontally (minor, acceptable).
