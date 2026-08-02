# Final Summary — Job #073

**Project**: `roblox.jungle`
**Completed**: 2026-08-02
**Status**: ✅ Completed — **one manual Studio step outstanding** (`LightingStyle`, see below)

## What was asked

Move the ambient layer from the lobby to the game place — *"lights, water lights"*, then *"ambient
includes sounds, music etc"*, then *"when game starts it must be early morning, so i do not want that
nights starts early."* Two further items arrived from the playtest mid-job — see **Out of scope**.

## What it turned out to be

The game place was on **stock Roblox lighting** and had **literally no ambient audio** — `SoundService`
with zero children. Measured against both live places, not assumed:

| | GAME (before) | LOBBY (target) |
|---|---|---|
| `Ambient` / `OutdoorAmbient` | grey `(70,70,70)` / `(70,70,70)` | `(74,72,56)` / `(104,106,80)` |
| `ColorCorrectionEffect` | **absent entirely** | `JungleCC` |
| `Atmosphere` | grey, `Glare 0`, `Haze 0` | warm, `Glare .32`, `Haze 2.7` |
| `GeographicLatitude` | `0` | `25` |
| `Terrain.WaterReflectance` | **`1` — a mirror river** | `0.03` |
| ambient audio | **none** | 4 beds + positional |

Two of the game's post-effects were **the same two strays Job #069 cleaned out of the lobby**: a `Bloom`
byte-identical to `JungleBloomHighlight`, and a `SunRays` at `Intensity 0.01` (invisible, but still a
full-screen pass). The rig **adopts and renames** them — creating our own alongside would have left the
game running 6 passes to the lobby's 4, two of them doing nothing.

## What shipped

### New — `sync/ReplicatedStorage/World/AtmosphereRig.luau`

The values live in **one version-controlled module**, not baked into the place. The lobby bakes its rig
with a command-bar script and earned a *"save the place or it resets"* warning in ASSETS.md §1.14 as a
result; this carries no such debt. Two callers share it: `AtmosphereServer` at runtime, and the command bar
for the Edit-time look so the editor isn't grey while building.

`STATIC` (applied once) vs `KEYFRAMES` (lerped off `ClockTime`) — night / dawn 6.5 / morning 9 / **day
16.1 = the lobby's accepted values verbatim** / dusk 17.5 / night 19.5, with 0 h and 24 h holding the same
palette so midnight wraps seamlessly. The 6.5 and 17.5 keys are aligned with `LightController`'s DAWN/DUSK
so the palette turns at the same moment the lights do. `ClockTime` is deliberately never written.

### New — `sync/ServerScriptService/World/AtmosphereServer.server.luau`

Applies the static half once, then tracks the palette at 2 Hz. Server-side so every client gets the same
sky. ~11 property writes twice a second, against `DayNightServer`'s existing 60 Hz — a rounding error.

### New — `sync/ServerScriptService/World/GameSoundscape.server.luau`

Four crossfading 2D beds (birds ×2, wind, cicadas), positional `water-splashes` at the dock, and the two
phase stingers. No looping music bed by decision — `lobby_intro_music` stays the lobby's signature.
**`morning_starts` / `night_starts` had been uploaded and owned since Job #064 and read by nothing**; this
is that wiring.

It holds silent until `Workspace.IntroWake` and fades in over 2 s as the crew comes round, so birdsong
never plays under the plane cabin or over the loading mask — the bug Job #072 shipped once.

### Changed — `DayNightServer`: the clock is now non-linear

Was a uniform 24 h per 4 real minutes from 08:00. A run is 18 000 studs at ~30 studs/s — 10 min at best,
12–15 real — so **night fell 1 min 50 s in and a run saw three full cycles.** Now starts **06:30** with
daylight (13 h) over 480 s and night (11 h) over 180 s.

Stepping to the day/night boundary *first* and spending the frame's remainder at the new rate keeps both
segment durations exact even when a frame straddles dawn — otherwise a long frame at the night rate could
overshoot dawn by most of an hour.

⚠️ **This is a balance lever, not just a look change:** `EnemyServer` scales spawn rate and bite damage off
`Phase`, so these two constants decide how much of a run is spent under sea-threat pressure.

### Files changed

