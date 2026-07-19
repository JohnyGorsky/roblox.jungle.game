# Job #043: Intro readiness gate (hold reveal until crew joined + world built)

**Project**: `roblox.jungle`
**Created**: 2026-07-19 18:25:22
**Status**: Requirements Gathering (intake)

## Requirements / goal

Step 2 of game-intro-sequence. Lobby: add partySize (+member UserIds) to TeleportData at launch. Game: IntroGateServer sets Workspace.IntroReady=false at startup, waits until all party members have joined (from TeleportData partySize, with a timeout failsafe for drops/solo) AND the world is built (WorldBuilt hook, inert until a generator exists), publishing IntroStatus text, then sets IntroReady=true. GameLoading loader holds on IntroReady and shows IntroStatus. Server-authoritative, greybox. Solo/Studio Play must not hang (expected=1).

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
