# TODO 0005: Lights: boat searchlight + carryable player torch/lamp for night

**Project:** `roblox.jungle`
**Status:** resolved (2026-07-19) — promoted to a job
**Created:** 2026-07-19 16:31:30

Lighting isn't tested yet. (1) BOAT SEARCHLIGHT: the Searchlight module part exists (BoatModules adds a SpotLight) but verify it actually lights the way at night + is steerable/useful; tie to the Night Watch effect. (2) PLAYER-CARRIED LIGHT (Dead Rails-style): players need a torch/lamp to survive the dark jungle at night on foot — find/loot a torch or lamp item, equip it, it emits light (PointLight/SpotLight) while held/carried. Without a light, night jungle excursions are near-blind. Consider it an inventory item + a held-light visual. Ties into day/night (DayNightServer), inventory, and the night set-piece (#035).
