# Asset gaps — everything Last River still needs (snapshot 2026-08-15)

Read from `ASSETS.md`, the shared registry, and the live code — **not** from memory. `ASSETS.md` stays
the bible; this is a dated summary of what is still OPEN, ordered by what a player notices first.

> ✅ **Recently closed:** all 6 creatures (Job #078), all 4 held weapons + the whole weapon audio set
> (Job #079), dock camps / docks / trading posts (Job #077). None of those appear below.

---

## 1. 🔴 HUD icons — 23 are wired, **16 are blank**, and ~6 of those can be reused

⚠️ **Correction to an earlier reading of this file.** The icon set is NOT unwired — `Theme.icon` has
**39 keys and 23 of them carry real ids** (the lobby / shop / boat set: `close`, `coin`, `shop`, `star`,
`wrench`, `party`, `calendar`, `check`, `bounty`, `engine`, `hull`, `fuel`, `crate`, `tools`, `boat`,
`crew`, `wheel`, `medkit`, `gun`, `spotlight`, `loot`, `trophy`, `robux`).

The **16 blanks are all from Job #075's in-run HUD set** — the icons the HUD needs *during a run*, which
is why the boot warning only ever names those.

### ~6 of the 16 do not need sourcing at all — an existing icon already fits

| Blank key | Reuse this wired icon | id |
|---|---|---|
| `pistol` | **`gun`** | `120983452101559` |
| `shotgun` | **`gun`** (same icon, both are firearms in the hotbar) | `120983452101559` |
| `bandage` | **`medkit`** | `87252065857781` |
| `salvage` | **`loot`** | `121749397596257` |
| `ammoBox` | **`crate`** | `123909056802404` |
| `metal` | **`crate`** or **`tools`** | `123909056802404` / `109933399936454` |

That is a one-line change each, no sourcing, no attribution, and it keeps the set consistent because
they are already the same author.

### 10 genuinely need new art

`heart` · `axe` *(currently keyed `machete`)* · `flag` · `warning` · `sun` · `moon` · `skull` · `rope` ·
`pin` · `clipboard`

**Source:** Flaticon. ⚠️ **Same author as the §1.9 lobby set** — ASSETS.md's own rule: *"One pack, one
author — mixed packs are the #1 way an icon set looks wrong."* Free Flaticon needs attribution, so
prefer CC0 or paid.

> ⚠️ `machete` is wrong twice over: it is blank AND the starting weapon became an **axe** in Job #079.
> The key wants renaming to `axe` at the same time. (`Theme.itemIcon` was already updated to `Axe` in
> both trees.)

## 2. 🔴 HUD sounds — 5 placeholders

`Theme.sound` keys with empty ids, warned about on every boot:

| Key | What it is |
|---|---|
| `lowFuel` | single soft warning beep — fuel < 20% |
| `lowHull` | metallic stress groan — hull < 30% |
| `downed` | low thud + breath — you go down |
| `revived` | rising recovery swell — picked back up |
| `runLost` | somber descending sting — crew wiped |

**Source:** Pixabay, then upload. These are the moments the run turns — currently silent.

## 3. 🟡 Audio sitting on disk, never uploaded

All local `.mp3`s with no registry entry. Uploading is the whole job for most of them.

**Boat** (`assets/Objects/Boat/Sounds/`)
`boat_destroyed` · `boat_on_fire` · `metal_hit_1_sec` · `boat_engine_loop_5_sek` ·
`diesel_motor_start` · `motor_loop`
→ ASSETS.md §2 already flags on-fire / destroyed / metal-hit as ❌ not uploaded. The three engine files
may be alternates for the engine loop that is already wired — check before uploading duplicates.

**Gun** (`assets/Objects/Gun/`)
`gun_reload` · `gun_empty_clip` · `gun_shot_1_sec`
→ ⚠️ `gun_shot` and `empty_gun` are **already uploaded and wired** (Job #079), so these three are
alternates *except* `gun_reload`, which has no equivalent yet.

## 4. 🟡 Boat upgrade models — 7 to generate

Every purchasable boat module is still greybox (`ASSETS.md` §2):

`motor2` (twin motors) · `hullkit` (reinforced hull) · `searchlight` rig · `fueltank` (extended) ·
`trailer` (**cargo ON the rear deck — NOT a towed barge**) · `gunupgrade` (turret) · gold-chest buy-popup art

**Source:** Meshy. These are bought with real money, so they are the assets most worth spending on.

## 5. 🟡 World set-pieces

| Item | Note |
|---|---|
| Waterfalls, ramps, dam blockages | ASSETS.md §3 "Set-pieces — ▫ stub". River variety beyond obstacles |
| Zone dressing / day-night set-pieces | per-zone props + lighting; 4 zones exist in code |
| Lobby lanterns | §1 says the signpost is built but *"Lanterns still ▫ (need props)"* |
| Plane-crash intro visuals | the cold open is scripted but has no bespoke art |

## 6. 🟢 Enemies — only the Anaconda

All six current creatures are done. The Anaconda exists **only as concept art**
(`assets/Enemies/Anaconda.png`).

⚠️ It is a **gameplay change, not an art swap** — it needs stats, a category (sea or land), spawn rules
and a balance pass before a model is worth generating.

## 7. Not assets, but tracked in ASSETS.md

- **Weekly leaderboard** is a `"coming soon"` placeholder. It needs a weekly `OrderedDataStore` +
  rollover — code, not art.
- **15 of 16 game HUD scripts are still hand-rolled**; only `RobuxShop` consumes the `Theme`/`Components`
  design system that was ported in #074.

---

## Suggested order

1. **HUD icons + HUD sounds** (§1, §2) — but the real number is **10 icons + 5 sounds**, not 21:
   six of the "missing" icons are satisfied by reusing one already wired.
2. **Upload the audio already on disk** (§3) — nearly free, and `gun_reload` closes the last weapon gap.
3. **Boat upgrade models** (§4) — they are paid content and currently look like boxes.
4. **World set-pieces** (§5) — biggest visual payoff per unit of work after the above.
5. **Anaconda** (§6) — only once its gameplay is decided.
