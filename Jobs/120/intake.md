# Job #120: Tie Boat sign on river piers

**Project**: `roblox.jungle`
**Created**: 2026-08-26
**Status**: ✅ COMPLETE — implemented, verified in Play, closed 2026-08-26

## Requirements / goal

User request, verbatim:

> new task. Players dont know that you need to tie boat at piers. So reuse existing signs, put sign on
> pier, and put info - Tie Boat, and set action on that sign. Also rope must go from sign to boat.
> visible. Test it

So four things, in order:

1. **A physical sign standing on the river pier**, built from the sign recipe this game already uses
   (not a new invented sign, and not a floating billboard — STYLEGUIDE §5 bans those for world signage).
2. The sign **reads "TIE BOAT"** so the mechanic announces itself before the player has to guess.
3. The **tie action lives on that sign** — the thing the player walks up to is the thing they press.
4. The **mooring rope runs from the sign to the boat**, visible.

Then: **tested in gameplay**, not in Edit (GROUND-RULES §7).

## The discoverability problem, stated plainly

Tying at a river pier is already fully implemented (`DockServer.server.luau`), and it already has a
`ProximityPrompt` whose `ActionText` is literally `"Tie Boat"`. The problem is not that the feature is
missing — it is that **the trigger hangs off an invisible part**:

- The prompt is parented to a `TieSpot` `Attachment` on `Deck` (`DockServer:301-311`).
- `Deck` has been `Transparency = 1` since Job #077 (`DockServer:279`) — the visible object is the
  62-part `Pier` model, and `Deck` survives only as the invisible anchor everything hangs off.

So the affordance is a prompt bubble floating over nothing, at the geometric centre of a pier, with no
object attached to it and nothing in the world that says the pier is for tying up. This job gives the
prompt a body.

## Decisions taken at intake (via wizard, 2026-08-26)

| Question | Decision |
|---|---|
| How to "reuse existing signs" | **Extract the recipe to a shared module.** `buildShopSign` is currently a `local function` inside `ExcursionServer` (the camp system). It becomes `World/WorldSign.luau`, required by **both** ExcursionServer and DockServer. One recipe, one place to restyle. |
| Where the rope attaches on the sign | **Round the signpost, at deck level** (~1 stud above the pier deck) — reads as a real mooring line and stays near-horizontal to the hull, rather than a steep line down from the board 6 studs up. |

⚠️ The first decision means this job **edits `ExcursionServer.server.luau`**, which belongs to the camp
system rather than the dock system. GROUND-RULES §1 requires that be confirmed before editing across
that boundary — it was, in the intake wizard above. Nothing about camp signs may change visually.

## Scope

**In scope** — the GAME place only (`sync/`), river piers only:
- `sync/ServerScriptService/World/DockServer.server.luau` — the sign, the prompt move, the rope anchor.
- `sync/ServerScriptService/World/WorldSign.luau` — new shared sign module.
- `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` — `buildShopSign` delegates to the
  module. **Camp signs must look and behave exactly as they do today.**

**Out of scope**:
- The **spawn dock** at the crash site (`StagingServer`). The boat starts *already tied* there and its
  prompt is an UNTIE (`StagingServer:197`, `"Untie rope — START"`), so there is no tie mechanic to
  teach. Not touched.
- The **LOBBY place** (`lobby/sync/`). Different place, different owner.
- Any change to the tie *mechanics* — the mooring `LinearVelocity`, the centre-of-mass moor point, the
  `Tied` attribute, `RequestUntie`, or the `UntieButton` GUI path. This job moves where the trigger and
  the rope *hang*, not what they *do*.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] **Independent reviewer agent run** - given the symptom/requirement, NOT my theory (GROUND-RULES 8)
- [x] **Symptom reproduced in PLAY**, at the player's camera, before any fix (GROUND-RULES 7)
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] **Proof it works better** captured - before/after from the same camera, in Play
- [x] Final summary + changelog written
