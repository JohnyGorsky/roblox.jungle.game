# Asset gaps — everything Last River still needs (snapshot 2026-08-15)

Read from `ASSETS.md`, the shared registry, and the live code — **not** from memory. `ASSETS.md` stays
the bible; this is a dated summary of what is still OPEN, ordered by what a player notices first.

> ✅ **Recently closed:** all 6 creatures (Job #078), all 4 held weapons + the whole weapon audio set
> (Job #079), dock camps / docks / trading posts (Job #077), camp night practicals + the river log jam
> (Job #079, 2026-08-16). None of those appear below.

---

## 1. 🔴 HUD icons — 23 wired, **16 still need real art**

`Theme.icon` has 39 keys; **23 carry real ids** (the lobby / shop / boat set) and **16 are empty** — all
of them Job #075's *in-run HUD* set, which is why the boot warning only names those:

`salvage` · `metal` · `ammoBox` · `heart` · `machete`→**axe** · `pistol` · `bandage` · `flag` ·
`warning` · `sun` · `moon` · `skull` · `shotgun` · `rope` · `pin` · `clipboard`

### ⚠️ They are NOT blank on screen — and that is the point

`Theme.iconFallback` already maps every one of them to a semantically-close wired icon, and
`Components.iconId` substitutes automatically whenever the real id is empty. The HUD has been drawing
`tools` for the axe, `gun` for the pistol, `medkit` for the bandage, `crew` for the skull, and so on,
the whole time.

The file states the intent plainly, and it is worth respecting:

> *"semantically close enough to read correctly in a screenshot, never so close that we forget to
> replace it. `Components.icon` consults this only when the real id is empty."*

So **the empty ids are the tracking mechanism**, not an oversight. Filling them with existing art (tried
2026-08-15, reverted the same day) removes the boot warning, makes a deliberately-imperfect stand-in
permanent, and duplicates a system that already exists.

**"The axe icon looks wrong" is this working as designed** — the axe slot shows the `tools` wrench,
because no axe glyph exists in the set yet. Nothing among the 23 wired icons is a blade or an axe, so
that one cannot be fixed by reuse; it needs real art.

**Source:** Flaticon. ⚠️ **Same author as the §1.9 lobby set** — ASSETS.md's rule: *"One pack, one
author — mixed packs are the #1 way an icon set looks wrong."*

> ⚠️ Rename `machete` → `axe` when the art lands: Job #079 made the starting melee an axe.
> `Theme.itemIcon.Axe` currently points at the `machete` key in both trees.

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

**Gun** (`assets/Objects/Gun/`) — <span style="color:#2e9c3f">✅ nothing left here</span>
`gun_reload` · `gun_empty_clip` · `gun_shot_1_sec`
→ All three are now **uploaded and wired** (Job #079): `gun_shot` `138178318678571`, `empty_gun`
`75733077651437`, `gun_empty_clip` `135106168511714`, `gun_reload` `134765294816468` (the turret is the
only weapon with a reload moment). These local files are alternates — leave them.

## 4. 🟡 Boat upgrade models — 6 to generate

Every purchasable boat module is still greybox (`ASSETS.md` §2):

`motor2` (twin motors) · `hullkit` (reinforced hull) · `searchlight` rig · `fueltank` (extended) ·
`trailer` (**cargo ON the rear deck — NOT a towed barge**) · `gunupgrade` (turret)

**Source:** Meshy. These are bought with real money, so they are the assets most worth spending on.

> ⚠️ **"Gold-chest buy-popup art" was on this list and is now closed** — not by generating it, but
> because it never existed as a gap: `Theme.productIcon` already carries real transparent PNGs for all
> four gold packs and every pass, and the shop draws flat images, not 3D. The `GoldChest` model
> generated for it became trading-post dressing in #079 instead.
>
> ⚠️ Boat upgrade **purchasing already works** — it was built in the lobby. `BoatParts` holds 18 real
> MeshParts, named by art rather than by module id, which is why an earlier sweep wrongly reported it
> missing. Only the 6 models above are greybox.

## 5. 🟡 World set-pieces

| Item | Note |
|---|---|
| Waterfalls, ramps | ⚠️ **neither is Meshy work** — waterfalls are terrain + VFX, ramps need a design decision first |
| ~~Dam blockages~~ | <span style="color:#2e9c3f">✅ closed (#079)</span> — `LogJam` is live as the 4th river obstacle |
| Zone dressing / day-night set-pieces | per-zone props + lighting; 4 zones exist in code. **Needs a spec before generating anything** |
| Lobby lanterns | §1 says the signpost is built but *"Lanterns still ▫ (need props)"*. ⚠️ **The `Lantern` model wired in #079 is in the GAME place** — the lobby is a separate place file and needs its own import |
| Plane-crash intro visuals | the cold open is scripted but has no bespoke art (2D) |

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

1. **HUD icons + HUD sounds** (§1, §2) — 16 icons + 5 sounds. Not urgent-broken (the icons fall back to
   close-enough art automatically), but it is the most-seen rough edge in the game.
2. **Upload the audio already on disk** (§3) — nearly free, and `gun_reload` closes the last weapon gap.
3. **Boat upgrade models** (§4) — they are paid content and currently look like boxes.
4. **World set-pieces** (§5) — biggest visual payoff per unit of work after the above.
5. **Anaconda** (§6) — only once its gameplay is decided.
