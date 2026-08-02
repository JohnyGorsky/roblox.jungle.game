# TODO 0044: night_starts audio asset is not approved for playback - re-upload

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 21:58:38

Found in Job 073 Play verification. rbxassetid://99602574849976 (night_starts) fails at runtime with 'Asset is not approved for the requester' and IsLoaded stays false. The id is NOT wrong: GetProductInfo returns name 'night_starts', AssetTypeId 3 (Audio), creator johnygorsky10 - so the asset exists and is owned. Its sibling uploads from the same batch (morning_starts 98066971477923, battle_starts 79506043370965, cicadas, both ambience beds, wind, water-splashes) all load fine in the GAME place, so this is NOT a per-experience permission issue - it is specific to that one upload, i.e. Roblox audio moderation has not approved it. ACTION: check the asset on create.roblox.com -> Creator Dashboard -> Development Items -> Audio -> night_starts, and if it shows rejected/pending, re-upload assets/Objects/Ambient/night_starts.mp3 and put the NEW id into the SFX table at the top of sync/ServerScriptService/World/GameSoundscape.server.luau plus the registry roblox.workspace/Assets/registry/audio.md. Until then the night stinger is silent; GameSoundscape warns about it and cleans the Sound up after 20s so it does not leak.
