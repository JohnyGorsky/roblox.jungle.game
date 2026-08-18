# Job #096 — Final summary

**Project**: `roblox.jungle` · **Place**: GAME (`sync/`)
**Status**: ⚠️ **CODE COMPLETE — NOT FINISHED.** Two items are blocked on a real device (§5).
**Studio**: `Last River COOP Game`, PlaceId 138141472932347

Intake: [intake.md](intake.md) · Plan: [implementation-plan.md](implementation-plan.md)

---

## 1. The headline: the gunner role did not work on mobile at all

Investigating finding #0006 uncovered something worse — logged as **finding #0007 (high)** and now the
main body of this job.

`GunClient.local.luau` gated **all** turret aiming behind
`input.UserInputType ~= Enum.UserInputType.MouseMovement`. Roblox does not emit `MouseMovement` for a
touch drag — it arrives as `UserInputType.Touch` on `InputChanged` — so on a phone `yaw`/`pitch` never
changed. A mobile gunner sat down, got the over-the-gun camera, and **could not move the barrel.**

Combined with #0006 (any tap fires), a mobile gunner could only shoot straight ahead while every
attempt to look around burned a round of the boat's shared, scavenged ammo.

**Fixed:** `InputChanged` now accepts `Touch` alongside `MouseMovement`, with its own sensitivity
constant. `gameProcessed` is checked **for touch only** — a drag starting on the fire button must not
swing the barrel, while the mouse path is left exactly as it behaved before.

## 2. Finding #0006 — the whole screen was a trigger

Both combat clients fired on any `Touch` `InputBegan`. Since aiming is now a *drag*, a tap/drag
discriminator would have been the only thing separating look from shoot, so (agreed via wizard) touch
gets a **dedicated fire button** instead.

New `sync/ReplicatedStorage/RunUI/TouchFire.luau` — one shared button for both the turret and the
handheld, following `UI/UIBus`'s pattern (a purely local `BindableEvent`; round-tripping through the
server so two client scripts can talk would add latency and hand an exploiter a remote for nothing).

Design points worth keeping:
- **It reuses the throttle's exact rectangle** (`0.98, 0.96`, `0.19 × 0.16`). Driving and shooting are
  mutually exclusive — verified from the server, §3 — so the corner is free, the right thumb always
  rests in the same place, and the harness only has to prove one geometry.
- **Visibility is ref-counted per owner.** `WeaponClient` requests it while `reticleShown()`,
  `GunClient` while seated at the turret. Both listeners stay connected; each self-gates exactly as the
  mouse path already did, so the module decides *when the button is up*, never whether a shot is legal.
- **The handheld fires at the reticle, not at the thumb.** The reticle marks the true viewport centre,
  which is the line the player is sighting along; firing at the touch position would send the shot into
  the bottom-right corner.
- **PC is untouched.** Mouse click still fires through the same path it always did. The old
  tap-anywhere arm survives only behind `not TouchFire.isActive()`, so it is dead on a real phone and
  exists purely so a failure to build the button leaves the gun usable rather than silently inert.

## 3. Confirmed from the server: driving and shooting are exclusive

Read, not assumed. `WeaponServer.canShoot` refuses a handheld shot when the player `isDriver`, is in
the `GunSeat`, or is `Busy`; `GunClient` fires only while `seated`. This is what makes §2's corner reuse
safe rather than a gamble.

## 4. Regression — clean

Added `gunner (touch)` and `on-foot (touch)` states to the harness and re-ran the matrix:

| State | phone-small | phone | tablet | desktop |
|---|---|---|---|---|
| driving (touch) | none | none | none | none |
| **gunner (touch)** *(new)* | none | none | none | none |
| **on-foot / passenger (touch)** *(new)* | none | none | none | none |

Zero overlaps, zero undersized tap targets — nothing #094 closed has reopened.

Runtime checks in Play: `TouchFire` synced and requires cleanly; `setVisible` is a safe no-op on a
non-touch device; `onFire` connects; both combat clients still start (`WeaponGui` / `GunGui` present);
no `TouchFire` ScreenGui on desktop, which is correct. `screen_capture` confirms the PC HUD is
visually unchanged. `luau-analyze.sh` clean (exit 0) — it caught one real type error mid-work, which
also confirms the tool genuinely reports rather than silently passing.

## 5. ⚠️ What is NOT done — this job cannot close without a phone

| Item | Why it is blocked |
|---|---|
| **`TOUCH_SENS` is an untuned first value** (`0.010`) | Chosen so a ~280 px drag covers the full ±80° yaw arc. Cannot be judged from Studio. **Expect to adjust it** — sluggish → raise, twitchy → lower. |
| **Finding #0004 — the default D-pad** | Still open. Desktop Play reports `TouchEnabled = false` and the emulator is single-pointer; neither can show whether Roblox's D-pad draws beside ours. |
| **`TouchFire.build()` has never executed** | It early-returns unless `TouchEnabled`. The geometry is proven (the harness builds the identical structure through the same component), but the module's own build path runs for the first time on your device. |
| **Multi-touch, still carried from #094** | Two thumbs on glass has never been exercised. |

### The device session — what to check

1. **Sit at the turret and drag to aim** — does the barrel move, and is the speed usable?
2. **Fire with the button while aiming with the other thumb** — both must register.
3. **Drag to look and confirm no shot is fired**; then a deliberate tap on the button that does.
4. **Sit in the DriverSeat: one set of controls or two?** → settles #0004.
5. **Hold throttle and steer through a bend**, and slide a thumb off the throttle mid-hold (from #094).

## 6. Files changed

| File | Change |
|---|---|
| `sync/ReplicatedStorage/RunUI/TouchFire.luau` | **new** — shared touch fire control |
| `sync/StarterPlayer/StarterPlayerScripts/Combat/GunClient.local.luau` | touch aiming (#0007); `TOUCH_SENS`; trigger extracted to `pullTrigger`; wired to TouchFire |
| `sync/StarterPlayer/StarterPlayerScripts/Combat/WeaponClient.local.luau` | touch fires via the button, not any tap; fires at the reticle; wired to TouchFire |

## 7. Queue

- **#0006** — code complete, **confirm on device before closing**.
- **#0007** — code complete, **confirm on device before closing**.
- **#0004** — still open; unchanged, still needs the device.
- **todo #0057** — logged separately (stale cross-tree comment in `RunComponents.luau`).
