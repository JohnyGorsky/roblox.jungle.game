# FINDING 0010: Mobile players are never told how to start a run

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-18 20:14:02

**Symptom:** Job #099 hid the lobby's centre hint on touch (user request - it dominated a 666x374 phone canvas and collided with the identity panel). That card carried the ONLY on-screen statement of how a run begins: 'First on a pad leads - hold Start to launch the run (up to 6).' A mobile player now gets that information nowhere. The launch pad itself is the natural home for it - a BillboardGui over the pad, or a short auto-fading toast the first time a player steps near one (the Job #098 Hints system already does once-ever per-player banners and would take one table entry). Desktop is unaffected.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_

## SCOPE WIDENED (Job #099, 2026-08-18)

The same thing has now happened in the GAME place. `StagingHint` — the crash-site card reading
"BOARD THE BOAT & UNTIE / Anyone can pull the rope — the run starts the moment it's loose" — is also
hidden on touch, for two reasons:

1. It was already reported CLIPPED on a real phone ("BOARD THE BOAT &", cut mid-title).
2. Once Job #099 moved health/vitals/cargo/role into a top-left column to clear the movement
   thumbstick, this card overlapped that column (25x26 and 10x48). The top-centre band is no longer
   free on a 666x316 canvas.

**So a mobile player is now told neither how to START A RUN (lobby) nor how to BEGIN ONE once at the
crash site (game).** Both instructions need a home that is not a centre-screen banner.

**Suggested fix for both:** the Job #098 `Hints` system already delivers once-ever, per-player banners
and each new hint is one table entry. A ProximityPrompt on the launch pad and on the boat's rope would
be even better — the instruction then lives on the object it refers to, which is where a player looks.