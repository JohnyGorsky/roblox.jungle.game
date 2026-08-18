# FINDING 0006: Touch fires the weapon on any tap-to-look (no dedicated fire button)

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-18 15:42:33

**Symptom:** GunClient and WeaponClient both fire on any Enum.UserInputType.Touch InputBegan. Both correctly honour gameProcessed so HUD taps do not misfire, but on a phone every tap used to look around or reposition the camera also fires the weapon, wasting ammo. Needs a dedicated on-screen fire button (or a drag-vs-tap discriminator). Noticed during Job #094's mobile audit; deliberately out of that job's scope, which was fixes not new controls.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
