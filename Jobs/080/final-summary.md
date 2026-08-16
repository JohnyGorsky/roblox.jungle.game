# Job #080 - Final summary

**Combat feedback - hit particles and floating damage numbers.**

## STOP: built in Job #084, not here

Absorbed into [Job #084](../084/) on 2026-08-16 at the user's call, after the playtest kept returning to
"you can't tell if you hit anything". This job was closed without its own build.

- **The audit in [intake.md](intake.md) is still the reference** for why it was built the way it was -
  in particular that `EnemyHealthBars` already existed and must not be rebuilt, and that #075's flat
  Neon slab was removed in #079 and must not come back as an impact effect.
- **The build, and the answers to this intake's four open questions,** are in
  [../084/final-summary.md](../084/final-summary.md) and [../084/todo.md](../084/todo.md).

Shipped as `Combat/CombatFx.luau` (server seam) + `Combat/CombatFeedback.local.luau` (pooled client
renderer), with the muzzle flash in `WeaponClient` because it must also fire on a miss.

WARNING: one correction worth carrying. The first version set `AlwaysOnTop = false` with no
`StudsOffset`, so every number spawned inside the body of whatever was hit and was invisible in play.
Damage numbers must be lifted clear of the impact point and drawn on top.
