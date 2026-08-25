# Job #118: Bazooka — arcing rocket launcher sold as a lifetime pass or per-run purchase

**Project**: `roblox.jungle`
**Created**: 2026-08-25 14:27:49
**Status**: Requirements Gathering (intake)

## Requirements / goal

Add the Bazooka to Last River as the second Robux-sold handheld weapon, and the first PROJECTILE weapon.

SELLING (both Hub ids already exist, created alongside the M16's in Job #117, currently IsForSale and wired to NOTHING)
- Lifetime game pass 'Bazooka lifetime' (1956512376, 250 R$): owner starts EVERY run with the Bazooka + 6 rockets, free.
- Per-run developer product 'Bazooka' (3709767468, 80 R$): one purchase per run grants the Bazooka + 6 rockets for that run only. Lobby purchase banks on the profile and is spent at the next run; in-run (crash-site kiosk) purchase grants immediately. Second purchase in the same run refused.
- Both offers appear in BOTH Robux shops (lobby + game start-area kiosk).
- NOT lootable at camps and NOT buyable with Salvage.

FIRING (projectile weapon, not hitscan)
- One trigger pull launches ONE rocket. 5 s reload before the next.
- The rocket flies a visible ARC (up, then down) and lands on the targeted point after exactly 4 s.
- Max targeting distance 300 studs; aiming beyond that clamps the impact point to 300 studs along the aim.
- A RED CIRCLE on the ground marks the impact point: a private aim preview while the weapon is held, and a public pulsing marker at the locked point for the 4 s of flight.
- Impact: big blast — particles, shockwave ring, light, camera-scale FX.
- 300 damage at the centre, 30-stud radius, falling off to ~25 pct at the edge. Enemies/camp guards/generators ONLY: players, crew and the boat are never damaged (owner decision).
- 6 rockets a run, no way to buy more (same hard cap that holds the M16's line).

AUDIO (all uploaded by the user 2026-08-25, lengths measured in Studio)
- bazooka_shoot 135920240434402 (5.094 s) and bazoka_shoot 122026452986070 (1.440 s): TWO fire variants, chosen at random per shot.
- rocket_whistle 138261119768443 (3.840 s): starts at launch, runs the flight.
- rocket_loop 73214531471418 (1.848 s): looped on the moving rocket.
- rocket_impact 73027674412530 (2.112 s): the blast heard from a distance.
- rocket_impact_near 108549200090609 (4.776 s): the blast when it goes off close to you.

ART (uploaded/imported by the user 2026-08-25)
- Launcher mesh 135181183468020 -> ServerStorage.AssetLibrary.Weapons.Bazooka (currently a Model wrapper; must be unwrapped to a bare MeshPart)
- Rocket mesh 87692913599759 -> ServerStorage.AssetLibrary.Weapons.Rocket (same)
- Icon bazooka_icon 76642882799637 (hotbar + one-run shop row)
- Icon missile 100284588876499 (the rocket/ammo glyph)
- Hub art RobloxPassBazooka 78985801749301 (Creator Hub pass listing art)

ADMIN
- Admin-panel actions to grant the Bazooka + rockets and to bank a per-run charge, so it can be tested without buying.

NOTE: this is the THIRD deliberate 'power = true' exception. GAME.md's monetization section must record it.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] **Independent reviewer agent run** - given the symptom/requirement, NOT my theory (GROUND-RULES 8)
- [ ] **Symptom reproduced in PLAY**, at the player's camera, before any fix (GROUND-RULES 7)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] **Proof it works better** captured - before/after from the same camera, in Play
- [ ] Final summary + changelog written
