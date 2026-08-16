# Job #084 — open follow-ups

Raised during the 2026-08-16 playtests. ✅ = done in this job · ⬜ = not built.

> **Dropped 2026-08-16 at the user's call:** *deposit from the pier*. Not wanted — deposits stay a
> boat-side action. Do not re-raise it from the playtest notes.

---

## ✅ 1. Drop what you are carrying, where you stand — BUILT


**Reported:** *"we need to be able drop if you something holding, then it drops where you stand."*

Carrying sets `Busy`, disabling the gun AND the axe, and the only exit was a successful deposit — so a
full cargo deck could soft-lock a run outright.

**Input (user's call):** the HANDS FULL chip **is** the drop button, plus `G` on desktop. Putting it on
that card was deliberate — the card only exists while carrying and already states the problem, so the
thing telling you you are encumbered is the thing that un-encumbers you. It also dodges the prompt
collision a world prompt would cause: the crate rides on your head, inside the Deposit prompt's 26-stud
reach and on top of camp LootPrompts.

**The dropped crate stays RE-LOOTABLE (user's call)** — `DroppedCrate` with its own `LootPrompt` (0.4 s
hold, quicker than a camp crate's 1.2 s: you already earned this one). Nothing is destroyed, so you can
stage a haul by the pier and ferry it aboard in trips, and a mis-tap costs seconds not the whole crate.

⚠️ **The dropped crate is ANCHORED and non-colliding.** A dynamic crate slides off the deck the moment
the boat turns, and rolls into the river on a bank. Non-colliding because a solid crate underfoot on a
14-stud-wide deck is a snag hazard.

`ExcursionServer` — `DropCarried` RemoteEvent (no payload; the server decides entirely from its own
state), `makeDropped`, `dropCarried`. Clears all three of `carrying[player]`, `Busy`, `char.Carrying`.

## ✅ 2. The held weapon / torch drifts off the boat — FIXED (first hypothesis was WRONG)


**Reported:** *"weapon and lamp flys away from boat when move, they are like drifting."*

⚠️ **My first diagnosis was wrong and is recorded so it is not repeated.** I blamed the parent-after-weld
ordering at `InventoryService:237-241`. But `makeCarried` in `ExcursionServer` builds its weld in exactly
the same order and the carried barrel rides perfectly — so ordering was not it.

**The real difference is WHAT is being welded to.** The carried crate welds to `HumanoidRootPart`. The
held item welds to `RightHand` — an **animated** limb, moved every frame by the Animator through the
rig's Motor6Ds. A `WeldConstraint` is a physics constraint resolved by the solver, so it is permanently
chasing a limb whose motion comes from somewhere else. Put that character on a moving platform and the
error becomes visible drift.

**Fixed with a `Motor6D`** — the engine's own mechanism, and exactly how a Roblox `Tool` attaches its
Handle (the "RightGrip" Motor6D). It IS a rig joint, transformed by the animation system alongside the
limb instead of catching up to it. `C0` is solved from the live CFrames so all of Job #079's
`holdInChar` pose work survives untouched.

⚠️ **Not yet confirmed in Play** — Studio was in Edit mode when this was written, so it could not be
measured live. If it still drifts, check network ownership next (a server-created loose part beside a
client-owned character can end up server-owned, which looks identical).

## ⛔ 3. Bandages have no world source — CLOSED, no change wanted


User's call: **leave it shop-only.** 3 at run start (`PlayerCombat:17`), 50 Salvage each at the village
trading post, no world drops. Scarcity is intended. Do not re-raise from the playtest notes.

## ✅ 4. Docs debt — CLEARED


`final-summary.md` written for **072, 076, 078, 080, 081, 082, 083**. All were built; only the write-up
was missing. Each is marked as reconstructed retroactively, with the code named as authoritative where
it disagrees with a stale intake.

Jungle is now **84/84 jobs documented**. (Defender still has 19 open — a separate backlog.)

Two carry real outstanding caveats, restated so they are not lost:
- **#081** — the boat wake has *never* been watched at speed on open water; driving in Studio kept
  beaching the boat. Rates are measured, the look is not.
- **#082** — ramps render as a `WedgePart`; the real Meshy art awaits credit approval.

## ✅ 5. "Deposited X" message, visible to every player — BUILT


**Style (user's call):** a small stacking corner toast — `CrewToast.local.luau` (new) fed by a
`CrewToast` RemoteEvent from `ExcursionServer`. Reads *"Janis deposited 1 Gasoline · 4/25"*, fired to
**all** clients because the hold is shared, so a deposit is crew news.

⚠️ **Deliberately NOT the `Announce`/`ZoneBanner` channel**, even though reusing it would have been
free. That is a large centre-screen banner with a HOLD, tuned for rare beats (zone crossings,
NIGHTFALL). A deposit fires several times per landing — reusing it would nag AND stomp the real zone
announcements it exists for. Same server→all-clients *shape*, own lightweight presentation.

Bottom-right, stacking upward, 3 slots with the oldest recycled. Bottom-right because the left column is
fully spoken for: hotbar 0.865–0.975, health 0.803–0.845, HANDS FULL 0.761–0.797, RoleChip 0.42.

## ✅ 6. Deposit silently did nothing — FIXED (first diagnosis was WRONG)

**Reported:** *"i sometimes deposit and nothing happens."*

⚠️ **I first blamed a full cargo deck and was wrong** — the user challenged it, and the live boat read
`Gasoline=0 Metal=0 Ammo=3, CargoMax=25`. Nowhere near full. Recorded because the wrong answer was
plausible and cost a round trip: the bare `return` on the full-cargo branch *looked* like the culprit
without anyone checking whether that branch could even be reached.

**The real cause, measured live.** The prompt hangs off `hull`, so it is anchored at the boat's CENTRE
with `MaxActivationDistance = 16`. But the boat is much bigger than the hull part:

| Measured | Value |
|---|---|
| `hull.Size` | 14 × 3 × 32 |
| Boat bounding box | 14.7 × 11 × 46 |
| Furthest **collidable** part from hull origin | **23.0 studs** |
| Prompt reach | **16 studs** |

So the outer ~7 studs of walkable deck — bow and stern — sat outside the prompt completely. The
reporting player was at **14.3 studs**, right on the edge. Intermittent for two compounding reasons:
where you stand decides whether it responds at all, and with a 0.5 s hold, one step mid-hold crosses
the boundary and cancels silently.

**Fixed:** reach raised to 26 (covers the measured 23 with margin for deck roll).

Kept as well, since it is a correct guard even though it was not the bug: the prompt now reads
**"Cargo FULL"** when the deck really is full, refreshing on `Gasoline`/`Metal`/`Ammo`/`CargoMax`.

## ✅ 6b. Dying while carrying disarmed you for the rest of the run — FIXED

Found while investigating the above. **Nothing cleared `carrying` or `Busy` except a successful
deposit** — the file had no `CharacterAdded`/`CharacterRemoving`/`PlayerRemoving` handler at all. On
death: the carried model died with the character, but `carrying[player]` kept pointing at the destroyed
instance (still truthy in Luau, so the "already carrying" guard blocked every future pickup), and
`Busy` is a PLAYER attribute so it survived respawn — leaving the new character permanently unable to
shoot or swing, "HANDS FULL" showing, and no crate to explain it.

Now cleared on character removal, character add, and player removal.

⚠️ Neither fix unsticks a **full** deck — that still needs the drop action in item 1.

## ✅ 7. Damage numbers were invisible — FIXED

**Reported:** *"decals is not flying when i hit or i am hit."*

Not a logic bug — the pipeline was working the whole time. Read live from the running client: 19 of 20
pooled parts had moved to real hit positions with real damage values in their labels (`8, 15, 18…`).

The cause was my own design call: `AlwaysOnTop = false` with **no** `StudsOffset`, on a billboard that
spawns at the *exact impact point* — i.e. inside the body of whatever you just hit, so it z-failed every
time. Now `AlwaysOnTop = true` with a 2.5-stud lift, a larger 110×40 box, and brighter world-space
colours (`Theme.color.green` is a dark olive tuned for flat UI behind a scrim; it read as mud over
sunlit water).

## ✅ 8. Campfire heal rate lowered to 2.5 HP/s

Shipped at 4.0, which **out-healed the boat's Medic station** (3 HP/s, `RoleServer:17`, Job 057) while
also working solo and ashore — making the dedicated Medic role pointless. Now 2.5, so the station stays
the best heal in the game and the fire is the off-boat fallback. Contested rate unchanged at 1.0.

## ✅ 9. "HANDS FULL" chip overlapped the health bar — FIXED

Moved from y=0.855 to y=0.797. Confirmed clear in a playtest screenshot.
