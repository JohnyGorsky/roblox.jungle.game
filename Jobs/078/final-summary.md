# Job #078 - Final summary

**Every creature onto real models, with rigs, animations, sounds, and the glowing eyes preserved.**

> WARNING: **Written retroactively on 2026-08-16** as part of Job #084's docs-debt sweep. The work
> shipped earlier; this summary is reconstructed from the intake and from the code as it stands today,
> so treat the *code* as authoritative where they disagree. The intake's checklist was never ticked
> and is stale.

## What shipped

`EnemyRig.luau` (~646 lines) and `EnemyAssets.luau` (~345 lines) - **one shared creature builder**,
replacing two separate greybox paths.

That consolidation was the point of the job. Before it, `EnemyServer` built a `Body` + `Snout` + Neon
eyes, and `ExcursionServer.spawnGuard` built its **own** greybox with no eyes at all. Two builders for
one creature meant sourcing a model would have fixed the river creatures and left every camp guard a
grey box. Both call sites now go through `EnemyRig.build`.

The rig carries: the sourced model, the Job 039 glowing eyes (attachment-aware - `EyeLeft`/`EyeRight`
anywhere in the model, falling back to a `def.size` offset), an Animator with idle/move/attack/death
tracks, a sound set (aggro/idle/attack/death), and water VFX for the swimmers.

## Two things that are load-bearing

- **`def.size` remains the hitbox the AI reasons about.** The sourced art hangs off it and never becomes
  it - bite range, aggro distance, leashing, culling and `stepToward` all read `enemy.PrimaryPart`.
  Swapping the PrimaryPart for a mesh of a different size would silently retune the whole AI.
- **Facing.** A model authored facing +Z swims backwards down the river; that is what `yawOffset = 180`
  is for. The crocodile was caught exactly that way - eyes right, body reversed.

## Known follow-on, fixed later in Job #084

`EnemyRig.die` plays the cues, topples the body and then despawns. That was correct, but the caller
cleared `state[enemy]` first, and `tickEnemy`'s opening guard despawns any stateless enemy - so the
corpse was destroyed on the next frame and the death was still invisible in play. Job #084 added a
`dying` set to keep the tick off the body. **If you touch the death path, read that note first.**
