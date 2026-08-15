# Job #078 — what's MISSING, one by one

Only things that do **not** exist yet. Tick them off as you go. Send me the ids and I'll wire them into
`sync/ServerScriptService/Enemies/EnemyAssets.luau` — the one place a creature id is written.

**In scope: Crocodile + Panther.** Nothing else is needed to finish this job.

> Nothing here blocks anything else. The wiring is already live and degrades: no model → greybox,
> no animation → no animation, no sound → silence.

---

# A. MODELS — 2 missing (Meshy, text-to-3D)

**Settings for both:** stylized / low-poly · PBR texture · **1.5–4k tris** · **GLB** · then auto-rig.
**Append this style line to every prompt** (it's what keeps them matching the game):

```
stylized low-poly game asset, chunky readable silhouette, hand-painted texture, matte not glossy, neutral pose, plain background
```

### ✅ A1 — Crocodile — DONE
Imported as `ServerStorage.AssetLibrary.Enemies.Aligator` (a single **MeshPart**, 7.10 × 4.00 × 20.68,
PBR via SurfaceAppearance, **0 scripts**). Wired with `scale = 0.774` → 5.5 × 3.1 × 16.0 against the
6 × 3 × 16 hitbox, and **`yawOffset = 0`** — the mesh is authored head-at-**-Z**, which is already our
forward.

**Orientation and eye placement were MEASURED, not eyeballed.** Raycast cross-sections along the mesh
(`CollisionFidelity = PreciseConvexDecomposition` on a temp copy) gave:
- +Z end tapers to **0.24 studs wide**, drooping to y **-1.67** → the **tail**
- -Z end stays blunt and level at **1.44 wide** → the **snout**
- twin bumps at **x = ±0.6…0.9, y = 1.88, z = -6.0…-5.1** with a dip between → the **eye ridges**

→ `EyeLeft`/`EyeRight` Attachments on the source mesh at **(±0.75, 1.90, -5.60)**. In game the eyes land
at world Y ≈ 12.25 against a water surface of 12 — just breaking the surface, which is the look a
lurking crocodile should have.

⚠️ Do not "correct" the facing or the eyes from a screenshot; both were got wrong that way first. Re-run
the raycast profile instead.

<details><summary>original prompt (kept for the record)</summary>
Target in-game size **6 × 3 × 16 studs**.
```
a large river crocodile, long armoured snout, ridged scaly back, thick tail, dark olive-green with a pale
underbelly, mouth slightly open showing teeth, standing on four short legs
```
</details>

### ☐ A2 — Panther  *(must be named exactly `Panther`)*
Target in-game size **5 × 4 × 11 studs**. Also becomes every **camp guard**.
```
a sleek black jungle panther, muscular shoulders, long tail, prowling stance, matte charcoal-black fur
with faint darker rosettes
```

**Both models must have, before they ship:**
1. **`EyeLeft` + `EyeRight` Attachments on the head, at the eyes.** The glowing-eye system is already
   attachment-aware — with them the eyes sit in the sockets; without them they float in front of the chest.
2. **Facing `-Z`.** Creatures are driven by `CFrame.lookAt(pos, pos + direction)`. If it faces `+Z` it
   moves backwards — tell me and I'll set `yawOffset = 180` rather than you re-exporting.
3. Dropped into `ServerStorage.AssetLibrary` (any group) and **the place saved** — that path is not
   Rojo-synced, so unsaved models vanish (the Bahay Kubo trap from Job #077).

---

# B. SOUNDS

## B.1 — 2 you already have, just upload them

Creator Hub → Creations → Development Items → Audio → Upload Audio. Under 6 s is free.

| ☐ | Local file | Upload as | Description |
|---|---|---|---|
| ☐ B1 | `assets/Objects/Monsters/Aligator/aligator_hissing.mp3` | `croc_idle` | Crocodile idle hiss — Last River enemy SFX |
| ☐ B2 | `assets/Objects/Monsters/monster_bite_1.mp3` | `croc_attack` | Crocodile bite — Last River enemy SFX |

> B2 is a *generic* monster bite. If you're on Pixabay anyway, `alligator bite` / `jaw snap` would give
> the croc a more specific attack. Optional — the generic one works.

## B.2 — 8 missing, find on Pixabay

Short **mono**, **under ~3 s**, .mp3 or .ogg. Upload under the exact `Asset name`.

| ☐ | Asset name | What it is | Pixabay prompt |
|---|---|---|---|
| ☐ B3 | `croc_aggro` | locks on, starts the chase | `crocodile growl` · `alligator bellow` · `reptile roar` |
| ☐ B4 | `croc_hurt` | took a bullet | `animal pain grunt` · `creature hurt growl` |
| ☐ B5 | `croc_death` | killed | `monster death growl` · `animal dying groan` |
| ☐ B6 | `panther_idle` | low growl while prowling | `panther growl` · `big cat low growl` |
| ☐ B7 | `panther_aggro` | the pounce warning | `panther snarl` · `leopard roar` · `jaguar growl` |
| ☐ B8 | `panther_attack` | claw / bite | `big cat attack snarl` · `cat hiss attack` |
| ☐ B9 | `panther_hurt` | took damage | `big cat yelp` · `animal pain cry` |
| ☐ B10 | `panther_death` | killed | `big cat death growl` · `animal last breath` |

> ⚠️ **Grab a second choice for B3 and B7.** Those two are the "it's coming" cues that have to cut
> through the boat engine, and Roblox audio moderation is unpredictable — `night_starts` was rejected
> **twice** in Job #073 while its sibling uploaded fine.

---

# C. ANIMATIONS — 4 missing (Panther only)

> ✅ **The Crocodile needs NO animations.** Water creatures are animated procedurally now (sunk to the
> waterline + bob/roll/wag + wake + splash) — see the revised decision in the intake. Same will apply to
> Piranha and RiverHippo. Only LAND creatures need a rig.

## Panther (land)

Cosmetic only — movement stays `PivotTo`, so none of these can break the AI.
Meshy auto-rig already returns **walk + run** (included in the 5-credit rig); `meshy_animate` is
3 credits each for the rest.

| ☐ | Key | What it is |
|---|---|---|
| ☐ C1 | `idle` | standing, tail flick |
| ☐ C2 | `move` | prowl / run — **free with the Meshy rig** |
| ☐ C3 | `attack` | pounce / claw swipe |
| ☐ C4 | `death` | collapse |

---

# D. Deferred — not needed for this job

Listed only so you can search once instead of five times.

| Creature | Model prompt (+ style line) | Sound prompts |
|---|---|---|
| Piranha | `a small piranha fish, deep flat body, blunt jaw with jagged teeth, silver-grey scales with a red belly` | `fish frenzy water` (looping bed, 3–5 s) · `small bite water` |
| RiverHippo | `a bulky river hippopotamus, huge blunt head, wide open jaws with tusks, thick grey-purple hide, short stubby legs` | `hippo grunt` · `hippo bellow` · `hippo bite` · `large animal dying` |
| Boar | `a wild jungle boar, bristly brown-black fur, upward curving tusks, thick shoulders and a low head, charging stance` | `wild boar snort` · `boar squeal angry` · `heavy impact thud` · `pig squeal pain` |
| Anaconda | `a giant green anaconda snake, thick coiled body, olive-green with dark blotches, head raised ready to strike` | `snake hiss` · `snake strike` |

⚠️ **Anaconda is a new enemy, not an art swap** — it needs stats, a category and spawn rules before any
model is worth generating.

⚠️ **Piranha has nothing usable on the Creator Store** (searched: returns `Night Angler` and generic
fish), so it is Meshy or nothing.

---

## Totals

| | Missing | Notes |
|---|---|---|
| Models | **1** (Panther) | Crocodile ✅ done — `Aligator` mesh, wired |
| Sounds | **3 to find** (Panther idle/aggro/attack) | Crocodile ✅ all 5 done |
| Animations | **4** (Panther only) | water creatures need none |
