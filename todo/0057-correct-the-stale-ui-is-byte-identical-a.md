# TODO 0057: Correct the stale 'UI/ is byte-identical across both trees' claim in RunComponents.luau

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-18 16:21:52

sync/ReplicatedStorage/RunUI/RunComponents.luau's header states UI/Components.luau is kept byte-identical across the GAME and LOBBY trees. A diff on 2026-08-18 (Job #095 investigation) shows the two copies already DIFFER, so the comment now misleads. Not fixed in Job #095 because that job is LOBBY-scoped and this file is in sync/ (GAME) - crossing the place boundary needs its own permission. Trivial one-comment fix, just needs the right job.
