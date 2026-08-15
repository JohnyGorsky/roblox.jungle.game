# Job #078 — asset shopping list

Everything the creatures need, with the exact prompt/search term to use. **Fill the `rbxassetid` column
as you upload, then paste it into `sync/ServerScriptService/Enemies/EnemyAssets.luau`** — that file is
the only place ids are written, and a blank id is not an error (no model → greybox, no sound → silence).

**In scope now: Crocodile + Panther.** The rest are listed so you can search once rather than five times.

---

## 1. Models — Meshy (text-to-3D)

**Settings for all of them:** stylized / low-poly · **PBR texture** · target **1.5–4k tris** ·
**GLB** export · then **auto-rig** (Meshy rig = 5 credits, includes walk + run).

**Style line to append to every prompt** — this is what keeps them matching the game
(STYLEGUIDE §2: detailed-stylized, ~70% stylized Roblox / 20% cinematic / 10% realism):

> `stylized low-poly game asset, chunky readable silhouette, hand-painted texture, matte not glossy, neutral pose, plain background`

| # | Creature | In-game size (studs) | Meshy prompt |
|---|---|---|---|
| M1 | **Crocodile** | 6 × 3 × 16 | `a large river crocodile, long armoured snout, ridged scaly back, thick tail, dark olive-green with a pale underbelly, mouth slightly open showing teeth, standing on four short legs` + style line |
| M2 | **Panther** | 5 × 4 × 11 | `a sleek black jungle panther, muscular shoulders, long tail, prowling stance, matte charcoal-black fur with faint darker rosettes` + style line |
| M3 | Piranha *(later)* | 2 × 1.2 × 4 | `a small piranha fish, deep flat body, blunt jaw with jagged teeth, silver-grey scales with a red belly` + style line |
| M4 | RiverHippo *(later)* | 8 × 5 × 12 | `a bulky river hippopotamus, huge blunt head, wide open jaws with tusks, thick grey-purple hide, short stubby legs` + style line |
| M5 | Boar *(later)* | 4 × 3 × 7 | `a wild jungle boar, bristly brown-black fur, upward curving tusks, thick shoulders and a low head, charging stance` + style line |
| M6 | Anaconda *(new enemy)* | TBD | `a giant green anaconda snake, thick coiled body, olive-green with dark blotches, head raised ready to strike` + style line |

### ⚠️ Two things every model must have before it ships

1. **`EyeLeft` and `EyeRight` Attachments on the head, at the eyes.** The glowing-eyes system (Job 039)
   is already attachment-aware — with them, the Neon eyes sit in the sockets and track the head; without
   them they fall back to a guess from the hitbox size and float in front of the chest.
2. **Forward is `-Z`.** Every creature is driven by `CFrame.lookAt(pos, pos + direction)`. If the model
   is authored facing `+Z` it will swim backwards — set `yawOffset = 180` in `EnemyAssets` rather than
   re-exporting.

Also: `CollisionFidelity` per the standing Meshy rule, and a `roblox-assets` SECURITY scan on anything
that did not come out of Meshy.

---

## 2. Sounds — Pixabay

**Format:** short **mono** clips, **.mp3 or .ogg**, ideally < 3 s except the idle beds.
**Naming:** upload as the `Asset name` below so the registry, the code key and the Creator Hub agree.

> ⚠️ Roblox audio moderation rejects things unpredictably — `night_starts` was rejected **twice** in Job
> #073 while its sibling uploaded fine. Grab a **second choice** for anything critical.

### Crocodile — the signature river threat *(in scope)*

| Asset name | What it is | Pixabay search prompt | Notes |
|---|---|---|---|
| `croc_idle` | lurking hiss, fires occasionally while it waits | `alligator hiss` · `crocodile hiss` | ✅ **You already have this** — `assets/Objects/Monsters/Aligator/aligator_hissing.mp3`, just needs uploading. 1–2 s |
| `croc_aggro` | the moment it locks on and starts the chase | `crocodile growl` · `alligator bellow` · `reptile roar` | Must cut through the engine — this is the "it's coming" cue. 1–2 s |
| `croc_attack` | the lunge/bite | `monster bite` · `flesh chomp bite` · `jaw snap` | ✅ **You already have one** — `assets/Objects/Monsters/monster_bite_1.mp3`. 0.5–1 s |
| `croc_hurt` | took a bullet | `animal pain grunt` · `creature hurt growl` | 0.5–1 s |
| `croc_death` | killed | `monster death growl` · `animal dying groan` | 1–2 s |

### Panther — land ambusher + every camp guard *(in scope)*

| Asset name | What it is | Pixabay search prompt | Notes |
|---|---|---|---|
| `panther_idle` | low growl while prowling | `panther growl` · `big cat low growl` | 1–2 s |
| `panther_aggro` | the pounce warning | `panther snarl` · `leopard roar` · `jaguar growl` | The one you hear before you're hit. 1–2 s |
| `panther_attack` | claw/bite | `big cat attack snarl` · `cat hiss attack` | 0.5–1 s |
| `panther_hurt` | took damage | `big cat yelp` · `animal pain cry` | 0.5–1 s |
| `panther_death` | killed | `big cat death growl` · `animal last breath` | 1–2 s |

### Later creatures — grab them in the same sitting if it's easy

| Asset name | Pixabay search prompt |
|---|---|
| `piranha_swarm` | `fish frenzy water` · `piranha feeding frenzy` — **looping bed**, 3–5 s |
| `piranha_bite` | `small bite water` · `fish nibble` |
| `hippo_idle` | `hippo grunt` |
| `hippo_aggro` | `hippo bellow` · `hippo roar` |
| `hippo_attack` | `hippo bite` · `heavy jaw snap` |
| `hippo_hurt` / `hippo_death` | `hippo groan` · `large animal dying` |
| `boar_idle` | `wild boar snort` · `pig snort` |
| `boar_aggro` | `boar squeal angry` · `pig squeal` |
| `boar_attack` | `boar charge grunt` · `heavy impact thud` |
| `boar_hurt` / `boar_death` | `pig squeal pain` · `boar dying` |
| `anaconda_idle` | `snake hiss` |
| `anaconda_attack` | `snake strike` · `snake hiss attack` |

---

## 3. Animations

Each creature needs four, and they are **cosmetic only** — movement stays `PivotTo`, so nothing here can
break the AI:

| Key | Crocodile | Panther |
|---|---|---|
| `idle` | floating still, occasional tail sway | standing, tail flick |
| `move` | **swim** | **prowl / run** |
| `attack` | lunge + jaw snap | pounce / claw swipe |
| `death` | roll over, sink | collapse |

**Source:** Meshy's auto-rig already returns **walk + run** (5 credits, included). `meshy_animate`
(3 credits each) covers the rest, or the Meshy animation library. Upload the resulting animations to
Roblox and paste the ids into `EnemyAssets.ART[x].anim`.

---

## 4. Where each thing goes

| Asset | Destination |
|---|---|
| Creature models | `ServerStorage.AssetLibrary` (any group — resolution is **by name**, so the model must be named exactly `Crocodile`, `Panther`, …) |
| Sound ids | `EnemyAssets.ART[creature].sound[key].id` |
| Animation ids | `EnemyAssets.ART[creature].anim[key]` |
| Every id, also | the shared registry `roblox.workspace/Assets/registry/{models,audio,animations}.md` |
| Status tracking | `ASSETS.md` §4 |

> ⚠️ Models placed in `ServerStorage` live **only in the `.rbxl`** — it is not a Rojo-synced path, so the
> place must be **saved** or they vanish. Same trap as the Bahay Kubo huts in Job #077.