| File | |
|---|---|
| `sync/ReplicatedStorage/World/AtmosphereRig.luau` | **new** — the palette + `apply()` |
| `sync/ServerScriptService/World/AtmosphereServer.server.luau` | **new** — drives it off the clock |
| `sync/ServerScriptService/World/GameSoundscape.server.luau` | **new** — beds, dock water, stingers |
| `sync/ServerScriptService/World/DayNightServer.server.luau` | re-paced, non-linear clock |
| `sync/ServerScriptService/World/FoliageServer.server.luau` | spawn-base exclusion |
| `sync/StarterPlayer/StarterPlayerScripts/Boat/BoatSound.local.luau` | **new** — live engine + hit (added mid-job) |
| `ASSETS.md` | new §3.1 + §3.2 + §6.1; §1.11 cicada note; §2 boat engine row |
| `STYLEGUIDE.md` | §8 canonical night values + `LightingStyle` gate |
| `../roblox.workspace/Assets/registry/audio.md` | boat engine + hit + `gun_shot` entries |

### Added mid-job at your request — the boat's audio

`BoatSound.local.luau` wires three uploads you made while the job was open:

- **`boat_engine_starts`** — one-shot when a player takes the helm, positional on the stern `Motor`.
- **`speed_boat_loop`** — the live engine. `Volume` **and** `PlaybackSpeed` both track
  `max(speed/30, throttle × 0.55)`: the throttle key gives an instant response, and real hull speed takes
  over authority as the boat gets going. Neither alone works — speed alone lags your input by half a
  second, and `VehicleSeat.Throttle` alone is binary (1/0/−1) so it can't express labouring-vs-cruising,
  which is the whole point of an engine note.
- **`boat_hit`** — hooked to the boat's **`HP` attribute dropping**, not to each damage source. Enemy
  bites (`EnemyServer`) and river obstacles (`ObstacleServer`) both just write `HP`, so one hook covers
  both and anything added later. ⚠️ Decrease-only, because `RoleServer` regenerates HP while the Repair
  station is manned — verified that heals add nothing.

**Client-side on purpose.** The engine note changes every frame; driving that from the server would
replicate two property writes per frame to every client for no benefit. The boat is server-owned, so
velocity, throttle and `HP` already replicate — each client reads them and drives its own local Sounds.

*"Stop when the boat is stopped"* is implemented as: below 1.5 studs/s with the throttle released for 1.2 s
→ fade out and `Pause`. Not `Stop`, and not instant — an instant cut chatters on and off at every dock, and
resuming mid-phrase avoids the loop re-announcing itself. It resumes **without** re-cranking the starter,
because the engine never actually turned over again.

**A bug in it, caught in Play:** the first version logged `boat has no Hull/DriverSeat` on every run. The
server builds the boat before any client script runs, but the **model replicates to the client before its
children do** — and `boat.PrimaryPart` is no help either, it can still be nil at that moment. Now uses
`WaitForChild` with a timeout plus a generation guard so a rebuilt boat can't have its connections stolen
by a stale attach.

## Five things that were wrong and got fixed

### 🔴 Night was pitch black — because two properties I'd called static aren't

The first night build screenshotted as effectively black: sand unreadable, palms flat silhouettes, which
STYLEGUIDE §8 explicitly forbids. The cause was carrying the lobby's `ExposureCompensation 0.12` and
`EnvironmentDiffuseScale 0.5` into night as constants. They are **time-of-day values** — at night the sky
*is* the light source, so halving its contribution while refusing to lift exposure leaves nothing to see
by. Both moved into the palette (night: `0.26` / `0.85`).

A second pass pulled `ccSaturation` back from −0.10 to −0.04, because at −0.10 the sand read as grey
**snow** rather than sand under moonlight. Tuned by screenshot, not by theory.

### 🔴 The cicadas were never one-shots — the clip is 71 seconds long

The approved plan was "push the cicada one-shots up in rate and volume at night". Reading the live Sound in
Play gave `TimeLength 71.4`. So each "one-shot" is still playing when the next two start: at the night gap
of 6–16 s that is **six or seven concurrent 71-second cicada loops** — a wall of noise.

Changed to a **crossfading fourth bed** (day 0.04 → night 0.34). Same intent — cicadas take over at night —
but it cannot stack and costs one `Sound` instead of N.

