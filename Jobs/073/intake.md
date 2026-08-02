# Job #073: Port the ambient layer from lobby to game (lighting, water, soundscape)

**Project**: `roblox.jungle`
**Created**: 2026-08-02
**Status**: Requirements Gathering — **plan below, decisions taken, building**

## What you asked for

> *"We created base camp for game at 072, now we need to move ambient (lights, water lights) all to
> game. Right now game does not have ambient colors and other colors. So this task is about that. Move
> from lobby to game."*
> …then: *"ambient includes sounds, music etc"*, *"remember we added these sounds in game"*, and
> *"also when game starts it must be early morning, so i do not want that nights starts early."*

---

# Part 1 — What is there now (all read live, 2026-08-02)

## 1.1 The game place is on stock Roblox lighting

Read from the live GAME place (`PlaceId 138141472932347`) beside the live LOBBY
(`PlaceId 114309626266505`). The lobby's live values match `lobby/build/lobby_atmosphere.luau`
**exactly** — no drift, so the script is a clean source to port from.

| Property | GAME (now) | LOBBY (target) |
|---|---|---|
| `GeographicLatitude` | **0** | 25 |
| `Brightness` | 3 | 2.7 |
| `ExposureCompensation` | **0** | 0.12 |
| `Ambient` | **(70,70,70)** stock grey | (74,72,56) |
| `OutdoorAmbient` | **(70,70,70)** stock grey | (104,106,80) |
| `EnvironmentDiffuseScale` / `Specular` | **1 / 1** | 0.5 / 0.5 |
| `LightingStyle` | **Soft** | Realistic |
| `ShadowSoftness` | 0.2 ✅ | 0.2 |
| `Sky.SunAngularSize` | 11 | 13 |
| `Atmosphere` | **Density .30 · Color (199,199,199) grey · Decay (106,112,125) cold · Glare 0 · Haze 0** | Density .40 · Color (196,186,150) · Decay (158,120,72) · Glare .32 · Haze 2.7 |
| `ColorCorrectionEffect` | **absent entirely** | `JungleCC` tint (255,240,212) sat .13 contrast .07 |
| Bloom | one, named `Bloom`, Intensity 1 / Size 24 / Threshold 2 | `JungleBloom` (.5/24/1.4) **+** `JungleBloomHighlight` (1/24/2) |
| SunRays | `SunRays` **Intensity 0.01 · Spread 0.1** | `JungleSunRays` Intensity .08 · Spread .85 |
| `Terrain.WaterColor` | (12,84,92) | (24,78,86) |
| **`Terrain.WaterReflectance`** | **1 — the river is a mirror** | 0.03 |
| `WaterTransparency` / `WaveSize` / `WaveSpeed` | 0.30 / 0.15 / 10 ✅ | same |

Two of the game's post-effects are **the same two strays Job #069 cleaned out of the lobby**:

- its lone `Bloom` is byte-identical to the lobby's `JungleBloomHighlight` → **adopt and rename**, don't
  add a second bloom next to it.
- its `SunRays` at `Intensity 0.01 · Spread 0.1` is the invisible-but-still-a-full-screen-pass stray →
  **adopt and retune**, don't leave it and add a third pass.

## 1.2 The game place has no ambient audio at all

`SoundService` has **0 children** and no `SoundGroup`s. Only `GameLoading.local.luau` and
`PlaneServer.server.luau` touch sound anywhere in `sync/`. ASSETS.md §6 *Global Audio* is a stub.

Meanwhile `morning_starts` / `night_starts` / `battle_starts` are **uploaded, owned, and wired to
nothing** — and both the registry and `LobbySoundscape`'s own header say they belong to the GAME place:

> *"morning_starts / night_starts / battle_starts are day-night/combat cues for the GAME place, not the
> static-afternoon lobby — intentionally not used here."*

## 1.3 What the base camp offers as audio anchors

