# Job #116 — Implementation plan

**Project**: `roblox.jungle` · GAME place only (`sync/`) · Status: **awaiting agreement**

## Shape

Exactly the shape Job #115 landed, because it worked and because the two systems have to meet:

| File | What it is |
|---|---|
| `sync/ServerScriptService/World/Bunkers.luau` | **NEW** — the whole feature. A module, so a spawner can `require` it without inheriting a boot scan |
| `sync/ServerScriptService/World/BunkerServer.server.luau` | **NEW** — the boot. Scan Workspace, then listen on the tag |
| `sync/StarterPlayer/StarterPlayerScripts/UI/BunkerLamp.local.luau` | **NEW** — the lamp's *pulse*, client-side (see §3) |
| `sync/ServerScriptService/World/Generators.luau` | untouched |
| `ASSETS.md`, `roblox.workspace/Assets/registry/audio.md` | record the `alarm` upload + the bunker rows |

Nothing else is edited. No combat-path change, no new remote (the loot rides `RewardFeed` /
`CrewToast`, which both already exist).

## 1. Finding a bunker, and finding its keys

**The signature is not the name.** Three nested instances are called `Bunker` (Folder → Model → MeshPart).
So `attachAll` takes *a `Model` that has a `BunkerDoors` child*. That is also true of the library template,
hence the same warning Job #115 carries: **scan `Workspace`, never `ServerStorage`**.

**Keys = siblings.** `requiredGenerators(bunkerModel)` returns every `Model` under
`bunkerModel.Parent` whose name starts with `Generator`. For the end zone that is exactly
`Generator1/2/3`; for a spawner it means "drop the bunker and its generators in one folder".

- A bunker that finds **zero** generators **stays locked** and warns loudly. A bunker with no keys is a
  content error, and silently opening it would hand the crew the loot for free — the empty slot must
  announce itself rather than fail open.
- `Bunkers.spawn(cframe, parent, generators?)` lets a caller pass an explicit list instead.

**Watching them.** Two paths, both order-independent, so it does not matter whether `GeneratorServer` or
`BunkerServer` boots first:
- `Generators.onDisabled(fn)` — the hook #115 exposed for exactly this;
- plus a re-read of each key's `Disabled` attribute at attach, in case one died before we attached.

## 2. The doors

- At attach: `closedPivot = doors:GetPivot()` — and **no PrimaryPart is ever set on that model**, or the
  pivot moves under us.
- `travel = doorsBoundingBox.Y + 0.5`, **derived, not typed**. Measured here that is 13.86, which puts the
  door's top at y 21.7 — under the interior floor (22.10) and inside the shell base, which itself sits in
  terrain at 18.00. The half-scale library copy gets half the travel for free.
- **Ensure closed** means: on attach *and* on every run reset, `PivotTo(closedPivot)` and restore each
  door part's original `CanCollide`. Not "assume the editor left them shut".
- **The tween**: a `CFrameValue` proxy tweened `closedPivot → openPivot` over **10 s**,
  `Sine / InOut`, with `proxy.Changed → doors:PivotTo(cf)`. A proxy rather than a per-part tween so a
  future two-leaf door model works unchanged.
- On completion the door parts go `CanCollide = false` — they are buried, but nothing should be able to
  bump an invisible slab underground.

## 3. The lamp at `LightLocation`

Built on the server (so it exists for everyone), **pulsed on the client** — the precedent is
`LootGlow.local.luau`, and the reason is that a server-side tween replicates two changing properties every
frame, forever, per bunker. An attribute flip replicates once.

- Server builds, parented to the marker: a small dark **housing** part sized off the marker, and a
  **`Neon` bulb** ball ~0.8 × the marker's height, plus one **`PointLight`** (range ≈ 9 × the marker's
  height, `Shadows` off).
- The bulb is tagged **`BunkerLamp`**; the bunker Model carries **`DoorsOpen` (bool)**.
- Client tweens `bulb.Color` / `bulb.Transparency` / `light.Brightness` on a `RepeatCount = -1,
  Reverses = true` loop — **0.7 s red** while locked (urgent), **1.7 s green** once open (calm).
- ⚠️ **Not** tagged `NightLight`. This is a status readout, so it must read at noon too; `LightController`
  would switch it off at dawn.
