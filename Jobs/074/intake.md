# Job #074: Playtest fixes — MEDIC label, real Robux shop in the game place, armour plating

**Project**: `roblox.jungle`
**Created**: 2026-08-02
**Status**: Requirements Gathering — **plan below, decisions taken, awaiting go**

## What you asked for

> *"Create one task for game from 0042 - 0045 todos. Read game logic, read what we did in previous job
> and create task where we address these issues."*

The four items are the leftovers of the **Job #073 playtest** — the three that were filed rather than
fixed, plus one that was fixed. So this job is the playtest cleanup pass.

| TODO | | Here? |
|---|---|---|
| [0042](../../todo/0042-remove-the-medic-billboard-label-from-th.md) | Remove the MEDIC billboard label | ✅ |
| [0043](../../todo/0043-replace-the-greybox-robux-shop-in-the-ga.md) | Real Robux shop in the GAME place | ✅ — **the bulk of this job** |
| [0044](../../todo/0044-night-starts-audio-asset-is-not-approved.md) | `night_starts` blocked | **already resolved in #073** — re-verify only |
| [0045](../../todo/0045-investigate-the-dark-slab-sticking-out-u.md) | Dark slab under the boat hull | ✅ — **root cause found, see 1.3** |

---

# Part 1 — What is actually there now (read from the code, 2026-08-02)

## 1.1 TODO 0042 — the MEDIC label is 14 lines and nothing depends on it

