# Job #049: Fix boat night light + remove shiny moon

**Project**: `roblox.jungle`
**Created**: 2026-07-19 19:54:23
**Status**: Requirements Gathering (intake)

## Requirements / goal

FINDING 0001 + TODO 0009. Boat was dark when riding: the searchlight is gated behind an owned module + is night-only (~95s to dusk), so a default ride had no light. Fix: every boat now gets a basic BOW LIGHT at night (BoatModules, night-only NightLight tag), Searchlight module stays the upgrade. Moon: DayNightServer sets Sky.MoonAngularSize=0 + clears MoonTextureId at startup (moon too shiny). Not committed.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
