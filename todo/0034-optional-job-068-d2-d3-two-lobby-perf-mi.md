# TODO 0034: OPTIONAL (Job 068 D2/D3): Two lobby perf micro-notes -- Heartbeat pad tick, full-Workspace station scans

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 10:51:17

Audit Job 068, gaps D2 and D3. Neither needs action now; recorded because GAME.md mobile perf is a standing constraint. D2: LobbyServer:379 runs an unconditional Heartbeat, gated to real work every 0.3s, doing #pads x #Players distance checks. Fine at lobby scale. D3: LobbyStations:33 and LobbyServer:38 each do a full Workspace:GetDescendants() scan, retried every 0.2s for up to 15s at startup, five callers. Startup-only and invisible to players. Only worth touching if the lobby place grows a lot.
