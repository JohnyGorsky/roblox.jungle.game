# FINDING 0009: In-run HUD: ObjectiveHud tray header and the carry DropButton are under the thumb floor

**Project:** `roblox.jungle`
**Status:** fixed (2026-08-18)
**Severity:** med
**Created:** 2026-08-18 16:47:21

**Symptom:** Measured in the GAME place during Job #097: ObjectiveHud's tray Header is 150x32 and InventoryHud's DropButton is 160x21, against the 58px thumb floor. Both are scale-derived (ObjectiveHud collapsedSize 0.045 of screen height; the HandsFull card is 0.036 tall), so this is NOT a measurement artifact and gets WORSE on a phone, where these numbers roughly halve. Both are real controls: the header is the tap target that expands the objective list, and DropButton is how a carrying player puts cargo down. Neither is a Components.button, so Job #097's shared floor does not reach them - they need their own sizing fix. Out of scope for #097, which was scoped to the modal close/buy buttons in finding #0008.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
