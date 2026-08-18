# Job #096 — Implementation plan

**Project**: `roblox.jungle` · **Place**: GAME only (`sync/`) · **Status**: AGREED — ready to implement

Intake: [intake.md](intake.md). Skills: `roblox-ui`, `roblox-dev`, GROUND-RULES §3/§6.

**Studio target (verified):** `Last River COOP Game`, PlaceId **138141472932347**, studio id
`9c07cff7-…fdb0`.

---

## ⚠️ 1. The scope changed: the gunner role is unplayable on mobile

Investigating finding #0006 turned up something worse, now logged as **finding #0007 (high)**.

`GunClient.local.luau:124` gates **all** turret aiming:

```lua
UserInputService.InputChanged:Connect(function(input: InputObject)
    if not seated or input.UserInputType ~= Enum.UserInputType.MouseMovement then
        return
    end
    yaw   = math.clamp(yaw   - input.Delta.X * SENS, -YAW_LIMIT, YAW_LIMIT)
    pitch = math.clamp(pitch - input.Delta.Y * SENS, PITCH_MIN, PITCH_MAX)
```

Roblox does **not** emit `MouseMovement` for touch drags — a touch drag arrives as
`UserInputType.Touch` on `InputChanged`. So on a phone `yaw`/`pitch` never change. A mobile gunner sits
down, gets the over-the-gun camera, and **cannot move the barrel at all.**

Combined with #0006 (any tap fires), a mobile gunner can only shoot straight ahead — while every
attempt to look around wastes a round from the boat's shared, scavenged ammo stock.

**This reorders the job.** #0006 was logged as "wastes ammo"; the real headline is that one of the
game's crisp interdependent roles — the pillar GAME.md names as how we beat Dead Sails — does not
function on the platform GAME.md calls a hard requirement. Aiming is now WS1; the fire control is WS2.

## 2. Confirmed: driving and shooting are mutually exclusive

Read from the server, not assumed. `WeaponServer.canShoot` refuses a handheld shot when the player
`isDriver`, is in the `GunSeat`, or is `Busy`; `GunClient` only fires while `seated` in the GunSeat.

| Role | Controls on screen |
|---|---|
| Driver | steer (bottom-left) + throttle (bottom-right) · **cannot shoot** |
| Gunner | turret aim + fire · **cannot steer** |
| On foot / passenger | handheld weapon + hotbar · **cannot steer** |

**This answers intake question 2: yes, a fire control can reuse a driving corner** — they are never on
screen together. It also means the fire button can sit bottom-right (where shooter players expect it)
without ever meeting the throttle.

**It must still be proven, not assumed**, by adding a "gunner (touch)" and "on-foot (touch)" state to
`tools/hud-overlap-audit.luau` and re-running the matrix. #094 closed a set of overlaps; this job must
not quietly reopen them.

## 3. Design decision — dedicated button (AGREED via wizard, 2026-08-18)

The intake offered a dedicated fire button vs a drag-vs-tap discriminator. **Agreed: the button.** Reasons:

- §1 forces a **drag** gesture for aiming. If drag aims and tap fires, the discriminator is no longer a
  nicety — it is the only thing separating the two, and every ambiguous gesture becomes either a lost
  shot or a wasted round. A separate button removes the ambiguity entirely.
- It matches the control language #094 established: fixed, large, always in the same place — chosen
  there over a floating joystick for exactly this reason (the player is watching the river, not their
  hands).
- §6.11's "no noise" rule is about *panels and chatter*, not controls. A control you need is not noise.

**Agreed layout** (still to be confirmed against the harness, not shipped on assertion):

**Also agreed:** the turret and the handheld share ONE scheme — same fire button, same corner, so the
right thumb always means the same thing. The turret additionally gets drag-to-aim (WS1); the handheld
does not need it, since the normal camera already aims it.

| Role | Left thumb | Right thumb |
|---|---|---|
| Driver | steer pair | throttle pair |
| Gunner | *(free — aim by dragging anywhere)* | **fire button**, throttle's corner |
| On foot | *(free)* | **fire button**, same corner |

