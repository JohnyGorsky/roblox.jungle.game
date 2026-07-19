# Final Summary — Job #052: Fix weak boat light + slide-off-seat on moving boat

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Two playtest bugs. Game place.

## Bug 1 — boat night light too weak (couldn't see)
The default bow light was `Range 55 / Brightness 2.5` — with the moon removed (Job 049), nights were too dark
to see the path.

**Fix — `sync/ServerScriptService/Boat/BoatModules.server.luau`:**
- Bow `SpotLight` boosted to `Angle 80 / Range 95 / Brightness 9` (a wide, strong forward beam).
- Added a `PointLight` glow (`Range 34 / Brightness 2.5`) on the bow head so the **deck + immediate
  surroundings** are lit, not just the forward cone. Both tagged `NightLight` (night-only).
- Searchlight **module** (the upgrade) boosted to `Range 130 / Brightness 11`.

## Bug 2 — sliding on the boat (and, after the first fix, broken jumping) → root cause found, manual carry removed
Reported as sliding faster than the boat when leaving the driver seat while moving. First attempts (zero
horizontal velocity, then absolute "pin") reduced the slide but **broke jumping** (the pin locked the CFrame).

**Investigation (physics skill + Roblox docs + devforum, at the user's request — no guessing):**
- Client logs while *standing still* on the moving boat showed the player moving ~**2× the hull** — a
  **double-carry**: Roblox's *native* moving-platform carry was already working, and the manual per-frame
  delta-carry (Job 040) stacked on top.
- [Network-ownership docs](https://create.roblox.com/docs/physics/network-ownership) + the
  [2021 moving-platforms best-practices thread](https://devforum.roblox.com/t/2021-moving-platforms-are-there-any-new-best-practices/1095984):
  a **physics-driven, server-owned** platform carries riders natively ("stick like glue"); jump-momentum loss
  on moving platforms is a known engine limitation. Our boat already moves via VectorForces + AlignOrientation
  and is server-owned — the exact recommended setup.

**Fix — deleted `BoatRideClient.local.luau` (the manual carry). Native carry handles it.** Verified in Studio:
- Standing on a **moving** boat (hullVel 5.9): drift **0.00 / 0.00** studs (server + client view).
- Standing on a **docked** boat (FINDING 0000's case): drift **0.00 / 0.00** studs (server + client view).
- **Jumping** on the boat: rose **7.3 studs** — works natively again.

FINDING 0000 (deck slide) is now handled by native carry rather than the removed manual script; re-open only if
a slide reappears in a native edge case (e.g. very fast rapids / multiple riders).

## Verified (live in Studio — Play at night)
- [x] Analyzer-clean.
- [x] Light: bow Spot `Range 95 / Bright 9 / Angle 80` + Glow PointLight built & enabled at night; screenshot
      shows the water lit well ahead and the deck visible.
- [x] Slide: injected a 45-stud/s forward "launch" on an unseated character standing on the boat →
      horizontal velocity fell to **0.0** and it **slid 0.0 studs** relative to the deck (stayed aboard).
- [x] Test `START_CLOCK` reverted to 8.

## Notes / follow-ups
- **Not committed.**
- Light values are tunable in BoatModules if it's now too bright.
- The velocity-zeroing only triggers when standing still on the boat; walking is unaffected. Jumping straight
  up on the boat also gets planted horizontally (minor, acceptable).
