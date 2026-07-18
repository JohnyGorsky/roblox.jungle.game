# Job #006: P3 POC: first alligator - AI chase, boat HP, shoot back

**Project**: `roblox.jungle`
**Created**: 2026-07-18 15:19:49
**Status**: ✅ Completed (2026-07-18)

## Requirements / goal

Greybox POC slice of P3 (threats/combat). A single crocodile/alligator enemy that: detects the boat (aggro radius), swims toward it, and bites it dealing damage. Boat gets an HP stat with damage feedback and a fail state at 0. A basic weapon lets the player shoot/hit the croc to kill it. Server-authoritative. Greybox croc model first (block or quick Meshy), spawn one for the drive-test. Defer to follow-up slices: player health + downed + bandage revive, multiple crocs + spawn/pacing director, formal gunner role (P2). Skills: roblox-ai (aggro/chase/attack loop, on-water movement), roblox-animation (swim/bite), roblox-chars (Meshy croc), roblox-scripting (server authority). Builds on Jobs #003 (boat) + #005 (river). See Planned/P3-threats-combat-revive.md.

## Design context (build the system to extend cleanly)

This POC is one **sea** croc, but the eventual threat system (GAME.md "Threats") has **two domains —
sea/river vs land — each scaling strength with time of day** (sea peaks at NIGHT, land active by DAY).
So model an enemy as data with a **category (sea/land)** and a **time-of-day strength modifier** hook,
even if the POC hardcodes day. Don't bake in assumptions that block adding land threats or a day/night
multiplier later. (Day/night safety flip: DAY = travel the water, NIGHT = shelter on land at a dock.)

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] Final summary + changelog written
