# Job #119: Rocket Man — bazooka enemy on the camp tower top

**Project**: `roblox.jungle`
**Created**: 2026-08-25 18:26:07
**Status**: Requirements Gathering (intake)

## Requirements / goal

User request, verbatim:

> new task. I want new feature. Each camp will have one new enemie. This will be rocket man, who fires
> with bazooka we added to you. I already altered towers and added "Defender" object. SO 1) find me a
> roblux character from store who is likely army style 2) equip him with bazooka 3) one enemie per camp
> 4) he shoots with 20 s intervals. So targes player then shoots bazookka. You have some seconds to
> escape red circle. 5) if you get close to enemy, you go into close combat 6) you need animations for
> that rocket man - for close combat. 7) rocket mans only spawn at tower top

So: a new enemy type — an army soldier standing on a camp watchtower's top platform, who lobs the
Bazooka's rocket at a player on a 20-second cycle. The rocket's existing 4-second flight plus its red
ground ring is the telegraph the player runs out of. Close in on him and it becomes a melee fight.

## What the user had already done before this job

Both are editor-side work already saved into the GAME place, and this job is written against them:

1. **`RangerTower` was altered.** `ServerStorage.AssetLibrary.Structures.RangerTower` now carries two
   invisible 4×1×2 marker pads inside its `Tower` child, both sitting **0.69 studs above the top
   platform's floor surface** (measured 2026-08-25 in Edit; platform floor `Tower."Floor and Roof".Union`
   top face is 43.00 studs above the model's base, the pads are at 43.69):

   | Pad | Offset from model pivot (X, Z) | Meaning (per the user) |
   |---|---|---|
   | `Defender` | (−0.91, −8.09) — out near the railing | where the rocket man stands and fires |
   | `InnerPlace` | (−0.91, −2.98) — inboard | spawns a loot chest for scraps, **in both towers** |

   ⚠️ Both pads are `Transparency = 1` **and `CanCollide` is whatever `prop()` last set** — `prop()`
   applies `CanCollide = o.collide` to *every* BasePart in the clone and the tower is placed with
   `collide = true`, so as things stand these two pads become invisible collidable slabs on the
   platform. See the plan.

2. **The Bazooka exists.** Job #118 shipped it as the player's weapon: `ItemDefs.Bazooka`,
   `ServerScriptService/Combat/Rocket.luau`, `ReplicatedStorage/Combat/Ballistics.luau` +
   `GroundRing.luau`, and the client-side `RocketFx.local.luau`. This job reuses that machinery rather
   than building a second projectile.

## Decisions taken at intake (user, via wizard, 2026-08-25)

| # | Question | Decision |
|---|---|---|
| 1 | Which army character | **C3 — "US Army Soldier" `11927692797`**, free Creator Store, R15 / 15 Motor6D, 122 parts (85 MeshParts), **0 scripts** |
| 2 | How many, and where | **One per landing site, at the FAR (deep) camp only** |
| 3 | The near camp's tower | **Kept, and stays unmanned** → so a landing site now has TWO towers, and the deep camp gains one (+128 parts/site) |
| 4 | Close combat | **He holds the tower.** Stops firing when the player is close, melees whoever reaches the platform. He never descends |
| 5 | What his blast damages | **Players, the boat, AND friendly fire on other enemies** — everything in the crater |
| 6 | Blast damage | **40 at the centre, 10 at the rim** (player has 100 HP; a camp guard bites for 5.5) |
| 7 | Respawn after death | **None.** Kill him once and the tower is yours for the run — same rule as the hut ambushers |
| 8 | `InnerPlace` | A **loot chest** — `AmmoBox` model, **45–70 salvage**, on **both** towers' platforms |
| 9 | How far out he opens fire | **160 studs** (a camp guard notices you at 95; he is 36 studs up) |
| 10 | Toughness | **110 HP**, Bandit-grade melee (10.8 → 5.53 after `DAMAGE_SCALE`) |
| 11 | Animations | **Reuse clip ids the game already owns** — no sourcing, ships this job |

### Character vetting that produced decision 1

Nine free Creator Store candidates were inserted into `Workspace.RocketManCandidates` in the live place,
scanned for scripts, and measured. **Only four of the nine are R15**, and that is the whole decision:

- An **R6** rig cannot play the R15 clips this game owns. In `EnemyRig` an R6 creature goes down the
  hand-swung-`Motor6D` path (Wolf, Boar) and has *no* animations at all — which fails requirement 6
  outright. Rejected on that basis: `8833489828`, `7703684779`, `77991209055867`, `1480370269`,
  `8124594317`.
- `5095153540` "Soldier Rthro" — R15, best-looking, but **two** soldiers in one model, 14 bundled
  scripts (NPC AI / Ragdoll / Animate / Health) to strip, and Rthro proportions read stretched under
  standard R15 clips.
- `5402943036` / `5421906498` (Vietnam War / Pacific Theater US Soldier) — R15, 19 parts, structurally
  identical to `WesternBandit`; cheapest option but visually plain.
- **`11927692797` "US Army Soldier" — chosen.** R15, 15 Motor6D (the exact `WesternBandit` shape the
  `EnemyRig` Bandit path already drives), MultiCam + tactical helmet so it reads as "army" instantly,
  and **zero scripts**. Costs 122 parts against the Bandit's 18 — affordable because only ONE is ever
  live per landing site and 1–2 sites exist at a time, i.e. it is cheaper than the tower it stands on.
  Carries 1 BillboardGui, 11 bundled Sounds and 50 Decals to be stripped/reviewed at build.

## Checklist

- [x] Requirements reviewed (this intake)
- [ ] **Independent reviewer agent run** - given the symptom/requirement, NOT my theory (GROUND-RULES 8)
- [ ] **Symptom reproduced in PLAY**, at the player's camera, before any fix (GROUND-RULES 7)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] **Proof it works better** captured - before/after from the same camera, in Play
- [ ] Final summary + changelog written
