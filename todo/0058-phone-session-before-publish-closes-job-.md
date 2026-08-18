# TODO 0058: PHONE SESSION before publish — closes Job #096 and findings #0004/#0006/#0007

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-18 16:51:40

One device session settles everything the mobile pass could not verify in Studio (the Device Emulator is single-pointer and desktop Play reports TouchEnabled=false, so the touch UI never even builds there).

Sit at the TURRET:
  1. Drag to aim - does the barrel move at all? (finding #0007; if it does not, the fix failed)
  2. Is the aim speed usable? TOUCH_SENS is an untuned first value of 0.010 in GunClient - sluggish = raise it, twitchy = lower it. Tell Claude which and it gets tuned.
  3. Fire with the button while aiming with the other thumb - both must register at once.
  4. Drag to look WITHOUT firing a shot, then tap the fire button and confirm it does fire (finding #0006).

Sit in the DRIVER seat:
  5. Is there ONE set of driving controls on screen, or two? A second D-pad = Roblox's default still draws (finding #0004).
  6. Hold throttle AND steer together through a bend - both must register (Job #094's multi-touch rewrite, still unproven on glass).
  7. Slide a thumb off the throttle mid-hold - the boat must stop accelerating, not stay latched.

In the LOBBY (Job #095, lower risk):
  8. Does the taller nav rail feel right at ~66% of screen height? That is a judgement call no measurement settles.

---

## ⚠️ SCOPE CORRECTED (Job #099, 2026-08-18) — most of this does NOT need a phone

This todo was written believing the whole list required hardware. It does not. The **Device Emulator**
(Test → Device) gives `TouchEnabled = true`, a real touch canvas, and Roblox's own `TouchGui`, and it is
**single-pointer** — which is enough for everything here except two fingers at once.

**Settle these in the emulator (no phone needed):**
- **#0004** — sit in the DriverSeat and look for a second set of controls. `TouchGui`'s children can be
  enumerated directly, so this is a measurement, not an opinion.
- **#0006** — drag to look and confirm no shot fires; tap the fire button and confirm one does.
- **#0007** — drag to aim the turret; confirm yaw/pitch move at all, and judge `TOUCH_SENS = 0.010`.
- The lobby rail and hint (already re-verified in the emulator by Job #099).

**Genuinely needs hardware — this and nothing else:**
- **Two thumbs at once**: hold throttle AND steer through a bend, and slide a thumb off the throttle
  mid-hold. The emulator cannot produce a second pointer, so Job #096's multi-touch rewrite is the one
  claim that stays unproven until a real device runs it.

Job #099 spent four jobs' worth of effort deferring to "a real phone" before this was noticed. See the
`mobile` skill §1 and §7.
