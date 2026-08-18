# Job #098 — Final summary

**Project**: `roblox.jungle` · **Place**: GAME (`sync/`) · **Status**: complete
**Studio**: `Last River COOP Game`, PlaceId 138141472932347

Intake: [intake.md](intake.md) · Plan: [implementation-plan.md](implementation-plan.md)

---

## 1. What shipped

**The problem:** players did not know loot could be carried to the boat, so they never discovered the
resource economy — or the rear stations it pays for.

Three pieces:

1. **A reusable one-shot hint system** (`Progression/Hints.luau`) — id, trigger, message, seen-flag.
2. **Two hints**, fired at the moments they teach:
   | id | when | title | subtitle |
   |---|---|---|---|
   | `carryToBoat` | first resource pickup, ever | CARRY IT TO THE BOAT | Deposit it in the centre area of the deck |
   | `fuelAndRepair` | first successful deposit, ever | FUEL & REPAIR | Load fuel and mend the hull at the stations on the rear deck |
3. **`BoatInfoSign`** in the landing zone, carrying the user's uploaded infographic.

Copy deliberately echoes the sign ("deposit in the center area", "fuel station", "repair station") so a
player who reads the board and then sees the banner meets the same words, not two vocabularies for one
mechanic.

## 2. Design decisions worth keeping

**Once ever, not once per run.** The seen-set lives on the persistent profile, so a veteran on their
50th run is never re-taught. `ProfileConfig.default()` gained `seen = {}`; `migrate()` fills it
additively, so no migration and no risk to existing profiles. **Applied to both trees** (agreed via
wizard) — the two copies back one DataStore and are still byte-identical.

**Its own remote, not `Announce`.** `Announce` is owned by `ZoneServer`, fired `FireAllClients`, and its
own comment reserves it for rare crew beats. A hint is per player — routed through it, one newcomer's
tutorial would land on all six crew screens. `HintBanner` is separate and fired `FireClient`;
`ZoneBanner` renders both through one `showBanner`, because a hint should *look* identical, just carry
different words.

**Guards at the call sites, not in the module.** The pickup hint sits *after* the weapon/ammo early
returns (those crates grant instantly and are never carried — firing there would tell the player to
deliver something they are not holding), and the deposit hint sits *after* the cargo-full early return,
so a refused deposit never teaches a lesson that did not happen. The pickup hint is delayed 0.6 s so it
does not compete with the HandsFull card and pickup sound landing on the same frame.

## 3. Two real bugs the verification caught

Both were found by measuring rather than by reading the code, and neither was in the original plan.

**a) "Fails toward teaching" was failing toward spamming.** `Profiles.hasSeen` deliberately returns
false when no profile is available, so an unlucky player still gets taught. But that check runs on
*every* pickup — so with no profile the banner fired on every single crate. Found immediately in Studio,
where no profile loads at all (`isReady = false`, no DataStore access). Fixed with an in-memory session
set as a second guard, so the worst case is "once per session" rather than "once per crate".

**b) The module created a duplicate RemoteEvent.** `Hints.luau` built `HintBanner` with a bare
`Instance.new`. Requiring it from a second Luau VM made a **second** remote: the server fired through
one, the client listened to the other, and every banner silently vanished — 0 received where 2 were
expected. Fixed with find-or-create. A module that makes an Instance as a side effect duplicates it
whenever it is required from another VM, and that is worth avoiding generally, not just for the test.

## 4. Verification

**Hints** — instrumented the client with a counter on a Player attribute (the two datamodels do not
share Luau state, so module internals cannot be read across):

| fired | received | |
|---|---|---|
| `carryToBoat` × 5, `fuelAndRepair` × 2, unknown id × 1 | **exactly 2** | PASS |

Unknown ids warn without erroring. `HintBanner` instance count stays at 1 even after a second require.

**Sign** — read-back *and* screenshot, per the standing rule:
- Posts bottom at **y = 18.0**, exactly the terrain height under it (raycast-derived, not guessed).
- **0 overlapping parts.**
- Board **10 × 5.9 = 1.69:1**, matching the image, so nothing is letterboxed or cropped.
- Two captures: at ~20 studs it reads as a board; at ~8 studs **every step and callout is legible**,
  which is the right result for a walk-up sign.
- Camera reset to `Custom` afterwards so Edit navigation is not left locked.

`luau-analyze.sh` clean (it caught one type-narrowing error mid-work).

## 5. Files changed

| File | Change |
|---|---|
| `sync/ServerScriptService/Progression/Hints.luau` | **new** — the hint system |
| `sync/ReplicatedStorage/Progression/ProfileConfig.luau` | `seen = {}` + additive migrate |
| `lobby/sync/ReplicatedStorage/Progression/ProfileConfig.luau` | identical (shared DataStore, agreed) |
| `sync/ServerScriptService/Progression/Profiles.luau` | `hasSeen` / `markSeen` |
| `sync/StarterPlayer/StarterPlayerScripts/UI/ZoneBanner.local.luau` | renders both channels |
| `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` | the two call sites |
| *(Studio)* `Workspace.SpawnBase.sign.BoatInfoSign` | **new** editor Instance |
| `roblox.workspace/Assets/registry/images.md` | registered `BoatInfo` `113207367236651` |

## 6. Over to you

**The sign's final position.** It is at `-228, 24.5, -307`, 37 studs from spawn on the line to the dock,
facing back at arriving players, beside the existing `Survive` sign. That is a starting point — drag it
where you want it. It is a **real editor Instance**, not script-generated, precisely so your move sticks;
anything built at runtime would be rebuilt at its scripted spot every run.

Minor: some foliage grows in front of the lower posts at the current spot. Cosmetic, and moot once you
reposition it.

## 7. Not verified here

Persistence itself. Studio has no DataStore access in this session (`Profiles.isReady = false`), so
"once **ever**" is proven only as far as "once per session" — the session guard is what was exercised.
The profile path is a two-line read/write against an already-working store, but it is untested until it
runs on a live server. Worth one check on the next real playtest: pick up a crate, leave, rejoin, and
confirm the banner does **not** return.
