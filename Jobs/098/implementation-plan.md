# Job #098 — Implementation plan

**Project**: `roblox.jungle` · **Place**: GAME only (`sync/`) · **Status**: IMPLEMENTED — see final-summary.md

Intake: [intake.md](intake.md) · Studio: `Last River COOP Game`, PlaceId 138141472932347
Image: **`BoatInfo` `rbxassetid://113207367236651`** (registered in `roblox.workspace/Assets/registry/images.md`)

---

## 1. Decisions (agreed via wizard, 2026-08-18)

| # | Decision |
|---|---|
| Frequency | **Once ever**, persisted in the profile |
| Channel | ZoneBanner-style centre banner, **per player** |
| Scope | **Reusable hint system**, seeded with these two |
| Wording | **Match the sign's language** — one mechanic, one name |
| Sign | Near spawn on the path to the dock, board sized to the image's real ~16:9 |
| Sign faces | **Image on the front, SpecialElite text on the back** |

**Agreed copy:**

| Hint | Title | Subtitle |
|---|---|---|
| `carryToBoat` (first pickup) | `CARRY IT TO THE BOAT` | `Deposit it in the centre area of the deck` |
| `fuelAndRepair` (first deposit) | `FUEL & REPAIR` | `Load fuel and mend the hull at the stations on the rear deck` |

Both echo the supplied sign, which says "deposit them in the center area", "use the fuel station", "use
the repair station". A player who reads the sign and then sees the banner should recognise the same
words, not learn two vocabularies for one mechanic.

## 2. Architecture

### 2a. Persistence — `seen` map on the profile

`ProfileConfig.default()` gains `seen = {}` (`{ [hintId]: true }`). The loader is documented as
forward-compatible ("fill any missing field"), so no migration is needed and existing profiles simply
arrive with an empty map.

Two typed accessors on `Profiles`, matching the house style of `getGold`/`addGold` rather than having
callers poke `Profiles.get(p).seen` directly:

```lua
Profiles.hasSeen(player, id): boolean
Profiles.markSeen(player, id)
```

**Profile-not-ready policy (intake §C):** if the profile is unavailable (in-memory fallback, a lost
session), **show the hint**. A repeat is a small annoyance; never teaching the mechanic is the bug this
job exists to fix. `hasSeen` therefore returns `false` when `not Profiles.isReady(player)` — failing
toward teaching, deliberately.

### 2b. Its own remote, not `Announce`

A new `HintBanner` RemoteEvent, fired with **`FireClient`**. `ZoneBanner.local.luau` listens to **both**
it and the existing `Announce`.

Reusing `Announce` was the obvious move and is the wrong one:
- `Announce` is created and owned by `ZoneServer`; firing it from `ExcursionServer` would add a
  load-order dependency between two unrelated systems.
- The two are genuinely different things — a **crew beat** everyone sees versus a **personal teaching
  moment**. One remote each keeps that visible in the code, which is how `CrewToast`, `Announce` and
  `DropCarried` are already organised.

The client work is small: `ZoneBanner` already renders `{title, subtitle, color, icon, sound}` and
already handles "a newer banner replaces an older one", so it needs one extra `OnClientEvent` connection
and nothing else.

### 2c. `Hints.luau` — the reusable part

`sync/ServerScriptService/Progression/Hints.luau`:

```lua
Hints.show(player, id)   -- no-op if already seen; else fire + mark
```

with a table of definitions (`id → title, subtitle, color, icon, sound`). Adding the third hint — and
there will be a third, nobody knows about the turret or the medic station either — is one table entry.

