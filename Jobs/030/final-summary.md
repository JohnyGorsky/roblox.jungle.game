# Final Summary — Job #030: In-boat untie GUI button

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · From todo 0001. Game-only.

## What was built
A GUI **untie/start button** shown while you're seated in the boat's DriverSeat and the boat is TIED — so
you can untie without reaching the winch/dock ProximityPrompt (which is unreachable at awkward mooring
angles, the reported pain point). Works for both the staging Start-gate and dock ties.

### Files
- **New:** `StarterPlayer/StarterPlayerScripts/UI/UntieButton.local.luau` — shows when
  `seated in DriverSeat` + `boat.Tied`; label "PULL / START" (staging) / "UNTIE" (dock); fires `RequestUntie`.
- **Edit:** `Staging/StagingServer.server.luau` — creates the shared `RequestUntie` RemoteEvent; handler
  reels/starts (same progression as the winch prompt), pre-run only.
- **Edit:** `World/DockServer.server.luau` — refactored untie into `doUntie`; the currently-tied dock
  registers `activeUntie`; `RequestUntie` handler calls it (only one dock tied at a time). WaitForChilds the remote.

## Verified (live in Studio)
- [x] Analyzer-clean.
- [x] Seated in DriverSeat + Tied → button visible, label "PULL / START" (screenshot).
- [x] Firing `RequestUntie` reeled the boat to the dock and **started the run** (RunStarted=true, Tied=false).
- [~] Dock untie uses the same remote → `doUntie` (symmetric; construction-verified — not separately driven
      to a dock headlessly).

## Notes / follow-ups
- **Not committed.**
- The **"drive while tied" (rope-constrained)** bonus idea from the todo is deferred — this job does the
  untie button only (the actual pain point). Note it for a later pass if desired.
- Both server handlers coexist safely (guarded by run state / `activeUntie`), sharing one remote.
