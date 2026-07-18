# Job #017: Lobby place + launch-pad party + reserved teleport

**Project**: `roblox.jungle`
**Created**: 2026-07-18 23:22:40
**Status**: Requirements Gathering (intake)

## Requirements / goal

P6 (first slice): the two-place front end. **CORRECTED STRUCTURE (Path A, 2026-07-18):** Roblox can't reassign the start place, so the CURRENT root ("Last River COOP", ★) BECOMES THE LOBBY, and a NEW "River Run" place is added for GAMEPLAY. Human adds the new place, publishes the `sync/` gameplay scripts to it, converts the root to the lobby, and gives me the River Run PlaceId (placeholder until then). Greybox AIRFIELD/departure theme. LAUNCH-PAD PARTY system: 3 pads (1-6 each); step on a pad to join its party; a sign shows occupants/count/leader; FIRST player on an empty pad = leader; leader-only Start; leader leaves -> next-longest-on-pad becomes leader; step off to leave. Leader presses Start -> 3s countdown -> ReserveServerAsync + TeleportAsync sends the pad's group TOGETHER into one reserved gameplay server (SafeTeleport pcall+retry; TeleportData = seed/party context only, DataStore for authoritative). Gameplay place then does its existing crash-site staging. Lobby scripts live in a NEW lobby/ repo tree (separate sync target). DEFERRED: shop/skills/boat-upgrades (P8 economy), matchmaking fill/queue, cosmetics. Teleport verified LIVE only (not Studio). Decided with user 2026-07-18.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed — **LIVE-VERIFIED 2026-07-19**: published both places; joining lands in the
      lobby, stepping on a pad + Start teleports the party into the reserved Game server. ✅
- [x] Final summary + changelog written
