# Job #084 — Final summary

**Four playtest bugs from 2026-08-16.** One turned out not to be a bug, one turned out to be worse than
reported, and two were design changes. Item 5 (hit feedback) stays with Job #080 and was not touched.

⚠️ **Status: built and statically verified; the Studio playtest is outstanding.** `tools/luau-analyze.sh`
is clean on every edited file and on the whole GAME tree, and all seven scripts are confirmed synced into
the *Last River COOP Game* place. The physics change in Part 2 cannot be settled by reading — see
**Still to verify** at the bottom.

## What shipped

### 1. The pistol was never broken — carrying disarms you

Confirmed with the user: the gate was `Busy`, set by `ExcursionServer.pickupLoot` while you carry a crate.
All four gates in `WeaponServer.canShoot` behave correctly. The failure was that a refused shot produced
**no output at all** — the reticle *hid itself*, which reads as a UI glitch rather than a rule.

- **`InventoryHud`** — the carry chip now reads **"HANDS FULL — CAN'T FIGHT"** instead of
  "HANDS FULL — CARRYING". The old text restated the crate already visible on the player's head and never
  mentioned the consequence.
- **`WeaponClient`** — the single `localCanShoot()` is split into `seatedAtStation()` / `blockedByCarry()`
  / `reticleShown()`. Seated or unarmed still hides the reticle (the hotbar hides there too, so the whole
  loadout UI goes together); **carrying now shows it in yellow** instead. Yellow outranks the ammo colour,
  so a full magazine can't show red and send the player hunting for ammo they have.
- **`WeaponClient` / `MeleeClient`** — a blocked trigger pull or swing now plays `emptyClick` (already
  debounced 0.3 s) and pulses the reticle, matching the answer the empty-ammo path has given since #075.

**Also fixed while in there:** `WeaponServer` stamped `lastShot[player]` *before* its gates, so a rejected
attempt consumed the rate-limit window and left the player briefly rate-limited after putting the crate
down. Moved after `canShoot`. **Deviation from the plan:** it is stamped *before* the ammo check, not
after both gates as written — the dry-fire click is a real server-side Sound and does need rate limiting.

### 2. The tied boat: an anchor that should never have been there

The report was "riders slide on a tied boat". The cause is worse than the symptom: `DockServer` tied by
setting `hull.Anchored = true`, and `StagingServer`'s header documents that exact anchor→unanchor-with-
riders-aboard transition as the old **"boat disappears"** bug. It was live at all 11+ streamed river docks.

Docks now moor the hull the way the spawn dock has always moored it:

- `SetNetworkOwner(nil)` + a **`LinearVelocity` in `Plane` mode** with a Heartbeat correction loop, eased
  inside 0.3 studs. Hull stays dynamic, so Roblox's native moving-platform carry keeps working — which is
  what stops the sliding, and keeps the project rule against a manual per-frame rider carry intact.
- ⚠️ **Not an AlignPosition**, despite what the approved option said. That wording came from
  `StagingServer`'s *header*, which is stale; the real code at `:141` is a LinearVelocity, and the comment
  above it explains why — plane mode never touches Y, so buoyancy alone owns the float. An AlignPosition
  fights buoyancy on Y and bounces.
- **Moored where it floats, not at the pier.** `TiePrompt` fires anywhere within `REFUEL_RANGE` (65
  studs); holding at the dock centre would reel the boat across the river on one keypress. Freezing the
  current spot is what the anchor did, so tie *feel* is unchanged.
- **The rope got slack (`ROPE_SLACK = 3`).** It was decoration only because anchored parts ignore
  constraints. A dynamic hull makes it load-bearing, and `StagingServer:186` records this exact thing
  going wrong once already — *"the rope was actively harmful (it is what suspended the boat above the
  waterline)"*.
- **`BoatServer` now checks `Tied`** — it never did, because against an anchored hull its forces were
  inert. They are not inert against a hold: a driver holding W would fight it. A tied boat now ignores the
  helm, stops integrating the rudder, and burns no fuel. Buoyancy is computed earlier in the loop, so it
  still floats and bobs.