⚠️ **The lobby has the same latent bug** (18–44 s gap, ~2 copies overlapping at all times). Not touched
from here — different place — but recorded in ASSETS.md §1.11 so it isn't rediscovered.

### 🔴 `night_starts` cannot be played at all — and the failure would have leaked a Sound every flip

Play log: `Failed to load sound rbxassetid://99602574849976: Asset is not approved for the requester`,
with `IsLoaded` stuck false.

**The id is not wrong.** `GetProductInfo` returns name `night_starts`, `AssetTypeId 3`, creator
`johnygorsky10`. Nor is it a per-experience permission pattern — `morning_starts`, `battle_starts`, all
four beds and the dock water load fine in the same place. It is specific to that one upload: Roblox audio
moderation hasn't approved it. **→ TODO 0044**, needs a re-upload. `morning_starts` works, so the day
stinger is fine.

That exposed a bug in my own code: `Ended` **never fires** for a Sound whose asset fails to load, so
`Ended:Once(destroy)` alone leaked one `Sound` into the folder on every phase flip, forever. There is now a
20 s backstop that destroys it regardless and warns if it never loaded.

### 🔴 Greybox trees were being planted through the hand-built camp *(user-reported mid-job)*

*"what are these random graybox trees???? do not use them anymore here in spawn area"*

