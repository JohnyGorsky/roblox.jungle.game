# Camp night practicals — warm pools of light at the spawn base

> ## ⚠️ PARTLY DELIVERED by Job #077 (2026-08-15) — READ THIS FIRST
>
> **The RIVER CAMPS half is done.** `CampAmbience` + `Campfire` place 4 warm practicals per dock camp
> (campfire + 2 along the sandbag line + 1 inside a hut), all tagged `NightLight`, plus a flickering
> fire and night fireflies. Verified live: 8 lights switch on at dusk, fireflies on / motes off, fire
> brightness flickering 1.93–3.11 around a base of 2.6. **The claim below that there are 0 `Light`
> objects in the Workspace is no longer true.**
>
> **What is STILL OPEN, and it is the harder half:**
> 1. **The SPAWN BASE has no practicals.** Job #077 only touched the streamed river camps. The plane
>    wreck, dock and tents at the spawn base still have nothing to light with.
> 2. **The night ambient is still artificially lifted.** Job #073 propped up `AtmosphereRig.NIGHT`
>    (`outdoorAmbient (66,76,96)`, `exposure 0.26`) *purely because* there were no practicals — and this
>    file said the two changes must land together. Job #077 deliberately did **not** touch it
>    (assumption A1): those camps are 6 spots on an 18,000-stud river, and dropping the GLOBAL night
>    ambient to suit a lit camp makes the other 17,000 studs unnavigable, with the river at night a core
>    beat (`EnemyServer` scales sea threat by `Phase`).
>
>    So the camps are lit, but their pools read weaker than §8 wants against a night that is still
>    lifted. **Dropping the ambient is its own job, and must be balanced against the boat searchlight
>    and the player torch, not against a camp.**

**Source:** Job #073 (ambient port), flagged during the day/night lighting build. **Depends:** #072
(SpawnBase hand-built), #073 (day/night rig live).

STYLEGUIDE §8 is explicit about night: *"warm practical pools of light — lanterns warm amber; torches
warm orange; shops warm internal glow. **Small pools of light — do NOT light the whole jungle
evenly.**"*

Right now the game world **cannot** do that, because there is nothing in it to light with. Measured live
in the GAME place, 2026-08-02:

- **0 `Light` objects in the entire Workspace.**
- No `FirePit`, no lantern, no lamp, no torch prop anywhere in `SpawnBase` (78 children: plane wreck,
  dock, 3 tents, ~40 sandbag walls, barrels, crates, rocks, logs, foliage, signs).
- `LightController` already switches anything tagged **`NightLight`** at dusk (17.5 h) and dawn (6.5 h) —
  it works, it just has nothing to switch. The only `NightLight`s in the game are **carried** (player
  torch, boat searchlight).

## The consequence, and the debt it created

Job #073's night palette is deliberately **lifted higher than it should be** — `outdoorAmbient
(66,76,96)`, `exposure 0.26`, `envDiffuse 0.85` — purely so the camp is navigable. The first attempt used
values consistent with a properly-lit camp and the screenshot came out effectively pitch black, which §8
forbids.

So the global ambient is currently doing the job practicals should be doing. **That is the wrong tool:**
it lights everything evenly, which is precisely what §8 says not to do, and it flattens the night.

## Scope

- A `FirePit` in the camp (the wreck already burns for 45 s — this is the *persistent* camp fire) with
  `Fire` + `Smoke` + a warm flickering `PointLight`, tagged `NightLight`.
- Lanterns along the sandbag line and at the dock head — warm amber `PointLight`s, tagged `NightLight`,
  editor-placed and found by name (memory: `lobby-editor-placed-not-scripted`).
- Warm internal glow in the tents and at the Robux kiosk.
- **Then bring the night palette back down** in `ReplicatedStorage.World.AtmosphereRig` (`NIGHT`) so the
  pools actually read as pools. This is the whole point of the job — the two changes must land together
  or night either stays flat or goes black.
- Mobile budget per §8/§10: a handful of lights, not one per prop. 120-stud light range is available
  (see `roblox-studio` skill).

## Why it matters

Night is a real gameplay beat (`EnemyServer` scales sea threat by `Phase`, GAME.md says shelter on land),
and it arrives ~7.5 min into every run under the #073 clock. It currently looks like a dim version of day
rather than a night you want to find light in — which also devalues the player torch and the boat
searchlight, both of which already work.

## Status — SPLIT (2026-08-05)

**The camp-practicals half is Job #077**: campfire `PointLight`, lanterns on the sandbag line and dock
head, warm tent glow — all tagged `NightLight`, which `LightController` already switches at 17.5 h / 6.5 h.

**The `AtmosphereRig.NIGHT` half stays HERE and stays open**, and the reasoning above needs one correction:
this file says the two changes *must* land together. That is true for the **spawn base** — a single lit
location — but not for the river. The dock camps are **6 spots on an 18,000-stud river**; dropping the
global night ambient to suit a lit camp would leave the other ~17,000 studs unnavigable, and night on the
water is a core gameplay beat (`EnemyServer` scales sea threat by `Phase`).

So the ambient drop is a **balance** decision about the boat searchlight and river navigation, not an art
tweak that rides along with placing lights. Approved as assumption A1 on Job #077.

→ Re-promote for the ambient/searchlight balance pass.