- Colours are signal colours, not the UI palette: `Theme.color.red` (#A84B3C) and `green` (#4B7A2B) are
  muted panel accents that read as dull brown/olive on a Neon bulb. The lamp uses saturated
  `(235, 45, 35)` / `(60, 220, 85)`, hue-anchored to those two. Recorded here because it is a knowing
  departure from `STYLEGUIDE §4`.

## 4. The alarm

- `rbxassetid://103190295733089`, **8.05 s measured**, one-shot, at the moment the slide *starts*.
- Positional on the doors part, `InverseTapered`, `RollOffMaxDistance = 300` — the furthest generator is
  155 studs from the doors, so the whole crew hears it wherever they killed the last one.
- **Not looped.** It covers 8 of the 10 seconds of travel and leaves the doors settling in silence.

## 5. The loot at `ChestLocation`

Spawned **when the slide begins**, so it is revealed by the doors dropping rather than popping in after.

- **The chest**: `Props.GoldChest` at scale **0.65** (Job #079's measured number → 6.14 × 4.78 × 7.41),
  seated by raycasting down onto the interior floor and facing the doors. Dressing only — no prompt.
- **The piles**: one `Props.GoldNugget` (a bare MeshPart) per crew member, scaled **2.2** → 4.4 × 2.8 × 3.1
  so it reads as a bar rather than a pebble. `CanCollide` off (a pebble underfoot is a trip hazard — the
  same call `ExcursionServer` made). Tagged `Lootable` so `LootGlow` finds them in a dark bunker.
- **Layout**: up to 6 slots, 2 rows of 3, laid out *forward* (toward the doors) from the chest — that is
  the only clear direction (40+ studs, against 6.86 to the right wall). **Every slot is validated** with a
  downward cast onto the shell before it is used, and nudged toward the doors if it lands in geometry.
  Footprint, not a single point.
- **Ownership**: one pile per player **in the server** at open time, keyed by `UserId`. A `BillboardGui`
  over each reads *"<DisplayName>'s share"*, and the `ProximityPrompt` refuses anyone else.
  - ⚠️ One refinement on the wizard answer, called out because it changes behaviour: reserving to players
    who are *alive at open time* would strand a pile forever if its owner is downed at that instant, and
    this game has revives. So a pile is reserved for every player **present in the server**, and a pile is
    **destroyed if its owner leaves** — a locked pile belonging to someone who is not in the game is not
    what "each gold is for each player" means. Say the word and it becomes alive-only.
- **The payout**, per pile: `Profiles.addGold(player, 3)` + `Salvage += 150`, two `RewardFeed` lines
  (gold and salvage are separate rewards — Job #109's rule), and one `CrewToast` so the crew sees who
  collected.

## 6. Run reset

`SalvageServer`'s precedent: watch `Workspace.RunStarted`. On a new run the bunker re-closes, the hoard is
destroyed, and the lamp goes back to red — otherwise an admin-forced second run in the same server finds
the doors already down and the gold already taken.

## 7. Explicitly NOT in this job

`KeyPadLocation` and `NumberLocation` are left untouched. They read as a future keypad-code mechanic;
nothing here writes to them.

## 8. Verification — in PLAY, and it must be able to fail

Edit is not evidence for any of this: the lamp's pulse is a `LocalScript`, and the chest, the piles and
the prompts are all created at runtime. So, in Play:

| # | Check | What FAILURE looks like |
|---|---|---|
| 1 | Boot log names the bunker and its 3 keys | `0 wired`, or a key count ≠ 3 |
| 2 | Doors closed, lamp pulsing **red**, walk into the doors and be stopped | doors already down, lamp dark/green, or you walk through |
| 3 | Kill generators 1 and 2 — **nothing happens** | doors move early |
| 4 | Kill generator 3 → alarm audible, lamp turns **green**, doors take ~10 s down | silent, lamp stuck red, doors snap or stop short |
| 5 | Read back the door pivot: y dropped by 13.86 ± 0.1 | any other number |
| 6 | Screenshot from the player's camera, outside, at door height | a visible sliver of door above the floor |
| 7 | Walk in. Chest + one pile per player, each named | piles inside a wall, floating, or unnamed |
| 8 | Trigger **someone else's** pile | it pays out |
| 9 | Trigger **your own** → +3 Gold, +150 Salvage, two reward lines, crew toast; profile Gold read back | Gold unchanged |
| 10 | Force a second run (`RunStarted`) → doors shut, lamp red, hoard gone | anything left over |

⚠️ Two things `screen_capture` provably cannot show (both burned earlier jobs): **ProximityPrompt bubbles**
and **BillboardGuis**. Those get verified by reading `PlayerGui.ProximityPrompts` / the instance tree and
by triggering the prompt, never from a picture.

## 9. Assets to record (no new sourcing needed — everything already exists)

| Type | Name | Id | Where it goes |
|---|---|---|---|
| Audio | `alarm` | `103190295733089` | shared `audio.md` (Jungle / GAME) + `ASSETS.md` |
| Model | `Bunker` | `AssetLibrary.Structures.Bunker` | `ASSETS.md` — placed + wired row |
| Model | `BunkerDoors` | `AssetLibrary.Structures.BunkerDoors` | `ASSETS.md` — note the double-size template |
| Model | `GoldChest` | `AssetLibrary.Props.GoldChest` | `ASSETS.md` — new use site |
| Mesh | `GoldNugget` | `AssetLibrary.Props.GoldNugget` | `ASSETS.md` — new use site |
