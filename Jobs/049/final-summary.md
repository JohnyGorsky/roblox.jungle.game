# Final Summary — Job #049: Fix boat night light + remove shiny moon

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Fixes FINDING 0001 + TODO 0009.
Game place.

## The two issues
1. **Boat light not working when riding** (FINDING 0001) — the only boat light was the **Searchlight**, which is
   (a) gated behind an *owned* boat module and (b) night-only (dusk ~95s into a session). A default ride with no
   module, or a short daytime ride, had no light at all → read as "broken".
2. **Moon too shiny** (TODO 0009) — the place's `Sky` had `MoonAngularSize=11` + a moon texture, making nights
   too bright.

## Fixes
- **`sync/ServerScriptService/Boat/BoatModules.server.luau`**: every boat now builds a basic **BowLight**
  (SpotLight at the bow, aimed forward, Range 55/Brightness 2.5) tagged `NightLight`, `Enabled=false` — so
  `LightController` turns it on dusk→dawn like any night light. The **Searchlight module remains the upgrade**
  (bigger head, Range 90/Brightness 4). Built at `RunStarted` with the rest of the boat.
- **`sync/ServerScriptService/World/DayNightServer.server.luau`**: at startup sets `Sky.MoonAngularSize = 0`
  and clears `MoonTextureId` (moon gone). Done in code (Lighting isn't file-synced) so it's reproducible.

## Verified (live in Studio)
- [x] Analyzer-clean.
- [x] At night (test `START_CLOCK=20`, ClockTime 21.8) with `RunStarted`: `BowLightHead` built,
      `SpotLight.Enabled=true` — boat has a working light; screenshot shows the beam on the water.
- [x] `Sky.MoonAngularSize=0`, `MoonTextureId=""` — night sky is dark/starry, no shiny moon (screenshot).
- [x] Test `START_CLOCK` reverted to 8.

## Notes / follow-ups
- **Not committed.**
- Night is still day/night-cycle gated (dusk ~95s from server start, per the user's "lights night-only"
  request) — the light won't show on a short daytime ride, by design. To see it, ride into dusk (or it's
  already night).
- If owning the Searchlight module, the boat now shows both the bow light + the searchlight (harmless overlap);
  fine for POC.
