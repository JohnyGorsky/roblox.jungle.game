# Job #091: Remove boars (boat spin) + fix the wiggling intro camera

**Project**: `roblox.jungle`
**Created**: 2026-08-17 20:00:20
**Status**: <span style="color:#2e9c3f">✅ **COMPLETE** (2026-08-17)</span> — analyzer clean, ⏳ awaiting playtest. See [`final-summary.md`](final-summary.md).

## Requirements / goal

Two items, user direction 2026-08-17. ITEM 1 - 'Remove boars for now, they somehow attack boat and boat spins.' SCOPE CHANGED MID-JOB: the user then asked to keep boars but confine them to land, and supplied the decisive detail ('pig jumped on my boat at the start'). Cause found and fixed; boars are back. ITEM 2 - 'intro - looks like camera cant keep up plane and it wiggles a lot, this is camera issue it lags.' TWO FIXES, the first insufficient: IntroCameraClient smooths its own position but aims at the plane's RAW replicated pivot; the plane is an anchored model the server PivotTos every Heartbeat, so its CFrame arrives as discrete replicated writes and every one snaps the view.

## Checklist

- [ ] Requirements reviewed (this intake)
- [x] Approach agreed (user direction, direct)
- [x] Implementation completed (⏳ not yet playtested)
- [x] Final summary + changelog written
