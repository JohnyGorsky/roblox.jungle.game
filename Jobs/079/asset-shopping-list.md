# Job #079 — assets: what's done, what I need from you

Ids go into the code once you send them. Nothing here blocks anything else — the held-item system
degrades: no model → the existing greybox part, no sound → silence.

---

# ✅ DONE — models, no action needed from you except the import

| Item | Source | State |
|---|---|---|
| **Axe** | roblox.defender, **rebuilt from ids** | ✅ already in `ServerStorage.AssetLibrary.Weapons.Axe` |
| **Pistol** | Meshy (30 cr) | `assets/GameObjects/Weapons/Pistol.glb` — **needs importing** |
| **Shotgun** | Meshy (30 cr) | `assets/GameObjects/Weapons/Shotgun.glb` — **needs importing** |
| **Torch** | to be BUILT in code | no asset needed — see below |

### The Axe needed no copy-paste between places
Defender's `Handle` turned out to be a plain `Part` + `SpecialMesh`, so it was rebuilt in Jungle
from ids alone:
- mesh `145815658` · texture `186913315` · decal `4657174543`
- size `0.40 × 3.00 × 0.80`, SpecialMesh scale `(1, 0.75, 1)`
- Defender's `Tool.Grip` was `(0, -1.089, 0.026)` — stored as a `GripOffset` attribute on the part so
  the hand weld can match how it sat in Defender.
- ⚠️ Defender's `ToolScript` was **not** brought across.

### Import steps for the two guns
1. Studio → **Import 3D** → pick the `.glb`
2. Name it **exactly** `Pistol` / `Shotgun`
3. Put it under `ServerStorage.AssetLibrary.Weapons`
4. **Save the place** — `ServerStorage` is not Rojo-synced

Then I'll do the measured pass: size against the greybox it replaces, which way it points, and the grip
offset so it sits in the hand instead of through it.

### The Torch is built, not sourced
It is a stick plus a flame, and `Campfire.luau` (Job #077) is already that recipe — `Fire` + ember
`ParticleEmitter` + `PointLight`. The torch branch of `updateHeldVisual` **already** creates the
`PointLight` and tags it `NightLight` so `LightController` switches it at dusk, so building it reuses
wiring that is already correct. Zero credits, on-palette, nothing to import.

---

# 🔊 SOUNDS — what I need from you

## Already have it, nothing to do

| Sound | id | Note |
|---|---|---|
| `AxeSwing` | `210946558` | from Defender |
| `AxeChop` (hit) | `8936215056` | from Defender |
| `Equip` | `2304904662` | from Defender — ⚠️ it is authored at **volume 10.0**; I will wire it far lower |
| `gun_shot` | `138178318678571` | **already uploaded and owned by you, never wired.** Deferred in Job #073 with your note *"this will be a separate task"* — this is that task |
| Torch crackle | `113774133604878` | reuse `crackle-campfire`, already owned and already used by the camps |

## ☐ Need you to upload — 1 file you already have

| ☐ | Local file | Upload as | What it is |
|---|---|---|---|
| ☐ | `assets/GameObjects/Sounds/empty_gun.mp3` | `gun_empty` | dry-fire click when you pull the trigger with no ammo |

## ☐ Need you to find on Pixabay — 3 clips

Short **mono**, under ~2 s.

| ☐ | Asset name | What it is | Pixabay prompt |
|---|---|---|---|
| ☐ | `shotgun_shot` | the shotgun's own boom | `shotgun blast` · `shotgun fire` — **optional but worth it**: it can share `gun_shot`, but a pistol crack on a 6-pellet shotgun undersells it |
| ☐ | `gun_reload` | pump/rack between shots | `shotgun pump` · `gun cocking` |
| ☐ | `axe_equip` | *(optional)* replaces Defender's `Equip` | `equip weapon` · `gear rustle` — only if Defender's sounds wrong for a jungle axe |

> ⚠️ **Only `gun_empty` is genuinely missing.** Everything else either exists or has a working fallback,
> so the job can ship without the three Pixabay clips — they are polish, not blockers.

---

# ⚠️ One thing to get right when wiring `gun_shot`

Fire intervals are **0.22 s (pistol)** and **0.7 s (shotgun)**. A `Sound` created per bullet stacks
into a wall of noise at sustained fire — the exact trap `GameSoundscape`'s header documents about the
cicadas, where a 71-second clip fired every 18 s layered six copies. The shot cue wants to be **one
positional Sound on the barrel, restarted**, not a new instance per shot.

---

## Credits

60 spent (1,600 → **1,540**). The axe cost nothing — it was reuse.