`FoliageServer` streams box-trunk/box-canopy greybox from `boat.Z − 220` to `boat.Z + 800`. The boat now
starts at Z −270 (Job #072), so it was planting greybox straight through a camp hand-dressed with 45 real
palm/tree/fern models. It already had a `DOCK_CLEAR` carve-out for landing docks; it just knew nothing
about `SpawnBase`.

The exclusion is **measured from the camp itself**, so extending the dressing in the editor widens it with
no script edit. Two traps avoided:

- **World AABB from part corners.** `GetBoundingBox()`/`GetExtentsSize()` return the *oriented* box and lie
  about world occupancy — the lesson Job #072 learned on the plane wreck.
- **`Dock.PlacePlace` excluded.** It is the plane's fly-in marker parked 500 studs west at X −760, not camp
  geometry; including it inflated the footprint from 681 to **845** studs wide and would have suppressed
  foliage over empty terrain the player never visits.

### 🟠 A start-up race put one frame of afternoon at dawn

`AtmosphereServer` seeded from `Lighting.ClockTime`, which still held whatever the place was *saved* with
(16.1, from the Edit-time bake) because `DayNightServer` hadn't written the run's start hour yet — the log
read `applied at 16.10h` on a run that starts at 06:30. It now waits briefly for `Workspace.ClockTime`, the
attribute `DayNightServer` publishes, so the **first** frame is right rather than corrected half a second
later. Falls back to the property if no `DayNightServer` exists.

## 🔴 One manual step remains — `LightingStyle`

**`Lighting.LightingStyle` cannot be set by a script.** The game place is `Soft`; the lobby is `Realistic`.
Refused even from the Studio command bar, which is a *privileged* context — the same capability gate the old
`Technology` property hit (Job #069). `ShadowSoftness 0.2` **is** writable; `PrioritizeLightingQuality` is
also refused but the game place is already `true`, so that one is harmless.

> **Studio → `Lighting` → Properties → `LightingStyle` → `Realistic`, then save the place.**

`AtmosphereRig.apply()` returns it in a `REFUSED:` list on every single run, so it cannot be quietly
forgotten.

## Verification

- [x] `[DayNight] start 6.5h · day 13h over 480s · night 11h over 180s (night falls 462s in)` — 7 min 42 s,
      as designed; night lasts ~3 min and dawn returns before the finish
- [x] `[AtmosphereRig] applied at 6.50h (0 stray post-effect(s))` — adoption worked; **4 enabled passes**,
      the same budget as the lobby (`JungleCC`, `JungleBloom`, `JungleBloomHighlight`, `JungleSunRays`,
      plus DepthOfField disabled)
- [x] Live `Lighting` matched the module's own `paletteAt()` sampled at 7.76 h, 8.25 h, 11.05 h and 15.68 h
- [x] Palette verified across 0 / 5 / 6.5 / 9 / 16.1 / 17.5 / 19 / 19.5 / 22 h, including the 19:00
      mid-blend, and the 16.1 h values equal the lobby's live values exactly
- [x] Water `(24,78,86)` / `0.30` / **`0.03`** — no longer a mirror
- [x] Day look screenshotted (wide + eye-level); night look screenshotted and tuned over two passes
- [x] `[GameSoundscape] live — birds×2 + wind + cicadas (2D beds), water×1, phase stingers armed` — after
      the wake, not over the loading mask or the plane cabin
- [x] All beds + dock water `IsLoaded true`; `DockWater` positional at `BoatPlace` (−149, 15.7, −270)
- [x] `Phase` listener fires the crossfade and both stingers
- [x] `[Foliage] spawn-base exclusion: X -636..124 Z -593..49 (1557 parts, +40 margin)` — **0 greybox parts
      inside it**, greybox now begins at Z 5 (exactly where the generated river starts), all 45 hand-placed
      camp models intact
- [x] **Night verified end to end in Play** — every value landed on target exactly:
      `bri 1.50 · exp 0.26 · envD 0.85 · amb (44,50,64) · out (66,76,96) · haze 1.20 · sat −0.04`, and the
      audio mix at `0.060 / 0.030 / 0.200 / 0.340`. Sampled across 23.56 h → 0.17 h → 0.78 h with **no
      discontinuity**, so the midnight wrap is clean. *(Reached by temporarily starting the clock at 17:36
      — an 8-minute wait kept being cut short by Studio use. Reverted to 6.5 and re-confirmed:
      `start 6.5h … night falls 462s in`.)*
- [x] `lights 0` while fully dark — confirms the flagged debt that nothing in the world is tagged
      `NightLight`
- [x] Boat engine sounds attach: `EngineLoop` + `EngineStart` on `Motor`, both `IsLoaded true`, correctly
      silent with nobody at the helm
- [x] `boat_hit` hook fires on damage, scales volume within its 0.45–0.95 band, and **adds nothing on a
      heal**. *(The exact volume-per-damage mapping couldn't be pinned down: the live server keeps
      reasserting `HP` and enemies were biting, so test writes interleaved with replication. A limitation
      of the test, not of the code.)*
- [x] `tools/luau-analyze.sh` clean over the whole GAME tree after every change
- [ ] **User to set `LightingStyle = Realistic` by hand and save the place**
- [ ] User to eyeball the night palette in-game and say whether it wants to be darker (it is knowingly
      lifted — see `Planned/camp-night-practicals.md`)

## Out of scope — filed, not done

| Item | Where | Why not here |
|---|---|---|
| `battle_starts` stinger | `Planned/combat-encounter-stinger.md` | `EnemyServer` is a continuous trickle spawner — no wave, encounter or aggro-start concept to fire on. Wiring it means inventing encounter detection **inside the combat system**: a gameplay change, not an ambient one |
| Camp night practicals (fire pit, lanterns) | `Planned/camp-night-practicals.md` | **0 `Light` objects exist in the whole game Workspace.** The night palette is knowingly lifted just to keep the camp navigable — global ambient doing a practicals job, which is the "lit evenly" failure §8 forbids. That job must bring the palette back **down** |
| Remove the MEDIC billboard | TODO 0042 | User asked for it as a todo. `CargoServer` ~line 177 |
| Real Robux shop in the game place | TODO 0043 | User asked for it as a todo. The lobby's `RobuxShop.local.luau` already has real store art |
| `night_starts` re-upload | TODO 0044 | Needs a Creator Hub action, not code |
| Dark slab under the boat hull | TODO 0045 | Investigated, not fixed. **Ruled out** stray world geometry (radius query returned only the player; five downward rays hit only Terrain), so it is a boat part — and the only dark diamond-plate parts on the boat are the **armour plating** (`ArmoredHullL/R`, plain Parts `0.8 × 2.4 × 22` at local x ±7.4). Three reasons it reads wrong are in the todo, incl. that it's a bare Part so the Paint Pack never recolours it. Needs a visual confirm — the boat had moved on before I could re-photograph the frame |
| `gun_shot` wiring | ASSETS.md §3.2 + registry | Your call: *"Do not add sound yet, because this will be seperate task, just list it in file."* Recorded in both, wired nowhere; belongs with `GunServer`/`WeaponServer` |
