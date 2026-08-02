# Final Summary — Job #067

**Project**: `roblox.jungle`
**Completed**: 2026-08-02
**Status**: ✅ Completed — **closed 2026-08-02.** Scope delivered in full; see *Outstanding* and *Not verified* for what deliberately did not fit inside this job.

Audited whether `SkillDefs` / `ModuleDefs` / `MonetizationDefs` actually deliver the progression `GAME.md`
describes, then built every gap the audit found. All four findings are closed.

## What the audit found, and what was done

| # | Finding | Outcome |
|---|---|---|
| 1 | **Two live passes delivered nothing** — Boat Paint (99 R$) and Cosmetic Bundle (249 R$) were on sale with no implementation anywhere | Paint **built**; Cosmetic Bundle **removed from the in-game shop** |
| 2 | **Armored Boat sells power**, contradicting a pillar `GAME.md` states twice | Pass **kept** (user's call) and `GAME.md` now records it as a named, reasoned exception instead of quietly contradicting itself |
| 3 | `GAME.md` promised a **ramps / hull-shape module** that didn't exist | **Built** as the `ramps` module |
| 4 | **Paid self-revive** and **extra inventory slots** were promised and missing | **Both built** |

Skills came out clean — 10 skills, all implemented and levelled, no gaps.

## 1. Boat Paint Pack — 6 hull liveries

`olive` (free for everyone) · `graphite` · `sand` · `navy` · `jungle` · `rust`. Chosen in a lobby swatch
picker; the player's **moored showroom boat repaints while they watch**. Applied to the game boat too, on
the hull *and* its armour plates, so the two never disagree.

### The part that mattered — and cost a debugging cycle

An opaque `ColorMap` on a `SurfaceAppearance` **completely overrides `BasePart.Color`**, so the obvious
implementation is invisible. Clearing the ColorMap fixes that — and:

> **⚠️ `SurfaceAppearance.ColorMap` cannot be written by a game script.**
> *"The current thread cannot write 'ColorMap' (lacking capability Plugin)"* — the same runtime gate as
> `MeshPart.MeshId` and `CollisionFidelity` (Job 066).
> **It DOES succeed from the Studio command bar**, which holds plugin capability. I verified it there
> first, concluded it worked, and only found out when the real server script threw and took the whole
> lobby boat build down with it.

The fix keeps the good result rather than settling for flat colour: `BoatParts.preparePaintLibrary()` is an
**authoring-time** pass that gives each paintable library mesh a *second* appearance, `PaintablePBR` —
identical but with an empty ColorMap. `BoatParts.skin()` clones it along with everything else, and at
runtime a livery merely **destroys the appearance it doesn't want**, which needs no capability.

So Normal + Roughness + Metalness survive the repaint: the hull keeps every rivet, panel line, dent and
wear-polished patch. It reads as repainted, not as replaced with plastic. If the prep was never run the
code degrades to flat colour and warns once — visibly worse, never broken.

**No new textures were needed**, which is the reason this shipped in one job.

## 2. Cosmetic Bundle — removed in-game

Dropped from `MonetizationDefs.GamePasses`, so it disappears from the Robux shop in both places and
`MonetizationServer` stops publishing `Owns_cosmeticBundle`. Trails / wake FX / emote remain unbuilt.
**The Creator Hub listing is unlisted by hand — that part is not done here** (the user's explicit call:
*"do not unlist it now, just remove in game"*).

## 3. Armored Boat — kept, documented

No code change. `GAME.md` gained an explicit exception block: what it is, that it's the **only** power item
we sell, and why it's tolerated — the buff is **crew-wide**, so one buyer helps everyone aboard, which
reads as "someone brought good gear" rather than a solo advantage. Plus a full table of everything we sell
and whether each item is fair.

## 4. `ramps` — Ramp Bow & Hull Shape (170 Gold)

Wired to code that already runs, so it's felt today rather than being a placeholder:

- **`RampBoost` 1.35** — read by `RampTest` when it applies a launch. Applied *before* the launch cap, so
  the module can't overshoot what the arc and landing were tuned for. Real ramps are still todo `0013`;
  this works the moment they land.
- **`TurnAuthorityMul` 1.2 / `CurrentMul` 0.85** — the always-on half. Full rudder authority arrives at a
  lower speed and the downstream shove drops, so the boat holds a line through The Rapids. Divides the
  speed threshold rather than raising `TURN`, so it sharpens low-speed handling without raising top turn rate.

Visible bow ramp, now a real mesh (`RampBow`, imported 2026-08-02). It's `paintable`, so it repaints with
the hull. ⚠️ It imported with a **square footprint** — as deep as it is wide — so at 8 wide it is also 8
deep, which the 5 studs of bow ahead of the gun mount cannot hold. It therefore rides low (`y 0.96…3.24`)
and passes **under** the gun base (`y 3.8…5.8`), overhanging the bow by 3 studs like a landing-craft ramp.

## 5. Extra Inventory Slots (149 R$) — 4 → 6

`ItemDefs.SLOT_COUNT` was a hard constant read in three places. It's now the **base**, with
`ItemDefs.MAX_SLOTS = 6` and `ItemDefs.slotsFor(player)` as the single source of truth.

Two things that would otherwise have broken:
- **Seeding writes all `MAX_SLOTS` attributes**, not the player's current count — the pass check is async
  and can land mid-session, and nil slot attributes would render as holes in the hotbar.
- **The hotbar builds all 6 buttons and hides the surplus**, and redraws on `Owns_extraSlots` changing,
  because that attribute arrives after the HUD has already drawn.

## 6. Paid self-revive (20 R$ dev product)

`PlayerCombat` had the hook point commented since Job 008: `-- no self-revive (that's the paid revive, P8)`.

- Bought **from the downed overlay while bleeding out**, not stocked in the lobby.
- Revives at exactly the HP a teammate's bandage gives (no Combat Medic bonus), and is usable **only while
  downed** — so it can never be a combat advantage. Convenience, not power.
- `ProcessReceipt` grew a non-gold branch that hands off through a `GrantProduct` BindableFunction. **If
  nothing can honour the grant — the lobby, an already-revived player, a corpse — the receipt returns
  `NotProcessedYet` and Roblox retries.** The player is never charged for nothing.

### The downed overlay is new, and was overdue

Going down had **no client UI whatsoever**: you stopped being able to move, with nothing saying why or how
long you had. There is now a red vignette, a bleed-out countdown that pulses in the last 10 seconds, the
"a teammate can revive you" hint, and the paid button. Worth having on its own merits.

`PlayerCombat` publishes `BleedOutAt` as an `os.time()` wall-clock deadline — not `os.clock()`, which is
per-process and meaningless to the client that has to render the number.

## 7. Follow-ups raised by the user during the job

**The searchlight was standing inside the gun.** Measured, not eyeballed: the mount sits at `z −11` with a
barrel skin spanning `z −13.8…−8.3`, and the mast stood at `z −8.7` on the same centreline. It now stands
to port beside the helm, verified clear of the gun, driver and crew seats.

**Two lamps did the same thing.** The free bow light and the 120-Gold Searchlight module both pointed
straight ahead all night, so the module was worth +35 range and a little brightness — and `HasSearchlight`
was set but **read by nothing**, so it had no gameplay effect at all. The beam now **sweeps with the
mounted gun's yaw**, giving the gunner a night role and the module a reason to exist. Yaw only (following
elevation would point it at the sky); recentres forward when the turret is unmanned. The bow light stays
on regardless.

