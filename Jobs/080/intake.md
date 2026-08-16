# Job #080: Combat feedback — hit particles and floating damage numbers

**Project**: `roblox.jungle`
**Created**: 2026-08-16 10:19:03
**Status**: ⛔ **ABSORBED INTO [Job #084](../084/) on 2026-08-16 at the user's call** — built there, not here.

> The playtest kept returning to "you can't tell if you hit anything", so hit feedback was folded into
> #084 rather than run as a separate job. This intake's audit is still the reference for WHY it was
> built the way it was; the build and the answers to the four open questions below live in
> [../084/final-summary.md](../084/final-summary.md). **Do not build anything from this file.**

## Requirements / goal

Hit particles on every landed strike (melee, gun, turret) plus world-space floating damage numbers: GREEN for damage the player deals, RED for damage the player or the boat takes. Enemy health bars are ALREADY BUILT (EnemyHealthBars.local.luau, covers the Enemy and CampGuard tags) and are out of scope.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Codebase audited — see below
- [ ] Open questions answered (wizard)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written

---

# The audit (2026-08-16) — what already exists

## ✅ Enemy health bars are DONE. Do not rebuild them.

`sync/StarterPlayer/StarterPlayerScripts/UI/EnemyHealthBars.local.luau` is complete and on-palette
(restyled in Job #075). It is a client `BillboardGui` driven by each enemy's replicated `HP`/`MaxHP`
attributes, with green/amber/red banding.

It already covers **both** enemy kinds — it subscribes to the `Enemy` tag (`EnemyServer` line 56) *and*
the `CampGuard` tag (`ExcursionServer` line 592), so river creatures and camp Bandits both get one.

> ⚠️ **Why it can look like they are missing:** the file deliberately *hides a bar at full health* —
> *"a calm river isn't a field of full green bars. It appears the moment something takes a hit, which is
> also the moment it becomes information."* If bars seem absent, hit something and check again before
> concluding they are broken.

## ❌ Hit particles — nothing exists

`grep` for `ParticleEmitter`/`Emit(` across `ServerScriptService/Combat/` and
`StarterPlayerScripts/Combat/` returns **nothing**. Landing a hit produces no impact VFX at all.

What DOES exist, and must not be confused with it: `EnemyRig` gives water creatures a `splash` emitter
fired on their own attack and death (`EnemyAssets.CreatureVfx.splashOnAttack` / `splashOnDeath`). That is
the creature's own water VFX, not a hit marker, and it is water-only.

> ⚠️ Job #075 shipped a `SwingFx` cream Neon slab in `MeleeClient` as a placeholder. It was **removed** in
> #079 after it read on screen as "some white object flying". Do not reintroduce a flat part as an impact
> effect — this job wants real particles.

## ❌ Floating damage numbers — nothing exists

No damage-number UI anywhere. `BoatStatusCard`, `HealthHud` and `EnemyHealthBars` reference damage only
as bar values.

# Where the damage actually happens (the hook points)

| Source | File | Note |
|---|---|---|
| Melee | `Combat/MeleeServer.server.luau` | server-authoritative; already knows swing-vs-landed-hit |
| Handheld guns | `Combat/WeaponServer.server.luau` | |
| Mounted turret | `Combat/GunServer.server.luau` | |
| Enemy → player | `EnemyServer` bite / `PlayerCombat` | |
| Obstacle → boat | `World/ObstacleServer.server.luau` | applies `Slow` + `Damage` to hull HP |
| Enemy → boat | `EnemyServer` | |

All are **server-side**, which is the right place to originate a damage event; the number itself must be
drawn on the client.

# Open questions for the wizard

1. **Where do numbers spawn from?** One shared `RemoteEvent` broadcasting `(worldPos, amount, kind)` is
   the cheap, uniform option — but it fires per hit, and a shotgun is 6 pellets at 0.7 s. Batch per shot?
2. **Do other players' numbers show?** Seeing the whole crew's damage is busy on a 6-pellet shotgun;
   showing only your own is calmer but hides the medic/gunner contribution in a co-op game.
3. **Crit / kill emphasis?** A bigger or differently-weighted number on a killing blow.
4. **Mobile budget.** This is a mobile-first game. A per-pellet `TextLabel` + `Tween` at sustained fire is
   real cost; a pooled set of labels is the safe pattern.

# ⚠️ Constraints this job must respect

- **Damage values are not changing.** This is presentation only. Jobs 015/053/058 tuned the numbers.
- **Mobile-first** — pool and cap the labels; do not allocate per hit unbounded.
- `GameSoundscape`'s stacking lesson applies to VFX too: one emitter reused beats one per hit.
