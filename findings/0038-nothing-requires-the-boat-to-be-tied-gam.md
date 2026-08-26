# FINDING 0038: Nothing requires the boat to be tied - GAME.md says it gates going ashore, code does not

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-26 19:59:07

**Symptom:** GAME.md:232 states the design: 'Tie up the boat - a hands-on action... Only once it's tied can the crew get out.' That gate does not exist anywhere in the code.

ExcursionServer's ashore loop and HudState.onBoat gate on a downward raycast only; the goAshore hint (Hints.luau) fires 2s after any player steps off the boat, tied or not. A player can beach the boat, jump off, loot the camp and come back, never having tied anything.

Surfaced by the independent reviewer on Job #120 and worth recording because it is very likely the ACTUAL root cause of the user's report 'players dont know that you need to tie boat at piers': they do not know because they never have to. Job #120 gave the tie action a visible sign, a readable caption and a visible rope, which fixes DISCOVERABILITY of the affordance - it cannot create a reason to use it.

Related, from the same review and also not addressed by a sign:
  - The penalty for not tying is invisible. Untied, BoatServer keeps applying the current (idle drift ~6 studs/s) and keeps burning FUEL_IDLE 0.15/s with nobody aboard, and EnemyServer's 55-stud tied wildlife safe zone never engages. BoatStatusCard has no tied/untied readout at all.
  - Half the piers are unmarked. RiverProgress only pins docks where landing is true (odd indices), so every other pier - the pure tie/refuel stops - has no marker anywhere and players may not know they are interactable.

Deciding whether tying should GATE going ashore is a design call (it changes pacing and the camp loop), so it is logged rather than made.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
