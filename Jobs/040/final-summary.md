# Final Summary — Job #040: Carry riders with the moving boat (no deck slide)

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · Fixes FINDING 0000. Game-only.

## The bug
Standing (unseated) on the boat, the player slowly slid across the deck — a client-owned character on a
**server-owned moving boat** isn't carried smoothly (Roblox's moving-platform carry breaks across network
ownership + replication lag), so the deck slipped under their feet as the boat drifted/drove.

## The fix (client-side — server boat physics untouched)
`StarterPlayer/StarterPlayerScripts/Boat/BoatRideClient.local.luau` (new): each `RenderStepped`, if the local
character is **standing on the boat** (down-raycast hits a boat part) and **not seated**, apply the hull's
per-frame transform delta (`hull.CFrame * prevHullCF:Inverse()`) to the character's root — carrying it with
the boat (position + yaw) *on top of* normal walking. Seated players are skipped (the seat already carries
them). No server / network-ownership change — deliberately avoids destabilizing the fragile boat physics
(the "boat disappears" bug came from anchoring a dynamic boat with a rider).

## Verified (live in Studio)
- [x] Analyzer-clean.
- [x] Boat drifted **2.4 studs over 3s** while the rider's deck-relative offset changed **0.00 studs** —
      carried perfectly (previously they'd slide the full drift).
- [~] Walking-while-carried is by construction (the carry is added on top of Humanoid movement) — the 0.00
      slide while stationary confirms the carry itself.

## Notes / follow-ups
- **Not committed.** Test account reset to clean.
- Purely client-side + cheap (one down-raycast/frame). Applies whenever the boat moves (drift or driven), not
  just at docks.
- Airborne edge (jumping over a moving boat) isn't carried mid-jump — acceptable for POC.
- FINDING 0000 marked fixed.
