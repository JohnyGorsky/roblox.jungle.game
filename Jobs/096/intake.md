# Job #096: Touch combat controls — dedicated fire button + settle the default D-pad

**Project**: `roblox.jungle`
**Place**: **GAME only** (`sync/`)
**Created**: 2026-08-18
**Status**: ⚠️ CODE COMPLETE — NOT CLOSED. Blocked on a real-device session (final-summary.md §5).
Everything Studio can verify is done and verified; the touch build path, aim sensitivity and finding
#0004 have never run on a phone. Confirmed still untested as of 2026-08-18.

## Why this job exists

Two findings logged during [Job #094](../094/final-summary.md)'s mobile audit and deliberately left out
of it, because both need **new controls** rather than fixes — and #094 was scoped to fixes:

- **Finding #0006** — on touch, any tap-to-look fires the weapon.
- **Finding #0004** — Roblox's default `VehicleSeat` D-pad may still draw alongside our own controls.

They belong together: both are "what is actually on the glass while you play", and both can only be
settled on a real device, so they should share one phone session rather than two.

## Requirements / goal

1. **Give touch players a real fire control** for the handheld weapon *and* the mounted turret, so
   aiming the camera stops costing ammo.
2. **Settle finding #0004** and act on the answer.

## Investigation — what #094 already established

### A. Finding #0006 — the whole screen is a trigger

Both combat clients fire on **any** `Touch` `InputBegan`:

- `sync/StarterPlayer/StarterPlayerScripts/Combat/WeaponClient.local.luau:212`
- `sync/StarterPlayer/StarterPlayerScripts/Combat/GunClient.local.luau:171`

Both **correctly** honour `gameProcessed`, so taps on HUD buttons don't misfire — that part is already
right and should not be "fixed". The problem is the rest of the screen: on a phone, dragging to look
around *is* a touch, so the camera and the trigger are the same gesture. Every look costs a round.

This is not a small tax. Ammo is a **scavenged resource** — the run's economy assumes you spend rounds
on threats, and `GunServer` refuses a shot with no rounds and no crates, so a mobile player burns
through the boat's shared stock by doing the one thing they must do constantly: look at the river.

**Two candidate shapes, to be decided in the plan:**

| | Dedicated fire button | Drag-vs-tap discriminator |
|---|---|---|
| How | An on-screen button, like the existing steer/throttle pair | A tap that moves less than N px in under T ms counts as a shot; anything else is a look |
| For | Unambiguous; matches the control language #094 established; discoverable | No new screen furniture on an already-busy HUD |
| Against | More HUD on a small screen — and §6.11 is a "no noise" rule | Invisible rules feel arbitrary; tuning N and T is a feel problem, not a correctness one; a shot that doesn't fire reads as a bug |

Leaning **dedicated button**, for consistency with the driving controls and because #094 chose fixed,
always-in-the-same-place buttons over a floating gesture for exactly this reason. To be argued properly
in the plan, not assumed here.

**Layout constraint inherited from #094:** the bottom corners are spoken for while driving (steer
`x 0.02–0.21`, throttle `x 0.79–0.98`, both `y 0.80–0.96`), and the health bar already reflows to
`x 0.225` in a control seat. A fire button must not re-open any of the overlaps #094 just closed —
which is directly testable, since `tools/hud-overlap-audit.luau` exists and needs a new state added.

Worth noting the roles rarely collide: `WeaponServer` refuses a handheld shot while in the DriverSeat
or GunSeat, so the driver isn't shooting and the gunner isn't steering. The fire button and the steer
buttons should mostly not be on screen together — **confirm that**, because it decides whether the fire
button can simply take the steer corner.

### B. Finding #0004 — does the default D-pad still draw?

Unresolved after two attempts, and the reason is worth stating plainly so nobody re-treads it:

- **Desktop Play reports `TouchEnabled = false`**, so our own `TouchControls` never builds — there is
  nothing to compare against.
- **Studio's Device Emulator is single-pointer** and did not settle it either.

`VehicleSeat.HeadsUpDisplay` is already false (the "Speed 0" gauge is gone), but the mobile vehicle
D-pad has no documented toggle. If it does draw, the fix is to suppress it via the `PlayerModule`
`VehicleController` — **not** to hide our own, which are the styled scale-based ones Job #075 built
specifically to replace it.

## Playtest & verification

This job is **phone-first**, unusually. The decisive checks cannot happen in Studio:

1. **#0004** — sit in the DriverSeat on a real device: is there **one** set of controls or two?
2. **#0006** — drag to look around and confirm no shot is fired; then fire deliberately and confirm it
   is.
3. **Carried over from #094 and still outstanding** — hold throttle and steer simultaneously through a
   bend, and slide a thumb off the throttle mid-hold. If this job is running, fold that sign-off in
   rather than scheduling a second phone session.

Studio still carries the layout half: add a "gunner (touch)" state to `tools/hud-overlap-audit.luau`
and re-run the resolution matrix so the new control is proven not to collide.

## Open questions for the plan phase

1. Dedicated button vs drag-vs-tap — decide, with the argument written down.
2. Can the fire button reuse the steer corner (are driving and shooting genuinely exclusive)?
3. Does the turret (`GunClient`) want the same control as the handheld (`WeaponClient`), or does a
   mounted gun deserve its own treatment?
4. Does a fire button need a reload/ammo affordance beside it, or does the existing hotbar slot cover it?
5. If #0004 turns out to be a non-issue, close it — don't leave it open by silence.

## Out of scope

- The LOBBY place — that is [Job #095](../095/intake.md).
- Re-litigating anything #094 settled (steer order, multi-touch, the overlaps it closed).

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [~] Implementation completed — code done; device verification outstanding (see final-summary §5)
- [x] Final summary + changelog written