Driven kinematically from the hull CFrame like `GunServer` drives the barrel. `GunServer` publishes
`GunYaw` on the boat — only when it changes, since attributes replicate and a per-Heartbeat write would be
60 replicated writes a second for a usually-static value.

**Twin Motors had no art at all.** Spotted in a screenshot while checking the racks: `motor2`'s def was
`library = nil`, so a 150-Gold module rendered as a **raw dark greybox slab** in the engine bay, right next
to a fully modelled base engine — even though Job 066's summary and `ASSETS.md` both stated "Motor2 reuses
the Motor mesh". The mapping simply never pointed at it. **No part of the boat is greybox any more**,
verified by scanning for hosts that are still visible and have no skin.

**Invented greybox was removed as a practice.** The user's instruction — *"if you need models just say, do
not invent things"* — after I fabricated a grey mast, a grey rack frame and a grey ramp wedge. Three
meshes were commissioned instead and **imported 2026-08-02**: `SearchlightMast`, `CargoRacks`, `RampBow`.

Each is sized to its OWN natural proportions — **zero stretch on all three** — and the boat was moved
around them rather than the art squeezed into existing hosts:

| Mesh | Imported | Used at | Consequence for the boat |
|---|---|---|---|
| `SearchlightMast` | 0.45 × 1.20 × 0.45 | 1.70 × 4.53 × 1.70 | A stocky **pedestal**, not a mast — a 0.8-stud pole is what Meshy reconstructs worst |
| `CargoRacks` | 3.22 × 1.20 × 2.11 | 7.50 × 2.80 × 4.92 | Owns the **aft half** of the rear deck; all three role stations moved forward to `backZ − 2.5` |
| `RampBow` | 4.21 × 1.20 × **4.21** | 8.00 × 2.28 × 8.00 | **Square footprint** — as deep as it is wide, which the 5 studs of bow ahead of the gun can't hold, so it rides low and passes **under** the gun base, overhanging the bow by 3 studs |

