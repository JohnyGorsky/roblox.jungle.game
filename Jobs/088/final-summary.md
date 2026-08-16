# Final Summary — Job #088

**Project**: `roblox.jungle`
**Completed**: 2026-08-16
**Status**: ✅ Code complete, analyzer clean, seating verified by measurement — ⏳ awaiting playtest

Three items from the 2026-08-16 playtest, chosen by the user. A fourth (glowing eye placement) is
the user's own Studio task; the attachments it needs were created for them (see below).

---

## Item 1 — Land creatures now come after you ashore

Land creatures targeted **the boat and nothing else**. The reasoning at `EnemyServer:261-262` was that
a bank-leashed creature "cannot cross open water to reach a swimmer anyway" — true of a *swimmer*, and
quietly wrong about someone standing on the bank right beside it. Sea creatures gained swimmer-hunting
in Job #084; land creatures never got the equivalent.

The result, reported in play as *"why do boars just follow on shore?"*: **stepping ashore made you
safer than staying aboard.** A boar wanted only the hull, and after Job #086 stopped it wading out, all
it could do was pace the shoreline alongside you.

Added `refreshAshore()` / `nearestAshore()` — the land twin of the existing swimmer pair, rebuilt once
per Heartbeat before the enemy loop for the same reason (up to 7 land creatures asking one question).
"Ashore" is simply *not swimming*, which also covers a player on the deck — harmless, since a creature
takes whichever target is nearer and a player on deck is at the boat's position anyway.

The two targeting branches collapsed into one, because they now differ only in **which people each
category can reach**:

```luau
local person = if def.category == "sea" then nearestSwimmer(pos) else nearestAshore(pos)
if person and flatDist(person.Position, pos) < flatDist(boatPos, pos) then ... end
```

⚠️ `huntingSwimmer` was renamed `huntingPerson` and still feeds `applyBite(def, pos, not huntingPerson)`.
That flag matters: a creature that closed on a person must not fall through to damaging the hull when
its victim slips out of reach — a boar biting you on the bank is not also chewing a boat 80 studs away.

## Item 2 — Land creature visuals stand on the ground instead of sinking into it

`EnemyRig` pivots the visual to the hitbox **centre**, which is only correct when the rig's own pivot
happens to sit at its vertical middle. The Wolf's does not — measured in Studio at 1.71 × 4.23 × 6.22
authored, with its pivot 0.53 (0.69 scaled) above the bounding-box centre.

**This was never a Job #086 regression.** The creatures were always mis-seated; over water it read as
"swimming", which is why the very first report of it looked like a swimming wolf. Putting wolves on
land at camps turned the same bug into a wolf buried to the shoulders.

The fix measures the clone's bottom and lifts it to meet the hitbox bottom. Verified by reproducing
the old and new placement against the real models:

| | Scaled size | Hitbox height | Feet vs ground — before | after |
| --- | --- | --- | --- | --- |
| Wolf | 2.22 × 5.49 × 8.08 | 4.0 | **−1.44** | 0.00 |
| Boar | 6.00 × 7.29 × 9.00 | 3.0 | **−2.34** | 0.00 |

The Boar was buried *worse* than the Wolf, and since Job #086 made Boar the only riverbank ambusher,
this fixes the bank as well as the camps.

⚠️ **Land only.** Sea creatures are deliberately half-submerged at the water line — seating a crocodile
on its "feet" would lift it clean out of the river.

Measured from the model rather than hand-tuned per creature, so a re-scaled or re-imported rig stays
seated without anyone remembering to update a magic number. An optional `art.yOffset` is honoured on
top for deliberate art nudges.

## Item 3 — Carried loot rides on the back

`makeCarried` pivoted the barrel to `root.CFrame * CFrame.new(0, 3, 0)` — three studs straight up,
putting a rusted barrel on top of the player's hat. Now `(0, 0.6, 1.3)` with a −12° tilt, so it sits
between the shoulder blades and reads as slung rather than balanced.

⚠️ **+Z is behind.** `HumanoidRootPart.CFrame.LookVector` is the way the character faces (−Z), so a
positive Z offset is the back. The greybox fallback crate was moved to match, and the `WeldConstraint`
is created *after* the pivot, so the new offset is what gets locked in.

