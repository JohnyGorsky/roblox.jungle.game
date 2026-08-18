# FINDING 0007: Mounted turret cannot be aimed on touch at all (gunner role unplayable on mobile)

**Project:** `roblox.jungle`
**Status:** open
**Severity:** high
**Created:** 2026-08-18 16:14:01

**Symptom:** GunClient.local.luau:124 gates ALL turret aiming behind 'input.UserInputType ~= Enum.UserInputType.MouseMovement' and returns otherwise. Roblox does not emit MouseMovement for touch drags - a touch drag arrives as UserInputType.Touch on InputChanged - so yaw/pitch never update on a phone. The gunner sits down, gets the over-the-gun camera, and cannot move the barrel. Combined with finding #0006 (any tap fires), a mobile gunner can only shoot straight ahead while wasting ammo on every look attempt. Found during Job #094's mobile audit follow-up; in scope for Job #096.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