Two corrections after seeing it in-world: the racks **floated** (the mesh sits ~0.7 high inside its own
bounding box — the same correction the deck stations needed in Job 066, and unmeasurable at runtime because
a skin can't be raycast), and the lamp sat **off-centre** on a post that is now 1.7 wide rather than 0.8.

## Files changed

**New** — `ReplicatedStorage/Boat/BoatPaint.luau` (both trees) · lobby `Progression/PaintServer.server.luau` ·
lobby `UI/PaintShop.local.luau` · game `UI/DownedHud.local.luau`
**Changed** — `MonetizationDefs` · `MonetizationServer` · `ProfileConfig` · `Profiles` · `ModuleDefs` ·
`BoatParts` (both trees) · `BoatModules` · `BoatServer` · `GunServer` · `CargoServer` · `RampTest` ·
`PlayerCombat` · `ItemDefs` · `InventoryService` · `InventoryHud` · lobby `LobbyBoat` · lobby `Theme` ·
lobby `RobuxShop` · lobby `EntryBar` · `GAME.md` · `ASSETS.md` · registry `images.md` · registry `meshes.md`

## Verification

- [x] Analyzer clean on **both trees** after every change; all shared modules verified byte-identical.
- [x] **Paint proven in a running Play session, not by inspection** — livery applied, stock ColorMap
      destroyed, `PaintablePBR` retained with Normal + Roughness intact, and the hull measured at the exact
      livery RGB. Screenshot confirms deck/engines/seats untouched.
- [x] **Round-tripped**: `olive → navy → olive` restores the authored art exactly (the rebuild clones a
      fresh skin), and a **hostile value** (`"notacolour"`) sanitizes to the default instead of erroring.
- [x] Library prep verified present on `Hull`, `HullPlate` and `RampBow` after returning to Edit.
- [x] **Every new mesh measured against the hull by AABB test in a fresh session, not eyeballed** — ramp vs
      gun base / barrel / bow light / hull, racks vs both stations, mast and lamp vs driver and gun: all
      clear. The one flagged contact (racks vs deck) measured **0.0000 studs** of interpenetration — the
      rack resting on the deck, which is correct.
- [x] **No part of the boat is greybox**, verified by scanning for visible hosts with no skin.
- [x] Mooring ropes re-measured after lengthening: 3.62 → **6.02**, now buried 0.86 into the transom and
      1.46 into the deck rather than stopping on both surfaces.
- [x] Camera reset to `Custom` after every screenshot.

### Not verified — stated plainly

- **The downed overlay and self-revive have not been exercised in-world.** They live in the GAME place,
  which wasn't open; the receipt path also can't run unpublished. The grant logic is guarded so a failed
  grant retries rather than charging, but the UI itself is unproven.
- **Armour plates repainting** is the same name-set code path as the hull and analyzer-clean, but wasn't
  seen in-world — it needs a player who owns `hullkit`.
- **The ramps module's handling change hasn't been felt**, only wired. It rides on the same untested
  re-tune as Job 066's hull-length change.
- **The searchlight's gun-tracking has not been seen running.** It is GAME-place code and Studio had the
  lobby open throughout; it also needs a night run with someone in the gunner's seat. The lamp's mesh is
  driven explicitly rather than trusting its weld, precisely because that path is unproven.
- **The ramp's underside sits 0.06 studs above the waterline.** Deliberate (the user asked for it lower)
  and it reads as a ramp meeting the water, but it will touch the surface when the boat pitches. Raise it
  ~0.5 if that reads badly in motion.

## Outstanding — needs the user

1. ~~Create the Extra Inventory Slots game pass~~ — ✅ **done 2026-08-02** (`1935044952`, 149 R$), wired in
   both trees and confirmed live via `GetProductInfo` (name and price match the code).
   ⚠️ Its icon is the **Hub thumbnail** (`130798210334331`) — the only row not using a transparent upload.
   Check it in Play; if it renders as a white blob in the round badge, re-upload with alpha.
2. **Unlist the Cosmetic Bundle** on the Creator Hub. It is out of the game; the listing is still up.
3. **Save the lobby place** — `PaintablePBR` is place content.
4. **Run `preparePaintLibrary()` in the GAME place** after importing the boat GLBs there (still carried
   forward from Job 066).

> Self Revive was likewise created during the job (`3612677893`, 20 R$) and confirmed live. It correctly
> uses the **transparent** upload `131281323216251`, not the Hub copy `124951966292519`.

## Carried forward from Job 066 (still open)

Importing the boat meshes into the **game place** — now **18**, not 15 — and **re-testing boat handling**
after the hull grew 22 → 32 studs, now with the `ramps` module's handling multipliers on top. The game
place is still fully greybox; `BoatParts` is byte-identical in both trees, so the art works the moment the
meshes land, followed by one `preparePaintLibrary()` run and a save.

## Lessons worth keeping

1. **The Studio command bar holds plugin capability; a game script does not.** Testing a gated property
   write there proves nothing — see the ColorMap story above.
2. **Rojo does not sync into a running Play session.** Edits made while Play is up land in the Edit tree
   only, so measuring the running session returns stale values. Stop → let it sync → restart. Cost two
   cycles here before it was recognised.
3. **`require` caches per Luau context**, including Studio's Edit session — `preparePaintLibrary()` kept
   skipping `RampBow` because the session held the pre-edit module. Requiring a **clone** bypasses it.
4. **Meshes sit high inside their own bounding boxes.** A box-flush base still reads as floating, and a
   skin can't be raycast, so this is tuned by eye every time. Third occurrence now (deck stations,
   cargo racks).
5. **Check the mesh's footprint before planning placement.** `RampBow` came back square when the bow needed
   wide-and-shallow, which changed where it could go, not just how big it was.
