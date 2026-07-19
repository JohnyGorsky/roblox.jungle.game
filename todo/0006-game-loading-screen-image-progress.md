# TODO 0006: Game loading screen (image + progress)

**Project:** `roblox.jungle`
**Status:** resolved (2026-07-19) — promoted to a job
**Created:** 2026-07-19 16:32:24

Add a proper game loading screen shown while the experience loads (assets/first-time in). Show a branded IMAGE + a loading indicator/progress, then fade out when ready. Reference roblox.defender's loading screen for style/approach (ReplicatedFirst + RemoveDefaultLoadingScreen + a custom ScreenGui, wait on ContentProvider:PreloadAsync / game.Loaded). Applies to both places (lobby + game). POC greybox, real art later.
