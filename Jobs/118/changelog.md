# Job #118 — Changelog

**Bazooka — arcing rocket launcher, sold as a lifetime pass or a per-run purchase.**

## Added
- **The Bazooka**, the game's first projectile weapon. One trigger pull lobs a rocket along a visible arc
  that lands on the point you marked after exactly **4 seconds** and blasts a **30-stud radius for 300
  damage**, falling to 25 % at the rim. Max target distance **300 studs**; **5-second reload**; **6 rockets
  a run** with no way to get more.
- **A red ground ring**: your own aim preview while the weapon is held, and a public pulsing marker at the
  locked impact point for the whole 4 s of flight, sized to the real blast radius so the crew can clear out.
  It doubles as the reload indicator, fading from grey back to red as the reload completes.
- **Impact blast**: flash, expanding shockwave ring, debris and smoke, a brief light, and a distance-chosen
  impact sound — the close variant plays 2D so "it went off on top of me" reads correctly.
- **Sold in both Robux shops**: *Lifetime Bazooka* (pass `1956512376`, 250 R$) and *Bazooka (one run)*
  (product `3709767468`, 80 R$). Both listings were already live on the Hub and **wired to nothing** since
  Job #117 — a game pass is buyable from the store page without entering the game, so that has been taking
  money and delivering nothing.
- Admin actions to grant the weapon and to bank a per-run charge for testing.

## Fixed
- **A Lifetime pass owner could buy a per-run charge that was never spent and never refunded.** Ownership
  is resolved asynchronously and up to 20 s after join, and only a positive result was ever published — so
  both shops showed a live buy button in the meantime and the grant then preferred the free pass. Ownership
  is now published either way behind a `PassesChecked` flag, and per-run rows wait for it. **This fixes the
  same hole for the M16.**
- **The rocket's explosion would never render for a player whose client was not drawing frames** (alt-tab,
  minimise, occlusion). The flight and the blast were driven off `RenderStepped`; the flight moved to
  `Heartbeat` and the blast onto its own timer. Found by measurement — `Heartbeat 60/s` against
  `RenderStepped 0/s` — not by reasoning.

## Changed
- `WeaponServer`'s weapon lockout renamed `burstUntil` → `lockUntil`: it now covers the Bazooka's reload as
  well as the M16's burst, and neither is scaled by Gun Discipline.
- Gun Discipline's documented exemption extended from the M16 to both paid weapons.
- Held-weapon muzzle geometry moved into the shared `Ballistics` module, so the server launches the rocket
  from exactly where the client draws the muzzle flash.
- `InventoryService` now warns at startup when a weapon's art is missing from `AssetLibrary` **or is still
  a Meshy `Model` wrapper**, instead of silently falling back to the grey greybox box.

## Notes
- ⚠️ **Third `power = true` item.** `GAME.md` had said the M16 was "not a licence for a third". Shipped on
  the owner's explicit call and recorded as a decision, not folded into the table.
- ⚠️ The blast damages **enemies, camp guards and generators only** — never a player, a crewmate or the
  boat, enforced structurally rather than by a filter.
- 🔴 **Save the GAME place**: the two unwrapped weapon meshes live in `ServerStorage.AssetLibrary`, which is
  not Rojo-synced.
- New findings **0032** (Q deletes a paid weapon) and **0033** (damage numbers culled at 260 studs while
  this weapon reaches 300); **0017** updated — both money paths left open by the owner's scoping call.
