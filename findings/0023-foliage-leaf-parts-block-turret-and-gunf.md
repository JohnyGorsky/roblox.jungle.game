# FINDING 0023: Foliage leaf parts block turret and gunfire; at the mooring the turret can only shoot ferns

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-23 16:38:17

**Symptom:** Observed live (Job #104 verification, 2026-08-23): seated in GunSeat at the moored boat, 30+ turret rounds all logged '[Gun] hit ...Foliage.FernTall...Fern_OuterLeaves (Plastic) - not an enemy'. FoliageServer's leaf parts are CanQuery, so they stop hitscan the way a wall does. Two consequences: (a) shooting anything near the bank is unreliable, (b) it makes verification hard because a CLIENT-side line-of-sight check can disagree with the server - with StreamingEnabled the client had not loaded the ferns and saw a clear line while every server round stopped in one. Consider CanQuery=false on decorative leaf parts (keeping trunks solid).
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
