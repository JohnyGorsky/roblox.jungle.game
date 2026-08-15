# Job #078: Animals & enemies on real assets — models, animations, sounds, glowing eyes

**Project**: `roblox.jungle`
**Created**: 2026-08-15 18:46:18
**Status**: **Audit done — awaiting decisions.** See "Open questions" at the bottom.

## Requirements / goal

Every enemy in Last River is greybox: `EnemyServer` builds a `Body` part + `Snout` part + two Neon eyes,
anchored and moved by `PivotTo`, with no Humanoid, no rig and no animation. Give every creature a real
model, a rig with animations, a sound set, and keep the Job 039 glowing-eyes treatment working.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Asset audit done — what exists, what each creature needs (below)
- [x] Creator Store searched for every creature (below)
- [ ] Open questions answered (wizard)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written

---

# The audit

## What exists today — measured from the code

| Thing | State |
|---|---|
| `EnemyDefs.Defs` | **5 enemies**: sea = `Crocodile`, `Piranha`, `RiverHippo`; land = `Panther`, `Boar` |
| Rendering | `EnemyServer.spawnEnemy` — a `Body` Part (`def.size`, `def.color`, SmoothPlastic) + a `Snout` Part at 60/70/35% of it. **That is the entire enemy.** |
| Movement | `Anchored = true`, kinematic, driven by `PivotTo`. **No Humanoid, no AnimationController, no Animator.** |
| **Glowing eyes** | ✅ **Already built (Job 039)** and **attachment-aware**: `addEyes` looks for `EyeLeft`/`EyeRight` Attachments anywhere in the model and puts Neon eyes at their `WorldCFrame`; only if they're absent does it fall back to an offset computed from `def.size`. |
| `CampGuard` | ⚠️ **A SECOND, SEPARATE greybox path** in `ExcursionServer.spawnGuard` — reuses `EnemyDefs.Defs.Panther` but builds its own `block("Body", …)` and gets **no eyes at all**. Any model work has to cover both call sites. |
| Enemy audio | **None uploaded.** Registry `audio.md` has zero jungle creature SFX (`monster_roar`/`golem_roar`/`skeleton_roar` are *Defender's*). |
| Local audio files | 2, **not uploaded**: `assets/Objects/Monsters/Aligator/aligator_hissing.mp3`, `assets/Objects/Monsters/monster_bite_1.mp3` |
| Animations | **None.** Nothing in the game plays an enemy animation. |
| Concept art | `assets/Enemies/`: `Crocodile.png`, `Hippo.png`, `Anaconda.png`, `Puma.png` |

### ⚠️ Two mismatches to settle before building

1. **Concept art doesn't match the code.** There is art for **Anaconda** and **Puma**, but `EnemyDefs`
   has neither — it has `Panther` (which is roughly Puma) and no snake at all. So either the art is
   ahead of the code (add an Anaconda enemy) or the art is stale.
2. **No art for `Piranha` or `Boar`**, which *are* in the code.

## What each creature needs

`E` = EyeLeft/EyeRight attachments (cheap, and the glowing-eyes system is already waiting for them).

| Creature | Size (studs) | Model | Rig + animations needed | Sounds needed | Notes |
|---|---|---|---|---|---|
| **Crocodile** (sea) | 6×3×16 | ⭐ best Store options of the five | idle-float, **swim**, lunge, bite, death | idle hiss, aggro, bite, hurt, death | ✅ `aligator_hissing.mp3` exists locally, needs upload. Concept art exists. |
| **Piranha** (sea) | 2×1.2×4 | ❌ **nothing usable on the Store** | swim-loop, dart, nibble | swarm-nibble loop, small splash | Tiny and spawns in numbers → **cheapest model, fewest bones.** Shoal of 1 mesh. |
| **RiverHippo** (sea) | 8×5×12 | Store options are old/realistic | idle-wallow, swim, charge, bite, death | grunt, bellow (aggro), bite, hurt, death | Concept art exists. Tanky mini-threat. |
| **Panther** (land) | 5×4×11 | Store options are old low-poly | idle, prowl/walk, **run**, pounce, claw, death | growl (idle), snarl (aggro), attack, hurt, death | Concept art is called **Puma**. Also used by `CampGuard`. |
| **Boar** (land) | 4×3×7 | Store options are old low-poly | idle, trot, **charge**, gore, death | snort (idle), squeal (aggro), impact, hurt, death | No concept art. Pack hunter — spawns in numbers. |
| **Anaconda** *(new?)* | — | — | coil-idle, slither, strike, constrict | hiss, strike, hurt | **Only exists as concept art.** Adding it is a gameplay change, not an art swap. |

Every one also needs: `E` attachments · `CollisionFidelity` set (standing Meshy rule) · all parts
`Anchored`/`CanCollide=false` to match the current kinematic movement · a `roblox-assets` SECURITY scan.

## Creator Store search results (done 2026-08-15, free assets)

**Verdict: the Store is a poor fit for four of the five.** The results are mostly 2018-era realistic
models — the wrong register for our stylized look (STYLEGUIDE §2: "detailed-stylized, NOT flat low-poly…
70% stylized Roblox"), which is exactly why the campfire in Job #077 was built rather than sourced.

| Creature | Best candidates found | Assessment |
|---|---|---|
| Crocodile | `[NPC Killer] Nile Crocodile` **9944877977** · `Crocodile` **10899936048** · `rigged crocodile with bone system` **6806168763** · `Crocodile Pal` **255119149** (by Roblox) | **Usable.** The "rigged … with bone system" one is the interesting one if we want a skinned rig. ⚠️ Anything named "[NPC Killer]" ships **scripts** — scan and strip. |
| Piranha | **NOTHING.** A "piranha fish" search returns `Night Angler`, generic `fish`, and unrelated junk. | **Meshy.** |
| Hippo | `Hippopotamus` **11557275302** · `Realistic Hippo` **13535692005** · `Hippo` **3563224742** | Realistic register, likely off-style. |
| Panther | `Panther` **2505492397** · `Male Panther` **1827794461** / **1641243741** · `Black P` **455662544** | Old, low quality. One literally says *"I need someone to animate this model please"*. |
| Boar | `wild boar` **1093988626** · `Wild Boar` **71648589** / **9032342608** / **5365380186** | Old, low quality. |

**Audio: the Store is unusable.** Searching `crocodile growl hiss` returned *"Sandstorm part 2"*,
*"Disturbed Whispers"* and a piano sample; `animal roar attack` returned a football chant and
*"PIANOOOO"*. Roblox audio search does not work for this. **Every creature sound will have to come from
outside (freesound/Epidemic-style) and be uploaded by you** — the same route all existing Jungle audio
took, and remember `night_starts` was rejected twice by moderation, so budget for re-uploads.

## Recommendation

**Meshy for the creature models** (matching how the plane, pilot and all four station buildings were
made), with the **Crocodile as the one candidate worth trying from the Store first** because good
options exist there and it is the signature river threat. That also gives one consistent art style
across all five, which five different Store authors would not.

## ⚠️ The architectural question this job cannot dodge

Enemies today are **anchored parts moved by `PivotTo`** — there is no Humanoid and no `Animator`, so
**nothing can play an animation**. Options:

- **A — `AnimationController` + `Animator`** on the model, keep `PivotTo` movement. Cheapest, keeps the
  server-authoritative kinematic AI exactly as tuned, animations are cosmetic. Needs skinned/bone rigs.
- **B — Real `Humanoid` + `PathfindingService`.** Much more expensive per NPC and would re-open the AI
  tuning of Jobs 006–009 and 053/058. **Not recommended in an art job.**
- **C — No skeletal animation**; sell motion with procedural CFrame (tail sway, jaw snap) + VFX.
  Cheapest by far on mobile, and works with single-mesh models.

`roblox-animation` + `roblox-ai` should be consulted before this is decided.

---

# Decisions taken (wizard, 2026-08-15)

| | |
|---|---|
| **Source** | **Meshy for all creatures.** One consistent art style across the whole roster — the same route the plane, pilot and all four station buildings took. The Store's free animals are 2018-era realistic models from different authors and would not read as one game. ⚠️ The Crocodile Store options were genuinely usable and are recorded above if we ever need a fallback. |
| **Animation** | **`AnimationController` + `Animator`, keeping `PivotTo` movement.** Animations are cosmetic only, so the server-authoritative AI tuned across Jobs 006–009, 053 and 058 is not touched. Requires skinned/bone rigs out of Meshy (its auto-rig + animation library). |
| **Roster** | **Add `Anaconda` as a 6th enemy** — the concept art exists and it earns its place. ⚠️ This is a **gameplay change, not an art swap**: it needs stats, a category (sea or land), spawn rules and a balance pass, so it is scoped *after* the pipeline is proven. `Panther` keeps its name. |
| **Scope** | **`Crocodile` + `Panther`/`CampGuard` first.** The signature river threat and the enemy you fight on foot — between them they prove the whole pipeline (Meshy model → rig → `EyeLeft`/`EyeRight` → `Animator` → sound) end to end, and they force the **two separate greybox paths** (`EnemyServer` and `ExcursionServer.spawnGuard`) to be unified early. `Piranha`, `RiverHippo`, `Boar` and the new `Anaconda` follow once it works. |

## Consequences of those decisions

- **The `CampGuard` duplicate path must be fixed in this job**, not deferred — `ExcursionServer` builds
  its own greybox body and gets **no eyes**, so a Panther model that only lands in `EnemyServer` would
  leave camps still grey.
- **Audio is a hard dependency on you.** Roblox's audio search is unusable (proved above), so creature
  sounds must be sourced externally and uploaded. Budget for moderation rejections — `night_starts` was
  rejected twice in Job #073.
- `assets/Objects/Monsters/Aligator/aligator_hissing.mp3` and `monster_bite_1.mp3` already exist locally
  and just need uploading — that is the Crocodile's idle hiss and a bite, i.e. 2 of its 5 sounds.
- **Meshy MCP is currently disconnected** in this session; it needs reconnecting before generation.
- Glowing eyes stay on every creature (current Job 039 behaviour) — not raised as a question, so
  unchanged. Say if you want them to become a night-only signature instead.
