# Job #116 — Final summary

**Project**: `roblox.jungle` (GAME place only) · **Completed** 2026-08-25 · verified in **Play**

## What shipped

The end-zone bunker is now a working objective, driven by **one reusable system** so a later spawner can
drop bunkers anywhere and get the same behaviour:

> Break all three generators → the alarm sounds and the lamp flips red→green → the doors slide 10 s
> straight down into the ground → walk in and take your share of the gold.

| File | Role |
|---|---|
| `sync/ServerScriptService/World/Bunkers.luau` | **NEW** — the feature, as a module: `attach` / `attachAll` / `spawn` / `close` / `resetAll` / `onOpened` / `progress` |
| `sync/ServerScriptService/World/BunkerServer.server.luau` | **NEW** — the boot: scan Workspace, listen on the tag, re-lock on `RunStarted` |
| `sync/StarterPlayer/StarterPlayerScripts/UI/BunkerClient.local.luau` | **NEW** — the two per-viewer halves: the lamp's pulse, and enabling only the local player's share prompt |

Nothing else was edited. **No new code in the combat path**, no new remote — the loot rides the existing
`RewardFeed` and `CrewToast`, and the unlock hangs off the `Generators.onDisabled` seam Job #115 left
behind for exactly this.

## The design decisions, and why

**A bunker is identified by STRUCTURE, not by name.** Three nested instances in the end zone are called
`Bunker` — a Folder, the Model inside it, and the shell MeshPart inside that. `Generators`' name-prefix
contract would have matched all three plus the AssetLibrary template. The signature is instead *a Model
whose `BunkerDoors` child is itself a Model*, which is also the one thing a spawned bunker cannot lack.

**Its keys are its siblings.** `requiredGenerators` takes every `Generator*` Model under the bunker's own
parent. The end zone already keeps `Bunker` + `Generator1/2/3` in one folder, so it wired itself; a spawner
drops both into one folder and inherits the contract with nothing to configure. Two bunkers in two folders
cannot steal each other's keys, which a proximity search could not have promised. `Bunkers.spawn` accepts
an explicit list for the case where they must live apart.

**A keyless bunker fails CLOSED and says so.** Silently opening one would hand the crew the loot for free,
so the empty slot announces itself with a warning naming the parent it searched.

**Every offset is derived from the model's own bounds.** The library ships `Structures.BunkerDoors` at
*double* the size of the placed copy — the same half-scale trap `Generator3` sprang on Job #115. Door
travel, lamp size, light range, chest size and hoard layout are all read at attach time.

**The lamp is built on the server and pulsed on the client.** A server-side tween on a blinking light
replicates two changing properties every frame, forever, per bunker; an attribute flip replicates once.
Same split `LootGlow.local.luau` makes. Locked pulses at **0.7 s** and open at **1.7 s**, so the *rhythm*
carries the state as well as the colour.

**Prompt ownership is enforced twice, for two different reasons.** `ProximityPrompt.Enabled` is one
replicated property, so the server physically cannot show a prompt to one player and hide it from five —
the client enables only the local player's share (presentation), and `Triggered` re-checks the `UserId`
and pays nobody else (authority).

**Shares are reserved to players present, not players alive.** The wizard answer was "alive at open time";
this game revives, and a pile stranded because its owner was downed in that one second is not what "each
gold is for each player" means. A pile whose owner *leaves* is destroyed instead. Agreed with the user.

## Six bugs found by testing, all measured before being fixed

Every one of these was invisible in code review and would have shipped.

| # | Symptom | Cause | Fix |
|---|---|---|---|
| 1 | Chest was a **1.02 × 0.80 × 1.23** toy on the floor of a 37-stud bunker | `Model:ScaleTo` is **absolute**, and `GoldChest` arrives from the 3D Importer at `GetScale() == 6.0`. Job #079's `ScaleTo(0.65)` was correct for a model then at scale 1; here it asks for 0.65/6 = **11%** | Multiply the *current* scale by a ratio taken from the room's measured headroom. Result: 6.20 × 4.83 × 7.48 — within 1% of #079's intent, and immune to any baked scale |
| 2 | The hoard laid out **away from the doors**, into the 7.6-stud back wall | A `CFrame.lookAt` frame's LookVector is its **−Z** axis, so `frame * CFrame.new(0,0,+forward)` walks backwards | Named world vectors (`frame.LookVector` / `.RightVector`) instead of local offsets — kills the whole class of sign error, not this instance |
| 3 | Every share silently took the "no clear slot" fallback | 🔴 **The validation could not fail.** `GetPartBoundsInBox` against a bunker — ONE concave MeshPart whose *bounding box* is the whole building — returns a hit at the dead centre of the open room. Proven by running it there | A line-of-sight ray from the chest. Rays resolve against collision geometry; bounds queries cannot see concavity. It also asks the better question: *is this share in the same room as the hoard* |
| 4 | `LampArm` existed on the server and **never replicated** | `CFrame.lookAt` with identical from/to → NaN CFrame. It aimed from `marker + outward*(push/2)` at `marker + outward` — the same point whenever push is exactly 2, which is precisely what this bunker measures | Guard on the real length and aim at the bulb. Caught by diffing a server dump against a client dump |
| 5 | Lamp read as a red pool on the sand **with no lamp attached to it** | The bulb sat under the bunker's projecting roof lip; line of sight from a player at the door was blocked | The standoff is now *searched for* against the bunker's own geometry (came out 2.00 studs) and a bracket bridges the gap |
| 6 | The lamp washed the **entire 37-stud facade** red, then green | `PointLight` range 18 reached the ground | Range 14. The bulb is `Neon`, so what carries at distance is the bulb; the light only has to prove it is a lamp (STYLEGUIDE §8, "small pools of light") |

