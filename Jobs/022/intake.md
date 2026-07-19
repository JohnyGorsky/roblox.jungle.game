# Job #022: Run rewards to Gold: zone-stepped payout + nuggets

**Project**: `roblox.jungle`
**Created**: 2026-07-19 11:41:17
**Status**: Requirements Gathering (intake)

## Requirements / goal

POC. Replace floor(distance/10) placeholder with zone-stepped Gold reward (4 zones at 25/50/75/100pct, partial payouts, +4 completion premium for finishing), computed server-side on run end and credited to the persistent profile. Add rare Gold nugget pickups at camps (cap 3 per run). Depends on Persistence foundation. Design source: Job 020 section 2.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan (inline — small job; design fully specced in Job 020 §2)
- [x] Implementation completed — WIN credits +10 Gold verified live (attr + leaderstats + HUD + results
      screen); reward curve matches Job 020 §2; analyzer-clean. Nuggets construction-verified.
- [x] Final summary + changelog written