`Workspace.SpawnBase` (78 children, hand-placed in Job #072): `Plane` wreck, `Dock`, 3 `Tent`, ~40
`SandbagWall`, barrels, crates, rocks, mossy logs, a `Foliage` folder, `sign`.

⚠️ **No `FirePit`, no lamp, no lantern, no torch, and 0 `Light` objects in the entire Workspace.** So
the lobby's campfire-crackle anchor has no counterpart here, and the STYLEGUIDE §8 night rule ("warm
practical pools of light") has nothing in the world to light. See Part 3.

⚠️ **The dock's parts are all literally named `Part`** (60+ of them) — the lobby's
`Dock:FindFirstChild("Pier", true)` lookup cannot work here. `Dock.BoatPlace` is the one stable, named,
editor-placed part on the waterline, so the water loop attaches there.

## 1.4 The clock is the real problem

`DayNightServer` runs `DAY_LENGTH = 240` (a full 24 h in **4 real minutes**) from `START_CLOCK = 8`,
with `Phase` flipping to night at 19:00.

A run is `END_DISTANCE = 18000` studs at a ~30 studs/s top speed → **~10 min minimum, ~12–15 real**.
So today:

- night falls **1 min 50 s into the run**, and
- a single run sees roughly **three full day/night cycles**.

That is exactly the *"night starts early"* you flagged.

---

# Part 2 — Decisions (2026-08-02)

| # | Decision |
|---|---|
| 1 | **Day/night-aware lighting rig**, not a static bake. Day = the lobby values verbatim; night blends to a darker, cooler, denser palette; dawn/dusk warm. Owned by ONE runtime script in `sync/`, so it is in git and survives a place reset. |
| 2 | **Stingers only — no looping music bed.** `morning_starts` / `night_starts` fire as 2D one-shots on the `Phase` flip. `lobby_intro_music` stays the lobby's signature and does not follow. |
| 3 | **Night audio crossfades to cicadas.** The two day beds duck to 0.06/0.03, wind rises to 0.20, and the cicada one-shots go from every 18–44 s to every 6–16 s. Night reads as night using only assets we already own. |
| 4 | **Long day, short night — non-linear clock.** Start **06:30** (early-morning golden dawn, so the crash cold-open lands at sunrise). Daylight 06→19 stretched over **480 s**; night 19→06 compressed over **180 s**. Night arrives ~7.5 min in as a real threat window and dawn returns before the finish. |

### The re-paced clock, against a 12-minute run

| Real time | ClockTime | |
|---|---|---|
| 0:00 | 06:30 | golden dawn — crash cold-open, launch |
| 3:00 | ~11:00 | full day |
| 6:00 | ~16:00 | warm afternoon (the canonical lobby look) |
| 7:30 | 19:00 | **night falls** — `night_starts`, `NightLight`s already on since 17:30 |
| 9:00 | ~23:30 | deep night |
| 10:30 | ~05:00 | dawn returns |
| 12:00 | ~08:00 | finish in morning light |

---

# Part 3 — Things I need to flag before building

## 🔴 There is nothing in the game world to light at night

STYLEGUIDE §8 requires *"Night: warm practical pools of light — small pools, do NOT light the whole
jungle evenly."* The base camp has **zero `Light` objects** and no fire pit or lantern. `LightController`
already switches anything tagged `NightLight` at dusk — but nothing in the world carries that tag; only
the player torch and boat searchlight do, and both are carried.

So night in the base camp will be *evenly dim* rather than *pools of warm light*. The rig can only set
the global palette; **camp practicals (fire pit, lanterns on the sandbag line, tent glow) are world
dressing and belong in their own job.** I am keeping the night ambient deliberately a little lifted so
it is readable rather than pitch-black, and filing the practicals as a planned item.

## 🟠 `battle_starts` has no moment to fire on — deliberately not wired

`EnemyServer` is a **continuous trickle spawner**: `spawnInterval()` escalates with distance and
time-of-day, and there is no wave, encounter, or aggro-start concept anywhere. Wiring a combat stinger
means inventing encounter detection (first aggro after a quiet period, with a cooldown) **inside the
combat system**, which is well outside an ambient job and would be a gameplay change smuggled in as an
audio one.

`morning_starts` / `night_starts` are wired here because day/night *is* the ambient layer. `battle_starts`
goes to `Planned/` with the note above.

## 🟠 The soundscape must stay silent through the cold open

Job #072 already hit this once — *"plane sound started to play through loading screen"*. Jungle birdsong
under a plane cabin, or over the loading mask, is the same bug. The soundscape therefore **holds silent
until `Workspace.IntroWake`** and fades in over ~2 s as the crew comes round, layering under
`ear_ringing`. It stays inert (starts immediately) if there is no intro at all, so a direct Studio Play
is unaffected.

## 🟠 The clock re-pace is a gameplay change, not just a look change

`EnemyServer` scales **spawn rate and bite damage** by `Phase` — "sea peaks at night, land by day". Making
the day 8 minutes and the night 3 changes how much of a run is spent under sea-threat pressure. That is
the intent (night becomes a survivable spike instead of most of the run), but it will want a balance look
once it is felt in Play.

## 🟢 `ClockTime` is not ported

The lobby's `ClockTime = 16.1` is deliberately **not** copied — `DayNightServer` owns the clock and
overwrites it every Heartbeat. The rig reads `ClockTime` and never writes it.

---

# Part 4 — The plan

## Step 1 — `DayNightServer`: re-pace the clock (non-linear)

Start at **06:30**. Advance the clock at a rate that depends on which half of the day it is in:
daylight 06→19 (13 h) over 480 s, night 19→06 (11 h) over 180 s. Keep publishing `ClockTime` + `Phase`
exactly as now so every existing consumer (`LightController`, `EnemyServer`, the new rig) is unchanged.
Keep the moon-disc removal.

## Step 2 — `AtmosphereServer.server.luau` (new, `sync/ServerScriptService/World/`)

One script owns the whole rig. Applies the static half once (latitude, exposure, env scales,
`LightingStyle`, water colour/reflectance/waves, blooms, sun rays, sky), then each half-second lerps the
**time-varying** half from a keyframe table: `Ambient`, `OutdoorAmbient`, `Brightness`, and the
`Atmosphere` + `ColorCorrection` values.

Keyframes at `ClockTime` 0 / 5 (night) → 6.5 (dawn, where `LightController` kills the lights) → 9
(morning) → **16.1 (the lobby palette, verbatim)** → 17.5 (dusk, where lights come on) → 19.5 → 24
(night). Adopts the two strays by rename rather than adding passes, and keeps Job #069's drift check
that warns about any unauthored post-effect.

## Step 3 — `GameSoundscape.server.luau` (new, `sync/ServerScriptService/World/`)

`SoundGroup` buses (`GameMusic` / `GameAmbient` / `GameSFX`), the two 2D jungle beds + wind under a
`GameSoundscape` folder in `SoundService`, the cicada one-shot loop, and `water-splashes` positional on
`Dock.BoatPlace`. Crossfades the whole mix on the `Phase` flip per decision 3, fires the two stingers,
and holds silent until `IntroWake`. Ids in ONE table at the top, mirroring `PlaneServer` and
`Theme.sound` — no id written inline.

## Step 4 — Apply once in Edit, then verify in Play

Run the rig's values into the Edit datamodel via MCP so the **editor** matches too (otherwise building
and screenshots happen under stock grey), read the properties back, and screenshot. Then Play and check
both palettes and the audio mix across a dusk transition.

