# Job #030: In-boat untie GUI button

**Project**: `roblox.jungle`
**Created**: 2026-07-19 15:47:08
**Status**: Requirements Gathering (intake)

## Requirements / goal

From todo 0001. When a player is seated in a TIED boat, a ProximityPrompt untie can be unreachable at awkward mooring angles. Add a client GUI UNTIE button shown while seated as driver in a tied boat (both the staging Start-gate rope and dock ties); clicking fires a RemoteEvent the server validates + performs the untie. Server-authoritative. POC, minimal GUI.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan (inline — small job)
- [x] Implementation completed — GUI untie button verified: seated+tied shows the button; firing reeled +
      started the run (staging); dock untie via same remote (symmetric); analyzer-clean
- [x] Final summary + changelog written
