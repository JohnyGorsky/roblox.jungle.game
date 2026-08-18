# FINDING 0004: Default VehicleSeat touch D-pad may still draw alongside our custom TouchControls

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-03 00:00:19

**Symptom:** Job #075 built custom touch drive controls (TouchControls.local.luau) that write SteerFloat/ThrottleFloat at a late render step. VehicleSeat.HeadsUpDisplay is now false so the 'Speed 0' gauge is gone, but Roblox's DEFAULT mobile vehicle D-pad has no documented toggle and may still render for a seated driver on a touch device, giving two sets of controls. Not reproducible in Studio Play on desktop - needs the Device Emulator with touch enabled, or a real phone. If it does draw: investigate the PlayerModule VehicleController, or gate our own controls off instead.
**Where:** `sync/StarterPlayer/StarterPlayerScripts/Boat/TouchControls.local.luau` (GAME place)
**Repro / notes:** Job #094 (2026-08-18) re-examined this and could NOT settle it. Studio's Device
Emulator is single-pointer, and a desktop Play session reports `TouchEnabled = false`, so our own
TouchControls never even builds there — neither environment can show whether Roblox's D-pad draws
alongside ours. Deliberately left OPEN rather than closed on a guess. Settling it needs a real phone:
sit in the DriverSeat and look for a SECOND set of controls beside ours.
**Fix idea:** If it does draw, gate it off via the PlayerModule VehicleController rather than hiding
our own controls — ours are the styled, scale-based ones (Job #075) and the default D-pad is what
#075 set out to replace.
