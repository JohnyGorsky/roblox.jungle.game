# TODO 0021: REQUIRED (Job 068 B1): Leaderboard_Weekly is a framed, titled, EMPTY board

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 10:50:31

Audit Job 068, gap B1. greybox_placement.luau:157 builds it and NOTHING anywhere reads it -- grep Leaderboard_Weekly returns exactly one hit, the line that creates it. RankServer binds only Leaderboard_TopRuns (:126) and has no Weekly branch. ASSETS.md 1.6 claims a "coming soon" placeholder; there is no such placeholder in code -- the board carries only the greybox lbl() billboard reading WEEKLY over a blank face. Three ways out: build a real weekly board (needs a weekly OrderedDataStore + rollover), ship a genuine coming-soon face, or remove the board until there is data.
