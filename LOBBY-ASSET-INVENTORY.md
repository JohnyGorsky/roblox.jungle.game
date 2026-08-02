# LOBBY-ASSET-INVENTORY.md — every asset the lobby place uses

**Purpose: a reuse manifest for the GAME place.** Generated 2026-08-02 (Job #069) by scanning the live
**Last River COOP lobby** place via Studio MCP, plus every `rbxassetid://` declared in `lobby/sync/`.

> **Why this file exists.** `ASSETS.md` records *what each area needs and its status* (design intent).
> The shared registry records *provenance and licence*. Neither answers **"give me every id the lobby
> actually uses so I can stand the same thing up in the GAME place."** This does.

**Totals:** **188 unique asset ids live in the place** + **53 declared in scripts** (audio, UI icons,
product art — these are created at runtime, so they do **not** appear in an Edit-mode scan).

## ⚠️ Read this before reusing anything

**Rojo does not sync assets.** `lobby/sync/` carries *scripts only*. Meshes, textures, inserted models
and `ServerStorage.AssetLibrary` are **place content** — they live in the `.rbxl`, not in git. So the
GAME place does not get any of this by syncing; each asset must be inserted or imported there.

This is already a known carry-over: `ASSETS.md` §2 warns the boat meshes were *"imported into the
LOBBY place only"* and the GAME place needs the same GLBs under the same names.

---

# 1) AUDIO — the part flagged for reuse

**20 unique audio ids. All 20 are in the shared registry** (`audio.md`), so provenance is covered.

> **Scan note:** an Edit-mode scan finds only **one** `Sound` instance in the place. That is not a
> mistake — `LobbySoundscape` and `UISound` create every sound **at runtime**, so the ids below come
> from the source, which is authoritative. Do not conclude from a place scan that the lobby has no audio.

## 1.1 Ambient beds & music — `LobbySoundscape.server.luau`

| Id | Name | Role | Placement |
|---|---|---|---|
| `135826546197884` | `lobby_intro_music` | Lobby theme | 2D loop, vol 0.35 |
| `116462724806689` | Jungle day ambience 1 | Birds + insects bed | 2D loop, vol 0.22 |
| `93331028777865` | `wind-breeze` | Light wind layer | 2D loop, vol 0.15 |
| `115704936377395` | `water-splashes` | Water lapping | **positional** @ `Dock.Dock.Pier`, vol 0.5 |
| `113774133604878` | `crackle-campfire` | Fire crackle | **positional** @ each `FirePit` (×2), vol 0.6 |
| `128204240690640` | `cicadas` | Wildlife one-shots | 2D, fires every ~18–44 s, vol 0.28 |
| `99642631685891` | `rope_creak` | Rigging creak | **positional** @ every `Watchtower*` (×4), vol 0.25 |

Volume buses: `LobbyMusic` 0.6 · `LobbyAmbient` 0.7 · `LobbySFX` 0.8 (SoundGroups under `SoundService`).

## 1.2 SFX — `Theme.sound`, played through `ReplicatedStorage.UI.UISound`

| Key | Id | Uploaded as | Trigger |
|---|---|---|---|
| `click` | `89108158102227` | `ui_mouse_click` | any button |
| `open` / `close` | `89724136900326` | `open_close` | panel open **and** close (deliberately one asset) |
| `prompt` | `83771530109851` | `prompt` | ProximityPrompt shown — **positional on the station** |
| `countdown` | `116568191818931` | `timer_countdown` | each launch-countdown second — **positional on the pad** |
| `joinPad` | `118942668007111` | `joined_pad` | step on/off a party pad — **positional** |
| `leader` | `83295373162555` | `leader_assigned` | lead changes hands — **positional** |
| `launch` | `74173367633003` | `teleport_woosh` | party launches — **positional** |
| `purchase` | `108328452137259` | `purchase_success` | buy confirmed |
| `fail` | `95777104498740` | `failed_or_not_allowed` | insufficient funds / cancel |
| `upgrade` | `98721741422623` | `upgrade_applied` | boat/skill upgrade bought |
| `rank` | `135669512865613` | `rank_completed_or_mission_completed` | rank-up / mission complete |
| `footstepWood` | `74260976253608` | `footsteps_wood` | dock / stall decks |
| `runSand` | `113877578461119` | `running_on_sand` | airfield clearing |

**The 2D-vs-positional split is a design decision worth carrying into the GAME place**: interface cues
are 2D; world cues play *from the object that made them*, so a party forming is audible across the
airfield instead of only in one player's ears.

**Reuse note:** `Theme.luau` is the single source of every id. Copying that one file to the GAME tree
brings all 13 SFX with it — no id is written in any screen script.

## 1.3 Uploaded but NOT wired

| Id | Name | Note |
|---|---|---|
| `120011248667884` | Jungle day ambience 2 | Owned, in the registry, **used by nothing** (`todo/0026`) |

`morning_starts` / `night_starts` / `battle_starts` exist in the registry and are **deliberately** not
used in the lobby — they belong to the GAME place's day-night and combat systems.

---

# 2) ANIMATION

| Id | Used by |
|---|---|
| `71254620030056` | Pilot idle — looped by `PilotIdle.server.luau` on `workspace.Pilot` (22-bone rig) |

---

# 3) UI IMAGES — 32 ids, all registered

Runtime-created, so absent from a place scan. All live in `Theme.luau`.

**23 icons** (`Theme.icon`): `close 140590179467868` · `coin 77292050689166` · `shop 113169065974317` ·
`star 123611506595607` · `wrench 90679964955780` · `party 103042204848069` ·
`calendar 78068320446462` · `check 108692155956143` · `bounty 106187109040565` ·
`engine 94903113819644` · `hull 111545806353192` · `fuel 128001249531842` · `crate 123909056802404` ·
`tools 109933399936454` · `boat 79958224084386` · `crew 108066459106452` · `wheel 124599807882020` ·
`medkit 87252065857781` · `gun 120983452101559` · `spotlight 111067444220887` ·
`loot 121749397596257` · `trophy 72442029972402` · `robux 100088930369566`

**8 product/pass art** (`Theme.productIcon`, transparent re-uploads): `pack10 72255341573939` ·
`pack25 114957317211525` · `pack60 100983946600429` · `pack150 133943328068949` ·
`armoredBoat 130910653087108` · `boatPaint 82416796032835` · `selfRevive 131281323216251` ·
`extraSlots 130798210334331`

**1 loading background**: `73636751330777` — fallback in `LobbyLoading` / `GameLoading`.

> Two gotchas that will bite in the GAME place: the icons are **full-colour flat**, not mono, so
> `ImageColor3` muddies them — seat them on a dark chip instead of tinting. And **never use a Creator
> Hub thumbnail id in-game**: the 2026-07-20 batch is matted onto an opaque disc and renders as a white
> blob. `extraSlots` is the one exception — that upload carries alpha, verified in Play.

---

# 4) BOAT MESHES — 18, already documented

`ServerStorage.AssetLibrary.BoatParts`, mapped by `ReplicatedStorage.Boat.BoatParts`. Full notes in
`ASSETS.md` §2; **all are in the registry** (`meshes.md`).

`Hull 89521912881313` · `CargoDeck 121083381228019` · `DriverSeat 92120079364409` ·
`Motor 93982818285882` · `GunBase 83630637675983` · `GunBarrel 138785726504897` ·
`GunBarrelHeavy 105379146957646` · `GunSeat 126708341359233` · `BowLight 91153379103503` ·
`HullPlate 109319594296029` · `FuelTank 113505197391374` · `SearchLightHead 127871044013620` ·
`SearchlightMast 110987057092036` · `CargoRacks 133551732172203` · `RampBow 130643201140870` ·
`FuelStation 97274117345322` · `RepairStation 125616975055918` · `MedicStation 117730471003292`

Every one ships with a full `SurfaceAppearance` (ColorMap + Normal + Roughness + Metalness) — that is
**~110 of the 188 live ids**, four maps per mesh.

> 🔧 **After importing these into the GAME place, run once and save:**
> `local BP = require(game.ReplicatedStorage.Boat.BoatParts) print(BP.preparePaintLibrary())`
> Skipping it doesn't break anything — the Paint Pack liveries just render flat. **Confirmed already
> done in the LOBBY place** (18 MeshParts, 3 `PaintablePBR`).

---

# 5) 🔴 HERO MESHY MESHES — used live, NOT in the registry

**This is the real gap this inventory found.** These were uploaded by the user and imported straight
into the lobby place. Their mesh ids exist **nowhere but the `.rbxl`** — not in the registry, not in
`ASSETS.md`, not in any script. If the place file were lost, or the GAME place needs the same props,
these ids are the only way back to them.

| Mesh id | In-place name | What it is |
|---|---|---|
| `118873896425222` | `Plane` | The landmark cargo plane (§1.2) |
| `108352617907497` | `char1` | The **Pilot** NPC body (§1.2) |
| `107408955523438` | `SkillTrainer` | Skill Trainer stall (§1.3) |
| `119564283624615` | `Boutnies` *(sic)* | Bounties stall (§1.3) |
| `81119390187013` | `RobuxhShop` *(sic)* | Robux Shop kiosk (§1.3) |
| `118860073556013` | `BoatUpgrade` | Boat Upgrades mechanic rig (§1.3) |
| `114620021340964` | `RunWay` | Runway tile — 6 instances (§1.2) |
| `139814217941669` | `Mesh1.0` | **Unidentified** — generic name, needs a look |

Two are **misspelled in the place** (`Boutnies`, `RobuxhShop`). Harmless today — nothing binds to those
names, since `LobbyStations` finds stations by the `Station` **attribute** — but worth knowing before
anyone writes a find-by-name against them.

**Recommended:** add all 8 to registry `meshes.md`. Filed as `todo/0041`.

---

# 6) STORE-MODEL COMPONENT MESHES — 27 ids

These are the meshes *inside* inserted Creator Store models. The registry correctly tracks these at
**model** level (`models.md` — e.g. PalmTall `5031791950`), which is the right granularity for
re-inserting. Listed here only so a place scan reconciles.

| Group | Component mesh ids |
|---|---|
| Palms (PalmTall / PalmCurved) | `14410065630` `14410065873` `14410066128` `14410066352` |
| PalmLowPoly | `1436299029` (Trunk) `1436301104` (Leaves) |
| JungleTreesPack | `1485912779` (Bark) `1485915491` (Leaves) |
| BushPack (8 broadleaf variants) | `118083754255318` `122867946846776` `127374948457251` `73068735731161` `80735823453602` `80897606053683` `86661083237364` `99564750643631` |
| Bushes | `742752350` `742756209` |
| FernTall | `5548709970` |
| Rocks ("rocks 3") | `13967716996` `13967716997` `13967716999` |
| LogMossy | `5547039339` |
| Tent | `2712915377` |
| Sandbags | `100818418128703` `131295969227139` |
| Ammo box | `11330332085` |

---

# 7) SKY & DECALS

**Sky** (5): `SkyboxUp 6412503613` · `SkyboxBk 6444884337` · `SkyboxDn 6444884785` ·
`SunTextureId 6196665106` · `MoonTextureId 6444320592`

> Reuse caution: the lobby is a **static warm afternoon**. The GAME place has a day/night cycle, so
> this skybox and the `Lighting` rig are a *starting point*, not a drop-in.

**Decals** (6): `186405730` (×1199 — the dominant surface texture) · `319943200` (Bark, ×198) ·
`1485917255` (trunk, ×60) · `16944307253` (Sticker, ×8) · `3337767860` (×6) · `73636751330777`
(loading background).

---

# 8) What the GAME place actually needs

| Category | How it transfers |
|---|---|
| **Audio (20)** | ✅ Easiest win. Copy `Theme.luau` for the 13 SFX; port `LobbySoundscape`'s 7-id table. Ids are universal — nothing to import. |
| **UI images (32)** | ✅ Copy `Theme.luau`. Ids are universal. |
| **Boat meshes (18 + ~72 PBR maps)** | ⚠️ Must be **imported into the GAME place**, same names, then run `preparePaintLibrary()` and save. Known carry-over from Job #066. |
| **Hero Meshy props (8)** | ⚠️ Re-import from the ids in §5 — **register them first** (`todo/0041`). |
| **Store models** | ⚠️ Re-insert from `models.md`, then **scan for scripts** before use (GROUND-RULES §4). |
| **Sky / Lighting** | ⚠️ Reference only — the GAME place needs day/night, not a static afternoon. |

---

*Regenerate by re-running the Job #069 inventory sweep in Studio + `grep -rhoE "rbxassetid://[0-9]+" lobby/`.*
