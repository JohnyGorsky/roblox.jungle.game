# Implementation Plan — Job #006: P3 POC (first alligator)

**Project**: `roblox.jungle`
**Created**: 2026-07-18
**Status**: ✅ Completed (2026-07-18) — see final-summary.md

## Goal
Prove the core survival tension: an alligator that **chases the boat and bites it** (boat HP + fail
state), and you can **shoot it dead**. Greybox; server-authoritative; built on Jobs #003 + #005.

## Approach
- **Croc = Humanoid-less NPC** (roblox-ai "swarm perf" path). Open water has no obstacles between croc
  and boat, so skip pathfinding — **direct steering with lead prediction** toward the boat, kinematic
  `PivotTo` each step, clamped to the water surface. Cheap and reliable for a POC.
- **Data-driven + extensible:** `EnemyDefs` holds stats + a **category ("sea"/"land")** and a
  **time-of-day strength hook**, so land threats + day/night scaling slot in later (GAME.md "Threats").
- **Server-authoritative** throughout (aggro, movement, damage).

## Build order (verify each in Studio)
1. **`EnemyDefs`** (ReplicatedStorage/Enemies) — Crocodile stats (hp, speed, aggro/bite ranges, damage).
2. **`EnemyServer`** (ServerScriptService/Enemies) — waits for boat+river, spawns one croc near the
   boat; AI loop: detect (magnitude ≤ aggroRadius) → chase (steer to boat + lead) → bite (in range,
   cooldown) → damage the boat. Croc holds an HP attribute (for shooting).
3. **Boat HP** — `BoatServer` sets `MaxHP`/`HP` attributes on the Boat model + handles the **fail state**
   (HP ≤ 0 → run over). EnemyServer applies bite damage + a hit flash.
4. **Shoot back** — a mobile-friendly weapon (leaning: tap → auto-target nearest croc, server-validated
   hitscan) that reduces croc HP → death/despawn. *(Second slice; confirm aiming style when we get here.)*

## Deferred (later P3 slices)
Player health + downed + **bandage revive**; multiple crocs + **spawn/pacing director**; **land threats**
+ **day/night strength**; formal **gunner role** (P2); real Meshy croc model + swim/bite anims (art).

## Success test
- [ ] Croc detects the boat, swims to intercept (leads a moving boat), and bites it.
- [ ] Boat HP drops with feedback; hits 0 → fail.
- [ ] Player can kill the croc; it despawns. Outrunning it at full throttle works.
