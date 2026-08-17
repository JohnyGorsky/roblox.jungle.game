# Final Summary — Job #093

**Project**: `roblox.jungle`
**Completed**: 2026-08-17
**Status**: ✅ Code complete, both trees analyzer-clean — ⏳ awaiting playtest

Two tuning asks from the 2026-08-17 session.

---

## Item 1 — Salvage for killing land creatures

> *"killing enemies should give some scrap, at least something"* → narrowed by the user to
> **land only (bandit, boar, wolf), 6 Salvage each.**

Sea creatures pay nothing — you aren't salvaging scrap off a fish, and the river fight is already paid
for by making progress (`SalvageServer`'s distance drip).

New **`Economy/KillReward.luau`**, called from the three damage sites.

### Why the damage sites and not the death check

The two loops that notice `HP <= 0` — `EnemyServer.tickEnemy` and `ExcursionServer.tickGuard` — are the
natural place to spot a death, and **neither knows who killed it**. `GunServer`, `WeaponServer` and
`MeleeServer` do, so the killing blow is detected there.

### Three details worth knowing

- **`Category` is read off the model**, not looked up in `EnemyDefs`. `EnemyRig.build` writes it on every
  creature, so one test covers riverbank creatures (model named after the def) *and* camp guards (model
  named `CampGuard`, carrying a separate `GuardType`) — no name matching, and nothing to update when a
  creature is added.
- **Two guards against double payment**, both needed: `before > 0` restricts it to the killing blow
  (corpses linger while `EnemyRig.die` topples them, so later hits would otherwise each read as a kill),
  plus a `SalvageAwarded` marker on the model to cover the three separate call sites and two crew members
  firing on the same tick.
- **The Scavenger's Instinct skill is deliberately NOT applied.** It is described as boosting the
  *looter's* payout; a kill is not a loot pickup, and folding combat into it would make the skill's own
  description wrong.

In `WeaponServer` the shooter is resolved with `Players:GetPlayerFromCharacter(char)` rather than
threading a player through `fireRay` — a shotgun calls that once per pellet, and changing its signature
would touch every caller for a value needed only on the frame something dies.

### Scale check

6 Salvage sits above a tenth of a bandage (50) and well under a loot crate (40–80), so fighting pays
without out-earning raiding. Distance drip is ~300 a run for reference.

---

## Item 2 — Wolf and Bandit hit 10% softer

> *"reduce enemies (on land) bandits and wolf hit to me by 10%, they are a little bit too strong"*

`biteDamage` **12 → 10.8** on both — an exact 10% cut.

**Fractional is intentional, not a slip.** Bite damage is already fractional in play: `applyBite`
multiplies it by `EnemyDefs.strengthFor(...)`, and camp guards further scale it by the village strength
ramp. Rounding to 11 would have been an 8.3% cut, not the 10% asked for.

**Boar was left at 10.** The user named only bandits and wolf, and boar was already the weakest of the
three. Wolf and Bandit are also the only two that exclusively fight *people* — they're camp guards, so
this change cannot weaken anything aimed at the boat.

---

## Files changed

| File | Change |
| --- | --- |
| `Economy/KillReward.luau` | **new** — 6 Salvage for a land kill, with the double-pay guards |
| `Combat/GunServer.server.luau` | calls `onEnemyDamaged` after writing HP |
| `Combat/WeaponServer.server.luau` | same, resolving the shooter from the character |
| `Combat/MeleeServer.server.luau` | same |
| `Enemies/EnemyDefs.luau` | Wolf + Bandit `biteDamage` 12 → 10.8 |

Game tree only.

## Verification

- [x] `tools/luau-analyze.sh` — GAME clean
- [x] `tools/luau-analyze.sh --lobby` — no new diagnostics
- [ ] ⏳ **Playtest:**
      1. kill a bandit/wolf/boar → Salvage goes up by exactly 6, once, per creature;
      2. kill a croc/piranha/hippo → no Salvage;
      3. hit an already-dead corpse → no extra Salvage;
      4. two players kill the same creature → paid once;
      5. wolves and bandits hit measurably softer; boar unchanged.
