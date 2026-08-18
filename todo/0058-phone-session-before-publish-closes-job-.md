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
