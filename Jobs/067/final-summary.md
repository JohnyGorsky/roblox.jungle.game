# Final Summary — Job #067

**Project**: `roblox.jungle`
**Completed**: 2026-08-01
**Status**: ✅ Completed — **two Creator Hub items outstanding, see below**

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
meshes were commissioned instead (`SearchlightMast`, `CargoRacks`, `RampBow`); `BoatParts` now names them,
so the stand-ins vanish automatically on import. **`size` is deliberately left unset on all three** so they
arrive at natural scale and the boat is fitted around them, rather than stretching art to fit a host.

## Files changed

**New** — `ReplicatedStorage/Boat/BoatPaint.luau` (both trees) · lobby `Progression/PaintServer.server.luau` ·
lobby `UI/PaintShop.local.luau` · game `UI/DownedHud.local.luau`
**Changed** — `MonetizationDefs` · `MonetizationServer` · `ProfileConfig` · `Profiles` · `ModuleDefs` ·
`BoatParts` (both trees) · `BoatModules` · `BoatServer` · `RampTest` · `PlayerCombat` · `ItemDefs` ·
`InventoryService` · `InventoryHud` · lobby `LobbyBoat` · lobby `Theme` · lobby `RobuxShop` · lobby
`EntryBar` · `GAME.md` · `ASSETS.md` · registry `images.md`

## Verification

- [x] Analyzer clean on **both trees** after every change; all shared modules verified byte-identical.
- [x] **Paint proven in a running Play session, not by inspection** — livery applied, stock ColorMap
      destroyed, `PaintablePBR` retained with Normal + Roughness intact, and the hull measured at the exact
      livery RGB. Screenshot confirms deck/engines/seats untouched.
- [x] **Round-tripped**: `olive → navy → olive` restores the authored art exactly (the rebuild clones a
      fresh skin), and a **hostile value** (`"notacolour"`) sanitizes to the default instead of erroring.
- [x] Library prep verified present on `Hull` and `HullPlate` after returning to Edit.
- [x] Camera reset to `Custom` after the screenshot.

### Not verified — stated plainly

- **The downed overlay and self-revive have not been exercised in-world.** They live in the GAME place,
  which wasn't open; the receipt path also can't run unpublished. The grant logic is guarded so a failed
  grant retries rather than charging, but the UI itself is unproven.
- **Armour plates repainting** is the same name-set code path as the hull and analyzer-clean, but wasn't
  seen in-world — it needs a player who owns `hullkit`.
- **The ramps module's handling change hasn't been felt**, only wired. It rides on the same untested
  re-tune as Job 066's hull-length change.

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

Importing the 15 GLBs into the **game place**, and **re-testing boat handling** after the hull grew
22 → 32 studs — now with the `ramps` module's handling multipliers on top.