[`CargoServer.server.luau:164-177`](../../sync/ServerScriptService/Cargo/CargoServer.server.luau#L164-L177)
builds a `BillboardGui` + `TextLabel` on the `Medic Station` part. Job #070 already gave that part its
real `medicStation` skin, so the station reads as a station without the tag.

**The todo asks whether removing it lets `IntroHudGate` be simplified. It does not.** Read
[`IntroHudGate.local.luau:49-80`](../../sync/StarterPlayer/StarterPlayerScripts/UI/IntroHudGate.local.luau#L49-L80):
the sweep is **generic** — it disables *every* enabled `BillboardGui` in `Workspace` and restores the
ones it touched. It never names MEDIC. The header comment names it as an *example*, and the ROBUX SHOP
tag is the other one. So: **delete the label, fix the stale comment, change no logic.**

## 1.2 TODO 0043 — the game place has no design system at all

The todo says *"use the lobby's `RobuxShop.local.luau`"*. That file cannot be copied as-is, because it is
built entirely on modules the game tree **does not have**:

| | LOBBY | GAME |
|---|---|---|
| `ReplicatedStorage/UI/Theme.luau` | 224 lines | ❌ absent |
| `ReplicatedStorage/UI/Components.luau` | 1011 lines | ❌ absent |
| `ReplicatedStorage/UI/UISound.luau` | 112 lines | ❌ absent |
| `ReplicatedStorage/UI/UIBus.luau` | 33 lines | ❌ absent |
| HUD scripts | on the design system | **all 16 hand-rolled greybox**, ~2000 lines |

`Theme.luau`'s own header already anticipated this:

> *"Lobby tree only for now; **the byte-identical `sync/` copy is added when the game place is
> restyled**."*

The two `RobuxShop` copies also differ in **behaviour**, not just looks — the game's is the Job #046
original and never got Job #065/#067/#069:

| | GAME (183 lines) | LOBBY (198 lines) |
|---|---|---|
| Row art | ❌ text only | ✅ `Theme.productIcon` — the transparent in-game icons, ASSETS.md §5.1 |
| Fallback icon for art-less products | ❌ | ✅ `Theme.productFallbackIcon` (Job #067) |
| Pass **OWNED** state | ❌ — an owner of the 499 R$ pass still sees a live buy button | ✅ `Owns_<key>`, Job #069 |
| Live Hub price | ❌ prints the hardcoded def | ✅ non-blocking `GetProductInfo`, Job #069 |
| Open routes | kiosk only (`OpenRobuxShop`) | kiosk (`OpenPanel`) **+** `UIBus` |

⚠️ The **OWNED gap is money-facing**: all three passes have **managed pricing** on the Hub, so the game
place can print a price Roblox is not charging, and can sell a pass to someone who already owns it.

### The kiosk model — ✅ you placed it mid-intake

[`StartShopServer.server.luau`](../../sync/ServerScriptService/Economy/StartShopServer.server.luau) spawns
a **green 4 × 5 × 2 `SmoothPlastic` box** with a `ROBUX SHOP` billboard, positioned by raycast from
`HubSpawn` on the opposite side from the plane wreck (Job #072's fix).

While this intake was being written you dropped the **real hut** into the camp. Read live:

```
Workspace.SpawnBase.Stands.RobuxShop        Model   attr Station = "RobuxShop"
├── RobuxhShop (sic)  MeshPart  PrimaryPart   MeshId 81119390187013  + SurfaceAppearance
│                                             15.09 x 18.77 x 19.97   at (-258.0, 28.0, -349.5)
├── Anchor            Part      invisible, CanCollide false, + BillboardGui
└── EntrySign         Model     the "ROBUX SHOP" board on posts
```

That is the **lobby station copied whole** — same mesh id as `meshes.md:97`, same `Station` attribute,
same `Anchor`-hosts-the-prompt convention `LobbyStations` uses. So the placement half of 0043 is done and
the script just has to stop building geometry and start finding this.

⚠️ **One defect the placement surfaced, not in any todo: `CollisionFidelity` is `Box`.** On a
15 × 18.8 × 20 mesh that is an invisible 20-stud cube sitting in the middle of the camp — the open front
and the counter are sealed, and you cannot walk up to the shop you are meant to walk up to. This is the
`meshy-collision-fidelity` trap, and it is **authoring-time**: a runtime script cannot write the property
(Roblox gates it behind plugin capability — the same gate `BoatParts.skin` documents at line 432). It has
to be set in Edit and **saved with the place**. Folded into step 4.

## 1.3 TODO 0045 — found it. Job #066 already fixed this exact bug, on the other set of plates

The todo's hypothesis (`ArmoredHullL/R`) is **correct**, and the reason is sharper than "it's a bare
part": the boat has **two** sets of flank plating, and only one of them got Job #066's treatment.

```
sync/ServerScriptService/Boat/BoatModules.server.luau

L180  hullkit upgrade  — FIXED in Job 066
      4 x tiled hullPlate segments, 0.5 x 2 x 4.6, x ±7.1, Y 2.2, skinId "hullPlate"
      -> real mesh at modelled proportions, on the flank, paintable = true

L349  Armored Boat pass — NEVER TOUCHED, still the Job 027 original
      ArmoredHullL/R    0.8 x 2.4 x 22, x ±7.4, Y 0.3,  no skinId
      ArmoredProw       14 x 2 x 3,             z -11,  no skinId
```

`BoatParts.Defs.hullPlate` even carries the lesson in a comment — *"TILED, NOT STRETCHED … a straight
strip at constant beam doesn't fit a hull that TAPERS, so the ends jutted out into open air like oars"*
— which is a description of the armour plates as they stand today.

Three separate faults, each independently visible:

1. **It pokes through the hull.** Half-width 7, plate at x ±7.4 → 0.4 studs of clearance against a
   *modelled, curved* 14-wide hull mesh. The hullkit plates sit at ±7.1 and read fine, because they are
   thinner (0.5 vs 0.8) and skinned.
2. **It is at the wrong height.** `Y 0.3` is box-centre — near the waterline. Job #066 raised the
   hullkit plates to `Y 2.2` for exactly this reason: *"the hull BOX is only 3 tall but the visible hull
   mesh rises to ~4.5, so plates at box-centre hung off the keel below the waterline."* The armour was
   left at box-centre.
3. **It never gets painted.** `BoatPaint.apply(..., BoatParts.paintableSkinNames())` repaints
   `Skin_<id>` children of paintable defs. The armour has no `skinId` at all, so it has no `Skin_*`
   child and the Paint Pack cannot see it — it stays `(70,72,80)` grey while the hull goes navy. That is
   the "raw greybox against the finished navy mesh" you saw, and it is *guaranteed* by construction, not
   bad luck.

`ArmoredProw` (14 × 2 × 3 at z −11) is also suspect and gets re-measured in the same pass: the hull grew
22 → 32 long in Job #066, so z −11 is no longer at the bow, and the `RampBow` kit is 8 × 8 sitting on the
same foredeck.

## 1.4 TODO 0044 — resolved, verify only

`night_starts_2` = `75443344927115`, wired in `GameSoundscape`'s `SFX` table and in the shared registry,
verified firing on a real dusk flip in #073. Nothing to build. This job just re-confirms it in Play so a
closed todo isn't taken on trust, and does **not** resurrect the three dead ids.

---

# Part 2 — Decisions (2026-08-02, all four confirmed by you)

| # | Decision |
|---|---|
| 1 | **Port the design system, then the shop.** Copy `Theme` + `Components` + `UISound` + `UIBus` into `sync/ReplicatedStorage/UI/` as a byte-identical second copy (the same deal `MonetizationDefs` already has), then bring the lobby's `RobuxShop.local.luau` over essentially verbatim. This is the port `Theme`'s header was written for, and it means the rest of the greybox game HUD can be restyled later without a second port. |
| 2 | **Editor-place the kiosk in `SpawnBase`.** ✅ **You did this mid-intake** — `SpawnBase.Stands.RobuxShop`, the lobby station copied whole. `StartShopServer` stops building geometry and instead **finds it by its `Station` attribute** and attaches the prompt, exactly as `LobbyStations` does. Placement is now a build decision you can move in the editor, not a raycast guess. |
| 3 | **Reuse the Job #066 hullkit recipe for the armour.** Tiled `hullPlate`-skinned segments on the flank at the proven geometry, so the armour is a real mesh, sits above the waterline, follows the midbody, and repaints with the hull. No new art. |
| 4 | **Armour supersedes the hullkit plates.** When the pass is active, build ONE set of plates in the armoured look and skip the hullkit's. No z-fighting by construction, and the 499 R$ pass visibly outranks the 
upgrade. |

---

# Part 3 — Things to flag before building

## 🔴 A second copy of the design system is real, permanent duplication

Decision 1 creates ~1380 lines that must stay in step with the lobby's. That is a **known, accepted
pattern here** — `MonetizationDefs`, `BoatParts` and `BoatPaint` are all already duplicated across the
two trees — but it is duplication, and the failure mode is silent drift (a colour fixed in the lobby, not
in the game).

Mitigations, both cheap:

- The copies go over **verbatim**, with a header line naming the lobby file as the source of truth, so a
  diff is the whole check.
- The job ends with a `diff` of all four files across the trees, recorded in the final summary.

**I am not building a shared package for this.** The two places are separate Rojo trees with separate
`default.project.json`s; a shared layer is its own job and is out of scope here.

## 🟠 `UISound` writes into `SoundService`, which is no longer empty

At the time the lobby module was written, the game place's `SoundService` had **zero children**. Job #073
put `GameSoundscape`'s buses and folder there. `UISound` creates its own 2D `Sound`s — it must not adopt,
rename, or route through `GameMusic`/`GameAmbient`/`GameSFX`, and the drift check `GameSoundscape` does
must not start warning about UI sounds. Verified as part of step 2, not assumed.

## 🟠 The kiosk move retires Job #072's wreck-avoidance logic

`StartShopServer` currently *derives* its position so the kiosk can't land inside the 88 × 94 plane
wreck. The editor placement **retires that logic** — which is correct (a hand-placed object can't collide
with a hand-placed wreck), but it means the raycast/`GetBoundingBox` block gets deleted rather than left
dead. The script keeps a loud `warn` when no `Station="RobuxShop"` model is found, so a missing or
renamed placement fails visibly instead of silently shipping a shop nobody can open.

Two smaller consequences:

- **The greybox block must actually stop being created.** Left in, the place would have two shops.
- **`Station` becomes a live convention in the game tree.** Nothing there reads it today; after this,
  one script does. Worth matching the lobby's spelling exactly so the two stay greppable together.

## 🟠 The armour change is worth one balance sentence

Decision 4 means a crew owning **both** the hullkit upgrade and the Armored pass sees one set of plates
instead of two. **No stat changes** — `MaxHP 150` from the hullkit and the pass's ×1.2 both still apply
exactly as now; only the geometry is deduplicated.

## 🟢 `MonetizationDefs` is not touched

It is meant to be byte-identical in both trees and already is. The new shop reads it; nothing writes it.
Verified by diff at the end.

---

# Part 4 — The plan

## Step 1 — TODO 0042: remove the MEDIC label *(small, do it first)*

Delete the `BillboardGui` + `TextLabel` block in `CargoServer`. Keep the part, the skin, the weld, and
the Medic ROLE. Fix `IntroHudGate`'s header comment so it stops citing a billboard that no longer exists
— **without touching its logic**, which stays generic and is still needed.

## Step 2 — TODO 0043a: port the design system

Copy `Theme.luau`, `Components.luau`, `UISound.luau`, `UIBus.luau` into
`sync/ReplicatedStorage/UI/`, verbatim apart from a source-of-truth header line. Confirm
`default.project.json` maps the new folder. Run `tools/luau-analyze.sh` over the game tree. Then verify in
Play that `SoundService` still reads exactly as #073 left it plus UI sounds, with no drift warning.

## Step 3 — TODO 0043b: the shop panel

Replace `sync/.../UI/RobuxShop.local.luau` with the lobby's, adjusted **only** where the two places
genuinely differ:

- the kiosk fires `OpenRobuxShop` here, `OpenPanel` there — keep this place's remote;
- the game place has no top bar and no entry bar, so the `UIBus` route has nothing to open it. Keep the
  `UIBus.onOpen` hook anyway (it costs one connection and is what a future game-place top bar will use).

Everything else comes over as-is: real store art per row, the `Owns_<key>` OWNED state with its
default-to-not-owned rule, and the non-blocking live-price fetch routed through the same single `refresh`.

## Step 4 — TODO 0043c: wire the kiosk *(placement already done)*

The hut is placed. What's left:

1. **Rewrite `StartShopServer`** to find the `Station="RobuxShop"` model, host the prompt on its `Anchor`
   (falling back to `PrimaryPart`), and size the activation radius from the model's bounding box — the
   same `findStation`/`promptHost`/`reach` shape `LobbyStations` uses, so the two read alike. Delete the
   part-building, the billboard-building and the whole raycast/`HubSpawn` positioning block. Keep
   `OpenRobuxShop` and its `FireClient`.
2. **Fix `CollisionFidelity`** on `RobuxhShop` — `Box` → `PreciseConvexDecomposition`, set in **Edit**
   and saved with the place (a runtime script cannot write it). Then walk up to the counter in Play to
   prove the front is actually open.
3. **Check the hut against the camp** — 15 × 18.8 × 20 is a real building. Confirm it isn't inside the
   `FoliageServer` spawn-base exclusion's blind spot, doesn't overlap the wreck or the dock walk-line,
   and that `EntrySign` faces the spawn.

## Step 5 — TODO 0045: the armour plating

Rework the `armored` block in `BoatModules`:

- `ArmoredHullL/R` → tiled `hullPlate`-skinned segments at the Job #066 geometry, sized so armour reads
  heavier than the upgrade plating;
- skip the hullkit's plates when the pass is active (decision 4), sharing one constant table between the
  two branches rather than copying the numbers;
- re-measure `ArmoredProw` against the 32-long hull and the `RampBow`, and either place it correctly or
  fold it into the plate run.

**Confirm visually before and after**, as the todo demands — Play with the pass, screenshot the hull from
outboard, then again after the change, with the Paint Pack on so the "does it repaint?" half is proven
rather than argued.

## Step 6 — TODO 0044: re-verify

One Play run to a dusk flip: `night_starts_2` `75443344927115` loads and plays. No code change expected.

## Step 7 — Docs

- **ASSETS.md §5.1** — the *"the game-place copy is still text-only (out of scope)"* line becomes wired;
  §1 gets a game-place kiosk row.
- **Shared registry `meshes.md:97`** — the `RobuxhShop` row currently names only the lobby location; it
  gains the game-place one, so the mesh isn't re-sourced for a place it already lives in.
- **ASSETS.md / STYLEGUIDE.md** — record that the design system now exists in both trees.
- Resolve todos **0042 / 0043 / 0045** via `job.py resolve`.
- Final summary + changelog.

## Checklist

- [ ] Step 1 — MEDIC label removed, `IntroHudGate` comment corrected, logic untouched
- [ ] Step 2 — design system ported to `sync/ReplicatedStorage/UI/`, analyzer clean, `SoundService` verified
- [ ] Step 3 — game `RobuxShop` = the lobby's (art + OWNED + live price), kiosk remote kept
- [x] Step 4 — kiosk hut editor-placed in `SpawnBase.Stands.RobuxShop` *(done by you, 2026-08-02)*
- [ ] Step 4 — `StartShopServer` finds the station + hosts the prompt on `Anchor`; greybox block gone
- [ ] Step 4 — `CollisionFidelity` `Box` → `PreciseConvexDecomposition`, set in Edit, **place saved**, walk-up proven in Play
- [ ] Step 5 — armour re-plated on the #066 recipe, supersedes hullkit, repaints with the hull
- [ ] Step 5 — **visual confirm in Play, before and after, with the Paint Pack on**
- [ ] Step 6 — `night_starts_2` re-verified on a real dusk flip
- [ ] Step 7 — ASSETS.md §5.1 + kiosk row, STYLEGUIDE note, todos resolved, summary + changelog
- [ ] `diff` of all four UI modules + `MonetizationDefs` across the two trees, recorded