Fire in the throttle corner means the right thumb always means "make the boat/gun do the thing", which
is one habit rather than two.

## 4. Workstreams

### WS1 — Turret aiming on touch *(finding #0007, highest priority)*
Accept `UserInputType.Touch` alongside `MouseMovement` in `GunClient`'s `InputChanged`, using
`input.Delta`. Two things to get right:

1. **`Delta` semantics differ.** For touch, `InputObject.Delta` is movement since the last frame of that
   touch; for `MouseMovement` it is raw mouse delta. `SENS` is tuned for a mouse and will almost
   certainly be wrong for a thumb — expect a separate touch sensitivity constant, tuned on a device.
2. **The aim drag must not also fire (WS2) and must not fight the camera.** Verify against
   `roblox-dev`/`roblox-camera` before writing, rather than guessing at the interaction.

### WS2 — Fire control *(finding #0006)*
A touch-only fire button reusing `RunComponents.touchButton` — which #094 already rebuilt for
per-`InputObject` multi-touch, so holding aim with one thumb and firing with the other works by
construction. Wire it for **both** `WeaponClient` (handheld) and `GunClient` (turret).

Then **narrow the tap-anywhere path**: once a button exists, firing on any `Touch` `InputBegan` should
stop. Keep the existing `gameProcessed` guard — that part is already correct and is not the bug.

⚠️ **Do not break PC.** Both clients currently fire on `MouseButton1` *or* `Touch` through one branch.
The mouse path must be left exactly as it is.

### WS3 — Finding #0004, the default D-pad
Settle it on a real device (§5) and act:
- **If it draws** — suppress via the `PlayerModule` `VehicleController`, **not** by hiding ours; ours are
  the styled scale-based controls Job #075 built to replace it.
- **If it does not** — close the finding. Do not leave it open by silence a third time.

### WS4 — Regression
Add `gunner (touch)` and `on-foot (touch)` states to `tools/hud-overlap-audit.luau`; re-run the full
matrix; confirm zero overlaps and zero undersized tap targets, as #094 left it.

## 5. What I need from you

**This job is phone-first and cannot be finished in Studio.** Studio can build and lay out the controls
and prove they don't collide; it cannot tell us whether aiming *feels* right or settle #0004.

Required on a real device:
1. **Aim the turret by dragging** — does it move, and is the sensitivity usable? (WS1 tuning depends
   on this; I cannot pick `SENS` from a desk.)
2. **Fire with the button while aiming with the other thumb** — both must register.
3. **Drag to look with no shot fired**, then a deliberate shot that does fire.
4. **Sit in the DriverSeat: one set of controls, or two?** → settles #0004.
5. **Carried over from #094 and still outstanding** — hold throttle and steer through a bend, and slide
   a thumb off the throttle mid-hold. Fold it into this same session rather than scheduling a second.

## 6. Risks

- **`SENS` cannot be tuned from Studio — agreed approach: ship a considered first value, then tune from
  your phone feedback.** One extra round trip, accepted deliberately as the honest path. No settings
  slider and no debug attribute in this job.
- **A new on-screen control is a design change**, not a fix. The button is now agreed, but if it proves
  too heavy on a real phone the discriminator remains the fallback — worth knowing before the device
  session rather than after.
- **Touch `Delta` behaviour is worth verifying against the docs**, not inferred from the mouse path.

## 7. Out of scope

- The LOBBY place — [Job #095](../095/implementation-plan.md).
- Anything #094 settled (steer order, multi-touch, the overlaps it closed).
- Rebalancing ammo economy, even though #0006 has been taxing it.

## 8. Order of work

1. WS1 aiming (the role is broken; fix that first) → 2. WS2 fire control → 3. WS4 regression sweep in
Studio → 4. **your phone session** (§5) → 5. WS3 resolve #0004, tune `SENS` → 6. summary + changelog;
close findings #0006 and #0007, and #0004 either way.