---

## Not in scope — the glowing eyes (yours)

Eyes sit wrong on the land creatures because **no land model had `EyeLeft`/`EyeRight` Attachments**, so
`EnemyRig.addEyes` fell back to guessing offsets from `def.size` — which for the Wolf is still the
*Panther's* 5 × 4 × 11 hitbox, hence eyes floating well ahead of a rig only 8 studs long.

Worth noting: the sea creatures (`Aligator`, `Piranha`, `RiverHippo`) **already had** these
attachments, which is why only the land rigs looked wrong.

At the user's request the missing attachments were created in
`ServerStorage.AssetLibrary.Enemies`, parented to each model's `Head`, then **hand-adjusted by the
user** and read back to confirm:

| Model | Host | Created at | Final (user-set) | |
| --- | --- | --- | --- | --- |
| Wolf | `Head` | ±0.26, 0.16, −0.42 | **±0.26, 0.86, −2.75** | adjusted, symmetric |
| Boar | `Head` | ±1.56, 0.19, −1.26 | **±0.91, −1.95, −0.82** | adjusted, mirrored (see below) |
| WesternBandit | `Head` | ±0.30, 0.18, −0.49 | unchanged | opted out of eyes anyway |

The sea creatures were left untouched — they already had correct attachments:
`Aligator ±0.85, 3.74, −8.00` · `Piranha ±0.70, 0.85, −1.90` · `RiverHippo ±1.00, 1.44, −3.62`.

⚠️ The read-back caught the **Boar's pair being asymmetric** — `EyeRight` sat 0.24 studs lower and
0.14 further out than `EyeLeft`, which at a 0.5-stud eye is about half an eye of vertical drift and
would have read as a lopsided face once lit. On the user's decision `EyeRight` was mirrored from
`EyeLeft`: `(1.05, −2.19, −0.74)` → `(0.91, −1.95, −0.82)`.

**No code change was needed** — the rig already prefers attachments and re-glues the eyes to their
`WorldCFrame` every frame.

---

### ✅ Auto-synced files

- `sync/ServerScriptService/Enemies/EnemyServer.server.luau` (item 1)
- `sync/ServerScriptService/Enemies/EnemyRig.luau` (item 2)
- `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` (item 3)

Plus the Studio-side attachments above (place file, not disk — they save with the place).

### ⚠️ Manual Studio copy required

- _none_

## Verification

- [x] `bash tools/luau-analyze.sh` clean (exit 0). The first run **caught a real defect**: `visual` is
      typed `PVInstance` and `GetBoundingBox` is a Model method — the sea creatures are MeshParts, so
      the code now measures a Model and a BasePart separately.
- [x] Seating verified by reproducing old vs new placement against the real rigs in Studio (table above).
- [ ] **Playtest** — step ashore and boar/wolves come for you instead of pacing the bank.
- [ ] **Playtest** — a creature biting you ashore does **not** also damage the boat.
- [ ] **Playtest** — wolves and boar stand on the ground at camps and on the bank, on sloped terrain.
- [ ] **Playtest** — crocodiles are still half-submerged (the land-only guard held).
- [ ] **Playtest** — carried barrel sits on the back; deposit and drop still work.

## Notes / follow-ups

- Still open and untouched: `todo/0047` (turret + searchlight lag, deferred to Job #087) and
  `todo/0050` (boat ride quality, Job #087 — awaiting a moving measurement).
- Raised in conversation, not logged as work: players have no in-game way to learn that Metal comes
  only from the deep camp, and Salvage has no dedicated pickup object (it is a by-product of looting
  crates). ASSETS.md still lists the `Scrap / salvage pile` prop as required-but-missing.
- The Wolf's hitbox is still the Panther's 5 × 4 × 11 against a rig 2.22 × 5.49 × 8.08. That is
  deliberate and documented in `EnemyAssets` (Job #058 is tuned against it), but it means the eye
  fallback and the bite reach are both generous relative to the art.
- Not committed — the user commits (GROUND-RULES §1).
