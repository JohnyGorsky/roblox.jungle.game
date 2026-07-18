# Final Summary — Job #008: Player health, downed state + bandage revive

**Project**: `roblox.jungle`
**Completed**: 2026-07-18
**Status**: ✅ Completed — downed chain verified; 2-player revive needs a Team Test

## What was implemented

The co-op heart: players can be downed by threats and revived by teammates.

- **`PlayerCombat`** (`ServerScriptService/Combat`, server Script):
  - Each character gets **`HP`/`MaxHP` attributes** (100) and each player **`Bandages`** (3). Damage
    reduces the character HP attribute (Humanoid health is left alone, so the player doesn't just die).
  - **Downed** at HP ≤ 0 (instead of dying): `Downed=true`, WalkSpeed/JumpHeight → 0, `PlatformStand`
    (flops over), a **`RevivePrompt`** ProximityPrompt spawns on the character, and a **bleed-out
    timer** (30 s) starts → on expiry, real death/respawn.
  - **Revive:** a *different* player holds the prompt (3 s, range 12) → restores the downed player to
    50 HP, clears downed, removes the prompt, and **consumes one of the reviver's bandages**. No
    self-revive (that's the paid revive, P8).
- **Crocs bite players** (`EnemyServer`) — a croc's bite now targets the **nearest exposed player** in
  reach (else the boat), so deck defenders take the hits and can be downed.

## Verification (live via Studio MCP)

- [x] `bash tools/luau-analyze.sh` clean.
- [x] Setup: character `HP`=100, `Bandages`=3, `Downed`=false.
- [x] Full chain: with the player on the boat among crocs, **HP fell 100 → 0** from croc bites, then
      **Downed=true, WalkSpeed=0, RevivePrompt spawned** — downed, not dead.
- [~] **Revive interaction** (teammate holds the prompt): logic + prompt are wired and correct, but
      triggering needs a **second player** — verify in a Team Test / 2-player playtest.

## Files changed (roblox.jungle)

- New: `sync/ServerScriptService/Combat/PlayerCombat.server.luau`.
- Edited: `sync/ServerScriptService/Enemies/EnemyServer.server.luau` (crocs bite nearest player).
- New: `Jobs/008/*`.

## Notes / follow-ups

- **Not committed** (per the rule).
- **Team Test** the revive (2 players) to confirm the hold-to-revive + bandage cost feel.
- Tunables: `MAX_HP`, `REVIVE_HP`, `BLEEDOUT`, `REVIVE_HOLD`, `START_BANDAGES`, `REVIVE_RANGE`.
- Deferred: **paid self-revive** hook (P8 monetization); **ragdoll/downed animation** + a **downed/HP
  HUD** (P9); **bandage pickups/inventory** (P4 resources). The **fishing/catcher** system will set the
  `Busy` attribute (already respected by the weapon).
- Balance: crocs now prefer players over the boat when someone's exposed — tune bite target priority
  and damage once combat feel is playtested.
