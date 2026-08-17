# Final Summary — Job #092

**Project**: `roblox.jungle`
**Completed**: 2026-08-17
**Status**: ✅ Code complete, both trees analyzer-clean — ⏳ awaiting playtest

Four playtest items. Items 3 and 4 turned out to be one piece of state and share a module.

---

## Item 1 — Wolves float slightly

> *"wolfs fly (they are too much in air, a little bit)"*

### Not the rigs

First suspicion was the seating maths, so the assets were measured in Studio. They're fine — the
bounding box a creature is seated by sits within **0.035 studs** of its lowest visible part:

| | bbox bottom | lowest visible part | gap |
| --- | --- | --- | --- |
| Wolf | 18.004 | 17.969 (`Right Leg`) | −0.035 |
| Boar | 18.000 | 18.000 (`Right Leg`) | 0.000 |
| WesternBandit | 2.946 | 2.939 (`LeftFoot`) | −0.007 |

Job #088's visual seating and Job #090's hitbox seating are both correct.

### The actual cause — and it's mine, from #090

Job #090 seated a camp guard by measuring the ground **once, at its spawn point**, storing it in
`guardState.anchor.Y`, and using that height forever. I justified it in that job's own comment:
*"the basin is carved flat, so one measurement covers the whole leash."*

That was true of a **55-stud** leash inside the carved basin. **It stopped being true in the same
job**, where the alert pull raised the leash to `GUARD_LEASH_ALERT` = **250**. A guard chasing a
shooter now leaves the flat basin entirely while still holding the basin's floor height — so it floats
over any ground that sits lower.

### Fixed

`tickGuard` re-measures the ground as the guard walks, throttled by **distance** (`REMEASURE_STEP` = 6
studs) rather than time. `groundAt` can fire up to 25 probes on its fallback path and this runs per
guard per frame, so a distance gate keeps it to a fraction of a raycast per guard per frame — invisible
at walking speed. A failed read keeps the previous height; a missed ray must never teleport a creature.

---

## Item 2 — Bandits sometimes have no health bar

> *"bandits sometimes does not have health bars"*

The visibility rule is *"show if damaged **or** within 140 studs"*, and the distance half read
`bar.model.PrimaryPart` **on every tick**.

`PrimaryPart` is a Model property that replicates **separately from the parts themselves**, so on the
client it can still be nil for a freshly tagged enemy — and `makeBar`'s existing retry may already have
adorned a different `BasePart` by then. When it was nil the distance test silently evaluated false,
`near` came out false, and a **full-health** enemy therefore drew nothing at all. No error, no pattern
— just *some* enemies with no bar. Exactly "sometimes".

**Fixed:** the `Bar` record now stores the part it actually adorned, and the loop measures from that.
The part is known to exist, because the bar was built from it, so the test can no longer fail silently.

---

## Items 3 & 4 — first person

These are one piece of state — *who owns the mouse* — so they share a new
`ReplicatedStorage/UI/InputMode.luau` rather than two scripts fighting over `UserInputService`.

### ⚠️ Why item 4 could not be fixed the obvious way

The obvious fix for *"in first person the shop can't be closed"* is
`UserInputService.MouseBehavior = Default` while a panel is open. **It does not work**, and it's
recorded in the module so nobody loses an afternoon to it: Roblox's own PlayerModule camera re-asserts
`LockCenter` **every frame** while the camera is in first person. An external write is gone by the next
frame and the cursor stays pinned to the centre of the screen.

The reliable lever is the **camera**, not the mouse: raise `Player.CameraMinZoomDistance` so the camera
is forced out of first person while a panel is up, then restore it. Roblox then frees the mouse itself,
because it is no longer in first person. Push/pop is **reference-counted** — a confirmation panel over
the shop must not hand the mouse back when the inner one closes.

**Hooked in `Components.panel.setOpen`**, not in the shop. Every modal in the game is built from that
component, so one seam covers the dock shop, the Robux shop, the admin panel and the results screen —
and anything added later gets it for free.

### Item 3 — and why the weapon was invisible

The cursor half is small: hide the OS mouse icon in first person so only the game's crosshair is drawn.

The weapon half had a structural cause worth knowing. **Roblox blanks the local character in first
person** by setting `LocalTransparencyModifier` on its parts, and makes **one exception: a `Tool`'s
`Handle`**. That exception is how every stock Roblox FPS shows its weapon.

**Our held item is not a Tool.** `HeldPose` documents that decision at length — a real Tool drags in
the Backpack UI *under our own hotbar*, drop-on-Backspace, and `Tool.Activated` racing `MeleeClient` —
and it is the right call. But it means `HeldItem`, a plain welded Part, is treated as ordinary
character geometry and vanishes with the rest of it.

So the exception is re-applied by hand: `FirstPersonClient.local.luau` forces
`LocalTransparencyModifier = 0` on `HeldItem` and the right arm **every frame** (Roblox re-applies the
blanking continuously, so a one-off write is gone next frame — the same shape as the existing fix in
`GunClient`). The axe, pistol and shotgun now show in view, held in a visible hand.
`LocalTransparencyModifier` is client-only, so nobody else's screen changes.

This is a *visible weapon*, not a separate FPS viewmodel rig with its own sway and bob — it reuses the
real held item, so it can never drift from the server's aim. If a true viewmodel is wanted later it is
its own job.

---

## Files changed

| File | Change |
| --- | --- |
| `Excursion/ExcursionServer.server.luau` | guards re-measure ground every 6 studs of travel; `GuardState` gains `seatY`/`seatAt`/`seatAtZ` |
| `UI/EnemyHealthBars.local.luau` | `Bar` stores its adorned part; distance test uses it |
| `ReplicatedStorage/UI/InputMode.luau` | **new** — who owns the mouse; first-person detection |
| `ReplicatedStorage/UI/Components.luau` | `panel.setOpen` pushes/pops `InputMode` |
| `Combat/FirstPersonClient.local.luau` | **new** — hide cursor icon, keep weapon + arm visible |

⚠️ **`Components.luau` and `InputMode.luau` were mirrored into the lobby tree.** The two
`Components.luau` are maintained as identical copies (verified: identical content, they differ only in
line endings — the lobby uses LF, the game CRLF, and each file's own convention was preserved). The
lobby has modal panels too, so this fixes the same unclosable-panel bug there.

## Verification

- [x] `tools/luau-analyze.sh` — GAME clean
- [x] `tools/luau-analyze.sh --lobby` — no new diagnostics (four pre-existing remain, unrelated)
- [x] Creature rigs measured in Studio — ruled the seating maths out before changing anything
- [ ] ⏳ **Playtest:**
      1. wolves stand on the ground, including a guard that has chased you well out of its camp;
      2. every bandit shows a health bar within ~140 studs, from the moment it spawns;
      3. in first person: no OS cursor, and your weapon is visible in hand;
      4. open the shop in first person — the camera pops out, and you can click to close it;
      5. same in the lobby.