### 3. Enemies disengage while the boat is tied

Half of this already worked — a tied boat took no hull damage — but the crew standing on deck was still
being bitten and creatures still milled around the hull, which is what read as "they attack even when
tied". In `EnemyServer`:

- `chasing` now requires `not suppressed`, so creatures settle to **idle in view** rather than closing.
- The bite is gated at the call site, so the crew stops being bitten. `applyBite`'s internal tie check is
  gone as a result — replaced by an explicit `canHitBoat` flag (see below).
- Land creatures fall into their existing return-to-anchor branch for free and slink back to the bank.
- Re-aggro is automatic: `chasing` recomputes per frame and `st.roared` resets, so untying replays the roar.
- **Camp guards untouched** — `ExcursionServer`'s `CampGuard`s are a separate system `tickEnemy` never
  drives, and they stand at camps, not docks.

### 4. Sea creatures hunt swimmers

`nearestPlayer` was never the problem (it excludes only `Downed`). The hole was targeting: every sea enemy
chased `hull.Position`, so a swimmer was only ever bitten by standing next to the boat.

- Sea creatures now target the **nearer of {boat, nearest swimmer}**; land creatures stay on the boat
  since they're leashed to a bank anchor and can't cross open water anyway.
- The swimmer list is rebuilt **once per Heartbeat** before the enemy loop, not per enemy — the answer is
  identical for all of up to 10 sea creatures.
- Lead prediction follows the target's own velocity; leading a swimmer on the boat's velocity would aim at
  open water. No `FLANK_DIST` offset against a person — that exists to stop crocs surfacing under the
  hull, and against a swimmer it would make them circle instead of close.
- `CULL_BEHIND` still measures from the boat, so a swimmer heading upstream can't keep creatures alive
  indefinitely behind the run.
- **`applyBite` gained `canHitBoat`.** Without it, a croc that lunged at a swimmer who slipped out of range
  would find no victim and fall through to damaging a hull 200 studs away.

### A3 — the contradiction the two decisions created

Decisions 3 and 4 conflict for a swimmer beside a tied boat. Resolved with one constant rather than left
to emerge in play:

> **`TIED_SAFE_RADIUS = 55`** — while tied, sea creatures neither approach nor bite anything within that
> distance of the hull, boat or swimmer. Outside it, normal targeting resumes.

The dock is genuinely safe; swimming away from it genuinely isn't. This is the lever if docks play too
generous (lower) or the safe zone feels stingy (raise).

## Files changed

| File | Change |
|---|---|
| `World/DockServer.server.luau` | Anchor → `LinearVelocity` moor + hold loop; rope slack |
| `Boat/BoatServer.server.luau` | Tied boat ignores the helm (required companion) |
| `Enemies/EnemyServer.server.luau` | Swimmer targeting, tied-dock suppression, `canHitBoat` |
| `Combat/WeaponServer.server.luau` | Rate-limit stamped after the gates |
| `Combat/WeaponClient.local.luau` | Split gates; yellow reticle + pulse on a carry-blocked shot |
| `Combat/MeleeClient.local.luau` | Click on a carry-blocked swing |
| `UI/InventoryHud.local.luau` | Carry chip names the consequence |

## Still to verify (human, in Studio)

Static analysis is clean and the scripts are synced, but none of the following can be read off the code:

1. **Part 2 is the risky one.** Tie with a player on deck → confirm no slide. Then **untie with the crew
   still aboard** — that is the transition `StagingServer` warns explodes, and the whole point of the
   change is that it no longer exists. Watch the bow through several bobs to confirm the rope stays slack.
2. Hold W while tied → the boat must not creep off its berth.
3. Tie at a river dock → creatures stop closing, stay visible, and re-aggro on untie.
4. Swim clear of the boat → you are hunted. Swim beside a **tied** boat → you are not.
5. Part 1 is a read-and-feel check: does the yellow reticle plus the chip actually land at speed?
