# TODO 0010: Hide in-game HUD/objective during the plane intro (show only on wake-up)

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-07-19 20:40:20

The objective banner + HUD (e.g. 'Pull the rope to reel the boat in — then board & untie to START', fuel/boat/cargo bars, hotbar) currently show from the START while you're still flying in on the plane. They should stay hidden through the whole intro (board/cruise/descent/crash) and only appear once you WAKE UP at the crash site. Gate the game HUD on IntroActive==false (or reveal it when the cold-open ends), similar to how IntroFade/GameLoading hide core GUI. Playtest note 2026-07-19.
