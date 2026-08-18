# Job #098: Cargo onboarding — first-time hints + landing-zone sign

**Project**: `roblox.jungle`
**Place**: **GAME only** (`sync/`)
**Created**: 2026-08-18
**Status**: Requirements Gathering (intake)

## The problem

**Players do not know they can pick loot up and carry it to the boat.** The mechanic exists, works, and
is central to the loop — scavenge at camps, haul it back, spend it on fuel and repairs — but nothing in
the game ever says so. A player who never picks up a crate never discovers the resource economy, and
therefore never discovers the rear stations either.

## Requirements

1. **First pickup** → tell the player to deliver it to the boat.
2. **First successful deposit** → tell them they can **load fuel and repair the boat at the rear
   stations**.
3. **A physical sign in the landing zone**, carrying an image the user will supply, in the style of the
   existing `Survive` sign. Claude places it roughly; **the user repositions it by hand.**

## Decisions (agreed via wizard)

| # | Question | Decision |
|---|---|---|
| 1 | How often | **Once ever**, persisted in the player's profile. A veteran on their 50th run never sees it again. |
| 2 | Channel | **ZoneBanner-style centre banner**, delivered **per player** |
| 3 | Scope | **A reusable first-time hint system**, seeded with these two |

## Investigation

### A. Where the two moments already are

Both live in `sync/ServerScriptService/Excursion/ExcursionServer.server.luau`:

- **Pickup** — `pickupLoot()`: a *resource* crate (gasoline/metal/turret-ammo) sets
  `char:SetAttribute("Carrying", resource)` and `player:SetAttribute("Busy", true)`. Note **weapon and
  ammo crates return early** — they grant instantly and are never carried, so the hint must fire on the
  resource path only or it will lie.
- **Deposit** — the deposit handler increments the boat's resource attribute and already fires
  `crewToast:FireAllClients{...}` ("X deposited 1 Metal"). The hint hooks the same success path, *after*
  the "cargo deck full" early-return, so a refused deposit never teaches the wrong lesson.

### B. ⚠️ The banner channel is crew-wide today

`Announce` (→ `ZoneBanner`) is only ever fired with **`FireAllClients`**, and `ZoneServer`'s own comment
reserves it for rare beats — zone crossings, nightfall, dawn. `ExcursionServer` explicitly declined to
use it for deposits for exactly that reason.

**A first-time hint is per player.** Fired as-is, one player's tutorial banner would land on all six
crew members' screens — including veterans who have seen it fifty times. So this job must add a
**per-player path** to that channel (`FireClient`), not reuse the existing call.

That is the main piece of real work here; everything else is small.

### C. Persistence is straightforward

`sync/ReplicatedStorage/Progression/ProfileConfig.luau` → `default()` returns a plain table, and the
loader is documented as **forward-compatible** ("fill any missing field"). Adding a `seen = {}` map costs
one field and needs no migration.

Profiles are served by `Progression/Profiles.luau` + `ProfileServer.server.luau` (ProfileStore).

**Edge case to decide in the plan:** what happens when the profile *fails to load* (the in-memory
fallback `MonetizationServer` already guards against). Showing the hint every run to that player is
annoying; never showing it means a first-timer learns nothing. A sensible default is *show it* — the
cost of a repeat is much lower than the cost of never teaching the mechanic.

### D. The sign — a template already exists

`Workspace.SpawnBase.sign` already contains **`Survive`**, which is exactly the style referenced:

| | |
|---|---|
| Pivot | `-189, 23, -339` · **80 studs from spawn** |
| Board | `8.0 × 3.0 × 0.4`, `WoodPlanks`, anchored |
| Structure | two `Post` (0.6×4.5×0.6, Wood) + `TopRail` (9×0.5×0.7) + `Board` (PrimaryPart) |
| Faces | `SurfaceGui` on **Front and Back**, `PixelsPerStud = 50` |
| Type | `Enum.Font.SpecialElite` — STYLEGUIDE's physical-world-sign font |

The landing zone for reference: `SpawnLocation` at **`-265, 18, -311`** (facing −Z), the `Plane` wreck at
`-302, 27, -288`, the `Dock` at `-172, 14, -302`. The natural spot for a "carry loot to the boat" sign is
on the **walking line from spawn to the dock**, facing the player as they set off.

**⚠️ It must be a real editor Instance, not script-generated.** The user is going to move it. Anything a
script builds at runtime would be rebuilt at its scripted position every run and silently discard that
move — the same rule the lobby already follows (objects are hand-placed; scripts find them by name).

### E. The image — SUPPLIED

**`BoatInfo` — `rbxassetid://113207367236651`** (uploaded by the user 2026-08-18). Registered in the
shared catalog at `roblox.workspace/Assets/registry/images.md`.

It is an infographic titled **"HOW TO USE THE BOAT"**:

| | |
|---|---|
| 1 | LOAD ITEMS AND DEPOSIT THEM IN THE CENTER AREA |
| 2 | USE THE FUEL STATION TO REFUEL THE BOAT |
| 3 | USE THE REPAIR STATION TO REPAIR THE BOAT |

with three annotated callouts over a screenshot — DEPOSIT ITEMS ("move items to the center of the
boat"), FUEL STATION ("refuel the boat before traveling"), REPAIR STATION ("repair the boat to keep it
in good condition").

**Two things this changes:**

1. **The hint wording gets more precise.** The image says the drop-off is the **centre area** of the
   boat, not just "the boat". The banner copy should match the sign a player may already have read —
   two different phrasings for one mechanic is worse than either alone.
2. ⚠️ **The board's aspect ratio has to change.** The image is roughly **16:9**; the `Survive` board is
   `8 × 3`, i.e. **2.67:1**. Dropping this image onto that board letterboxes it with dead wood above
   and below, or crops the callouts off. A board near **1.7:1** — e.g. `10 × 5.9` — shows it whole.
   That is a bigger sign than `Survive`, which is appropriate: this one is meant to be read, not
   glanced at.

Still needed from the user: **the final position.** Claude places it as a starting point only.

## Open questions for the plan phase

1. **Wording.** Concrete copy for both hints, matching the supplied sign's language — it says "deposit
   in the CENTER area", so the pickup hint should too.
2. **Does the banner need an icon and sound?** `Announce` already supports both; a teaching beat
   probably wants to feel different from a zone crossing.
3. **Timing on the pickup hint** — immediately on pickup, or a beat later so it does not collide with the
   pickup feedback already on screen (the `HandsFull` card appears at the same moment)?
4. **Does the sign carry a text header as well as the image**, or image only? The image already
   contains its own title, so a wooden header saying the same thing twice would be noise.
5. **Should the second hint also fire for a player who has never deposited but joins a crew mid-run?**
   (It is per-player and profile-backed, so yes by default — worth confirming it is not surprising.)

## Out of scope

- Any other onboarding gap (turret, medic station, untie, drop). Real, but this job covers the cargo
  loop only — a wider audit would be its own job.
- The LOBBY place.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
