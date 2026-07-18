# Job #008: P3: player health, downed state + bandage revive

**Project**: `roblox.jungle`
**Created**: 2026-07-18 16:02:24
**Status**: ✅ Completed (2026-07-18)

## Requirements / goal

The co-op heart. Players get an HP attribute; crocs bite nearby players (not just the boat). At 0 HP a player enters a DOWNED state (can't move, bleed-out timer) instead of dying. A teammate revives by holding an interact (ProximityPrompt) near them, consuming a scarce bandage; bleed-out expiry -> real death/respawn. Server-authoritative. Builds on Jobs 006/007 (crocs, weapon). Greybox (no ragdoll/anim yet). Skills: roblox-scripting (server authority, attributes), roblox-ai (croc target selection). Deferred: paid self-revive hook (P8 monetization), ragdoll/downed animation (P9), bandage pickups/inventory.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] Final summary + changelog written
