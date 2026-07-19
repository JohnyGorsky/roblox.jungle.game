# FINDING 0001: Boat searchlight does not turn on while riding at night

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-07-19 19:41:38

**Symptom:** Player reports the boat light was not working during a ride. The searchlight (SpotLight tagged NightLight, built at RunStarted) should turn on dusk->dawn via LightController. Check: is it built/tagged at run start, is LightController toggling it, is it aimed/enabled, and does ClockTime cross the DUSK threshold during the ride.
**Where:** sync/ServerScriptService/Boat/BoatModules.server.luau (searchlight) + World/LightController.server.luau
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
