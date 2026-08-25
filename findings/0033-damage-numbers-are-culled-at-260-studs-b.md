# FINDING 0033: Damage numbers are culled at 260 studs, but the Bazooka reaches 300

**Project:** `roblox.jungle`
**Status:** open
**Severity:** low
**Created:** 2026-08-25 15:44:18

**Symptom:** Raised by the independent reviewer on Job #118 and verified. CombatFeedback sets MAX_DIST = 260 and skips both the floating number and the hit burst past it (line 187), and also caps gui.MaxDistance at the same value. The Bazooka's range is 300 studs, so a max-range rocket lands and deals up to 300 damage with NO number shown. Mitigated in Job #118 but not closed: the explosion itself (flash, shockwave, particles, sound) is drawn by RocketFx and is deliberately NOT routed through CombatFx, so the player does see the blast - just not what it did. Worth revisiting if any weapon's range grows again, since 260 was chosen when the longest handheld reach was the M16's 250. The boat turret already reaches 350 and has the same gap.
**Where:** sync/StarterPlayer/StarterPlayerScripts/Combat/CombatFeedback.local.luau:38 (MAX_DIST) and :187
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