**Icon and sound (intake open question 2):** a teaching beat should not feel like a zone crossing. It
gets `Theme.color.gold` (the game's "pay attention, this is useful" accent) rather than a zone colour,
the `crate` icon for the pickup hint and `fuel` for the stations hint, and the softer `open` UI sound
rather than the combat stinger.

## 3. Call sites — both in `ExcursionServer.server.luau`

| Hint | Where | Guard |
|---|---|---|
| `carryToBoat` | `pickupLoot()`, the **resource** branch, right after `player:SetAttribute("Busy", true)` | ⚠️ **After** the weapon/ammo early-returns. Those crates grant instantly and are never carried — firing there would tell the player to deliver something they are not holding. |
| `fuelAndRepair` | the deposit handler, immediately after the boat's resource attribute is incremented | ⚠️ **After** the "cargo deck full" early-return, so a *refused* deposit never teaches a lesson that did not happen. |

`ExcursionServer` already requires `Profiles` (it credits gold nuggets), so no new coupling.

**Timing (intake open question 3):** fire the pickup hint on a short `task.delay` (~0.6 s) rather than
in the same frame. The `HandsFull` card and the pickup sound land at the moment of pickup; a banner in
the same frame competes with them. A beat later it arrives into a quiet screen.

## 4. The sign

**Built as a real editor Instance via MCP, in `Workspace.SpawnBase.sign`, named `BoatInfoSign`.**

⚠️ **Not script-generated.** The user is going to move it, and anything a runtime script builds would be
rebuilt at its scripted position every run, silently discarding that move. This is the same rule the
lobby already follows.

**Structure** — copying `Survive`'s vocabulary so the landing zone reads as one signage set:

| Part | Size | Material |
|---|---|---|
| `Board` (PrimaryPart) | **10 × 5.9 × 0.4** | `WoodPlanks` |
| `Post` × 2 | 0.6 × 6 × 0.6 | `Wood` |
| `TopRail` | 11 × 0.5 × 0.7 | `Wood` |

`10 × 5.9` is **1.69:1**, matching the image, so nothing is letterboxed or cropped. Taller than
`Survive`'s 8×3 on purpose: this sign is meant to be *read*.

- **Front** — `SurfaceGui` (`PixelsPerStud = 50`, as `Survive` uses) with a single `ImageLabel`,
  `Image = rbxassetid://113207367236651`, `ScaleType = Fit`.
- **Back** — `SurfaceGui` with a `SpecialElite` `TextLabel`, so it reads as a sign from either side
  exactly like `Survive` and `WelcomeSign`. Copy: **`LOAD THE BOAT`**.
- Every part `Anchored = true`, `BorderSizePixel` n/a, no scripts.

**Placement (starting point only).** Spawn is `-265, 18, -311`; the dock is `-172, 14, -302`. The sign
goes on that line, roughly `-228, 21, -307`, rotated to face back toward spawn so an arriving player
reads it as they set off. Ground height gets probed by raycast before committing rather than assumed —
the landing zone is hand-built terrain and a guessed Y buries or floats it.

**Then the user drags it wherever they actually want it.**

## 5. Verification

- **Studio, Edit mode:** build the sign, then **read it back** (`inspect_instance`) *and* `screen_capture`
  from a player's-eye position to confirm the image renders, is not cropped, and sits on the ground —
  per the standing rule that scene edits are verified by read-back **and** screenshot, never assumed.
  Reset `CameraType = Custom` afterwards so Edit navigation is not left locked.
- **Play:** pick up a resource crate → banner fires once; pick up a second → **no** banner. Deposit →
  second banner once. Re-check `Profiles.get(player).seen` to confirm the flags actually persisted.
- **Weapon/ammo crate** → **no** banner (the early-return guard).
- **Full deck deposit refused** → **no** banner.
- `luau-analyze.sh` clean.
- The banner is a HUD element, so re-run `tools/hud-overlap-audit.luau` — `ZoneBanner` is already in the
  audit set and this job puts it on screen in new circumstances.

## 6. What I need from the user

1. **The final sign position** — Claude places it as a starting point; you drag it.
2. Confirmation the image reads clearly at 10 studs wide in-world. If it is too dense to read at a
   glance, the board grows rather than the image being redrawn.

## 7. Out of scope

- Other onboarding gaps (turret, medic station, untie, drop) — real, and worth their own job once this
  system exists, since each is then one table entry.
- The LOBBY place.

## 8. Order of work

1. `seen` on the profile + `hasSeen`/`markSeen` → 2. `Hints.luau` + `HintBanner` remote →
3. `ZoneBanner` listens to both → 4. the two call sites → 5. analyzer → 6. Play verification →
7. the sign in Edit + read-back + screenshot → 8. summary + changelog.
