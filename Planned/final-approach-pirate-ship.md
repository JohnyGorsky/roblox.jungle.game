# Final approach: a pirate ship that shoots back

**Source:** the owner, during Job #121's intake (2026-08-27), in their own words:

> *"ship as asked. But we will have pirate ship later, that will shoot back, but that other task"*

**Depends:** Job #121 (the sea gauntlet + the end-zone garrison) — this is the answer to the one thing
that job could not deliver.

## The problem this exists to solve, stated from the code

Job #121 shipped the owner's requirement 1 as asked: a **×3 sea surge over the last 800 studs** before the
end zone (`EnemyServer.FINAL_SURGE_FROM` / `FINAL_SURGE_MUL`), verified in Play at 16 concurrent sea
creatures solo against a baseline of 2. The intent behind it was *"so last camp counts — how many bullets
you have"*.

**The surge does not, on its own, cost the player any ammunition, and the numbers say so:**

| | speed |
|---|---|
| Crocodile | 15 |
| RiverHippo | 10 |
| Piranha | 22 |
| **The boat, full throttle** | **~30** |

`EnemyDefs`' own comment on the crocodile states the design outright: *"slower than the boat's top (~30) so
full throttle escapes; still catches a dawdler"*. And `EnemyServer.CULL_BEHIND` (260) deletes anything the
boat outruns. So the optimal line through the surge is **full throttle, fire nothing** — roughly 27 seconds
and zero rounds spent. Raising a concurrent-creature ceiling adds crocodiles that get culled off the stern.

Raised by the independent reviewer on Job #121, put to the owner, and answered: ship the ×3 anyway (the
run-in reads as dangerous, and `FINAL_SURGE_MUL` is one number to dial), **and solve it properly with a
ship that shoots back.**

## Why a shooting enemy is the right shape

A threat only costs ammunition if it cannot be answered with the throttle. Two ways to force that, and the
ship is the better one:

1. **Out-range the boat** — anything that can hit you from beyond your escape window has to be shot at or
   endured. A hull-damaging cannon does this without touching creature speeds.
2. **Slow or stop the hull** — a blockage, a grapple, a rammed broadside. Also works, but "the river is
   blocked" is a puzzle, not a firefight, and the game already has `LogJam`/`ObstacleServer` for that idiom.

A ship additionally gives the finale a **silhouette** — the run currently escalates from wildlife to
wildlife, and the only humans you fight are stationary camp garrisons. A moving, firing, crewed enemy vessel
is the first opponent in the game that is *doing* something rather than *guarding* something.

## Scope sketch (not agreed — this is a starting point)

- A vessel on the channel in the final approach, in front of or alongside the crew, that **fires at the
  hull** from outside crocodile range.
- Its shells must be **answerable**: a telegraph the driver can steer around, or a gun the gunner can
  suppress. The Bazooka's existing red `GroundRing` + 4-second arc (`Combat/Rocket.luau`,
  `ReplicatedStorage/Combat/GroundRing.luau`) is a proven telegraph and would be the obvious reuse.
- Killable — the mounted turret (`GunServer`) should be the right tool, which finally gives the **gunner
  station** a set-piece of its own. Roles are a core pillar and the gunner currently has no scripted moment.
- **Hull damage is the pressure**, so the repair station matters too.

## 🔴 Two hard constraints this job must respect

1. **The boat has 100 max HP** (`BoatServer:267`) and `Workspace.BoatDestroyed` is one of `RunServer`'s two
   LOSE arms, with no timeout and no abandon. A ship that out-damages the repair station is not "hard", it
   is a run deleted 800 studs from the win. Job #121 had to exempt the hull from wildlife bites and from
   enemy rocket blasts **inside the end zone** for exactly this reason (see `EnemyServer.applyBite` and
   `Rocket.enemyBlast`); this job needs its own answer for the approach, where no such exemption applies.
2. **`TIED_SAFE_RADIUS` (55) makes a tied boat immune to wildlife, and the last camp at z = 17600 sits
   inside the surge window.** Job #121 had to gate the surge on `not Tied` to stop 30-odd creatures parking
   in an idle ring around a moored crew. A ship needs the same question answered: what does it do while the
   crew is tied up at the last camp — wait, blockade, or shell the mooring?

## Open questions for intake

- Does it **chase** the crew downstream, hold a position (a blockade at the mouth), or pass on an opposing
  course?
- One ship per run at a fixed point, or a possibility on the approach?
- Does it **board** — raiders onto the deck — or purely shell from range?
- Does killing it drop anything, and does it interact with the end-zone garrison 800 studs later?
- Asset: is this a Meshy generation, a Creator Store vessel, or built from `BoatParts`?
  (`roblox.tide` has a whole vessel system — worth a look before generating anything.)
