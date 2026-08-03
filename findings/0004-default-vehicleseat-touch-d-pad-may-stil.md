# FINDING 0004: Default VehicleSeat touch D-pad may still draw alongside our custom TouchControls

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-03 00:00:19

**Symptom:** Job #075 built custom touch drive controls (TouchControls.local.luau) that write SteerFloat/ThrottleFloat at a late render step. VehicleSeat.HeadsUpDisplay is now false so the 'Speed 0' gauge is gone, but Roblox's DEFAULT mobile vehicle D-pad has no documented toggle and may still render for a seated driver on a touch device, giving two sets of controls. Not reproducible in Studio Play on desktop - needs the Device Emulator with touch enabled, or a real phone. If it does draw: investigate the PlayerModule VehicleController, or gate our own controls off instead.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