---

# Part 5 — Added mid-job at your request

These arrived during the playtest. The first was a defect in existing code and was fixed here; the rest
are new audio you uploaded while the job was open, so they were wired here rather than deferred.

| # | Ask | Outcome |
|---|---|---|
| 5 | *"what are these random graybox trees???? do not use them anymore here in spawn area"* | **Fixed.** `FoliageServer` was streaming greybox through the hand-built camp. Exclusion zone measured from `SpawnBase` itself |
| 6 | *"remove that medic label"* | **Filed as TODO 0042** — you asked for it as a todo |
| 7 | *"remove that graybox robux shop, we have real in lobby, use the same"* | **Filed as TODO 0043** — you asked for it as a todo |
| 8 | `boat_engine_starts` + `speed_boat_loop` — *"boat sound must increase when full trottle, and stop when boat stopped, so it must be live sound"* | **Wired.** New `BoatSound.local.luau` |
| 9 | `boat_hit` — *"sound when boat is hit (our boat)"* | **Wired** into the same script, hooked to the boat's `HP` attribute dropping so it covers enemy bites *and* river obstacles from one place |

## Checklist

- [x] Live game + lobby lighting/water/audio state read and diffed
- [x] Base-camp audio anchors surveyed (no fire pit, no lights, dock parts unnamed)
- [x] Run length + clock maths worked out
- [x] Decisions taken (Part 2)
- [x] Step 1 — clock re-paced to 06:30 start, long day / short night
- [x] Step 2 — `AtmosphereRig` + `AtmosphereServer` day/night rig + water
- [x] Step 3 — `GameSoundscape` beds, wind, cicadas, dock water, crossfade, stingers
- [x] Step 4 — applied in Edit, read back + screenshot
- [x] Verified in Play — day palette, **night palette and audio mix hit their targets exactly**, midnight
      wrap clean, greybox exclusion holds
- [x] `battle_starts` + camp night practicals filed to `Planned/`
- [x] Boat engine + hit sounds wired and registered (Part 5)
- [x] ASSETS.md §1.11/§2/§3.1/§6.1 + STYLEGUIDE §8 + registry `audio.md` updated
- [x] Final summary + changelog
- [x] `Lighting.LightingStyle = Realistic` set by hand and the place saved — verified live; the baked
      Edit-time rig survived the save. (A script cannot write it — see final summary)
- [x] `night_starts` resolved — took three assets; `night_starts_2` `75443344927115` plays, and was
      verified firing on a real dusk flip (TODO 0044 closed)

**✅ Job closed 2026-08-02.** The night-brightness judgement is deliberately deferred to
[`Planned/camp-night-practicals.md`](../../Planned/camp-night-practicals.md) rather than left open here:
the palette is knowingly lifted because the world has no light objects yet, and lowering it only makes
sense in the same job that adds the camp practicals.
