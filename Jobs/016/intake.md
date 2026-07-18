# Job #016: Crash-site staging area + rope Start gate

**Project**: `roblox.jungle`
**Created**: 2026-07-18 20:34:20
**Status**: Requirements Gathering (intake)

## Requirements / goal

Restructure the run's front end (GAME.md two-place vision, staging phase). SAME gameplay place, phased: players spawn at a greybox CRASH-SITE HUB (where the plane fell) at the river start, NOT on the boat. The boat sits MOORED (tied with a rope) at the river start, stationary; the river run (threats/progression) is GATED until start. Players walk from the hub to the boat, board, and UNTIE THE ROPE (ProximityPrompt) = the Start gate -> boat is released, run begins (threats/river progression start). Driver still steers after untie (current driving unchanged). Greybox POC now; polished staging-area design deferred to a later job. Precedes P2 role-assignment + P8 pre-run shop (both will hang off this hub) and P6 lobby/teleport. Decided with user 2026-07-18.

## Decisions locked (via wizard + chat, 2026-07-18)

- **Same place, phased** — hub → boat/river in ONE gameplay place, no teleport between them.
- **Start gate = untie the mooring rope.** Boat sits tied/stationary at the river start; a ProximityPrompt
  "Untie" releases it and flips the run to STARTED.
- **Boat driving is UNCHANGED** — after untie the Driver steers via the VehicleSeat exactly as now. The
  rope-untie is purely the Start trigger.
- **Threats/progression GATED until started** — no enemies/river danger during staging; they begin at untie.
- **Players spawn at the HUB, not on the boat** (reverses the current spawn-on-hull behaviour, gated to
  before-start).
- **Hand-built vs procedural split (GROUND-RULES §2):** the human HAND-BUILDS the crash-site hub AND the
  startup river section (the moored-boat area). The existing PROCEDURAL river generator takes over only
  AFTER that hand-built stretch. This job provides the LOGIC + a greybox placeholder hub (clearly marked
  for replacement) + defines the HANDOFF point where procedural generation begins once the boat passes
  the hand-built section. No scripting of hero hub/terrain art.

## Open (for the plan, after code map)

- Where the hand-built section ends / procedural begins (a Z threshold), and how the generator is told
  "start ahead of here" instead of at the current boat spawn.
- Multiplayer: any player's untie starts the run for the whole crew (assumed yes).
- Where exactly the hub + moored boat sit relative to RiverData's river start.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] Final summary + changelog written