Bugs 5 and 6 were only findable from a **screenshot at the player's own camera**. Bugs 1–4 were only
findable by **reading the numbers back out of a running game**. Neither method would have caught the
other's bugs.

## Proof — measured in Play, at the player's camera

| Check | Result | What failure would have looked like |
|---|---|---|
| Boot | `[Bunker] 1 wired (Workspace.EndBase.Bunker.Bunker (0/3 keys down)) — 10s door slide, 3 Gold + 150 Salvage per crew share` | `0 wired`, or a key count ≠ 3 |
| Doors closed, lamp red | pivot y **22.167**, bulb `(235,45,35)`, `Open=false`, transparency oscillating 0.09 ↔ 0.55 and brightness 3.46 ↔ 0.62 on the client | a static or dark lamp |
| **2 of 3 generators dead** | doors moved **0.000** | any movement |
| 3rd generator dead | alarm playing t=0→8.05 s then stopped; lamp `Open=true` in the same second; doors dropped on a Sine curve `0.34 → 1.32 → 2.85 → 4.82 → 7.00 → 9.14 → 11.09 → 12.62 → 13.58 → 13.863` | silence, a lamp stuck red, or a snap |
| Final drop | **13.863** studs — door top from 35.52 to 21.66, under the 22.10 interior floor | a visible sliver; the screenshot from the player's eye shows a clean doorway |
| Collision | door part `CanCollide` true → **false** | walking into an invisible slab |
| Hoard | chest 6.20 × 4.83 × 7.48 with its bottom at **22.10** (the measured floor); share **7.68** studs from the doors against the chest's 12.68 | a share further from the doors than the chest (bug 2's signature) |
| Ownership | server `prompt.Enabled = false`; client `Enabled = true`, `"Take Your Share" / "3 Gold"`, label `"johnygorsky10's share"`, tags `Lootable+BunkerShare`, `LootGlow` highlight present | a prompt on someone else's pile |
| Payout | Gold **163 → 166**, Salvage **150 → 300**, share destroyed | either number unchanged |
| Run reset | doors back to **22.167 exactly**, `DoorsOpen=false`, lamp red, hoard gone, collision restored | anything left over from the previous run |

⚠️ Two things `screen_capture` provably cannot render — **ProximityPrompt bubbles** and **BillboardGuis** —
so those were verified by reading `prompt.Enabled` / the label text off the instance and by *triggering*
the prompt, never from a picture.

## Checklist deviations

- **Independent reviewer agent: NOT run.** This session is instructed not to call the Agent tool unless
  the user asks, which overrides GROUND-RULES §8. Recorded here rather than quietly skipped. The six bugs
  above were instead caught by read-back-and-screenshot in Play, which is the discipline §7 asks for — but
  a fresh-eyes reviewer remains unrun on this job.
- **Post-verification changes.** Two edits landed after the last full Play pass and were confirmed working
  by the user rather than by a fresh measured run: the warm practical over the hoard, and `resetAll`
  re-evaluating.

## Left open, deliberately

- `KeyPadLocation` / `NumberLocation` are untouched — they read as a future keypad-code mechanic.
- **[findings/0029]** — destroyed generators do not revive on `RunStarted`. `Generators.luau` keeps
  `Disabled = true` through a run reset, so an admin-forced second run in the *same* server starts with
  three dead keys. `Bunkers.resetAll` therefore warns and re-opens rather than sitting shut over keys that
  are all down. Harmless in production (a real new run is a new server); it belongs to Job #115's file.

## Reusability — what a later spawner does

```lua
local Bunkers = require(ServerScriptService.World.Bunkers)

-- drop a bunker and its generators into one folder and it wires itself:
local site = Instance.new("Folder"); site.Parent = Workspace
Generators.spawn(CFrame.new(...), site)   -- x3
Bunkers.spawn(CFrame.new(...), site)      -- finds the three as siblings

-- ...or hand it the keys explicitly:
Bunkers.spawn(cframe, parent, scale, { gen1, gen2, gen3 })

Bunkers.onOpened(function(model) ... end)  -- for an objective, a HUD, a stinger
local down, total = Bunkers.progress(model)
```
