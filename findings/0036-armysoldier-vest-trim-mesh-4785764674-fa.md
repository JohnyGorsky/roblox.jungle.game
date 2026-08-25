# FINDING 0036: ArmySoldier vest trim mesh 4785764674 fails to fetch, so one plate-carrier piece does not render

**Project:** `roblox.jungle`
**Status:** open
**Severity:** med
**Created:** 2026-08-25 19:23:11

**Symptom:** ServerStorage.AssetLibrary.Enemies.ArmySoldier.UpperTorso.Model.Chest.Border is a MeshPart whose MeshId is 4785764674, and the log reports 'MeshContentProvider failed to process ... because could not fetch' three times on every run. It is one small trim piece of the 30-part plate carrier from the free Creator Store model 11927692797; the rest of the vest and the helmet render fine, so the RocketMan still reads as a soldier. Cosmetic only. Fix options: delete that one part from the library model (and re-save the place), or replace its MeshId with a working asset. Logged rather than fixed because it needed a place-file edit the user has to save anyway, and deleting geometry from a sourced model is worth their call.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_
