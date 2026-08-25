# Final Summary — Job #115

**Project**: `roblox.jungle`
**Completed**: 2026-08-25 00:41:18
**Status**: ✅ Completed — **signed off by the user in game, 2026-08-25** ("it works fine")

## What was implemented

The three end-zone generators are destructible, and the behaviour lives in ONE reusable module so a later job gets it for free.

**`World/Generators.luau` (new, the reusable half)** — `attach(model)` wires one generator: sets `PrimaryPart` (these models ship without one, and `MeleeServer` reads it to place the impact burst), `HP`/`MaxHP` = 150, builds the FX rig, connects ONE `HP` watcher, and adds the `Generator` tag last so nothing can shoot a half-built prop. Also `attachAll(root)`, `spawn(cframe, parent, scale)` off `AssetLibrary.Structures.Generator`, `onDisabled(fn)`, `isAlive`, `all()`. Idempotent, so the boot scan and the tag signal can both fire for the same model.

**`World/GeneratorServer.server.luau` (new, the boot half)** — finds the editor-placed ones by the `Generator*` NAME PREFIX under Workspace (the same contract `EscapeServer` uses for its `Escape` marker), and wires anything tagged `Generator` later. Scans Workspace, never ServerStorage, so the library template stays clean.

**Behaviour, as asked:**
- **150 HP** = exactly 10 axe swings; 8 pistol shots; ~2 point-blank shotgun blasts — bullets beat melee purely on the weapons' own numbers.
- **Alive**: looped positional `eletricity_going` hum (0.32, 90-stud tail) + blue-white sparks falling off the whole housing at Rate 20 + a night-only PointLight that `LightController` owns.
- **Hit**: the hum's clip restarted loud and cut at 0.5 s as a zap, plus a burst of ~16 big RED/orange embers that then smoulder at Rate 7 for 1.6 s.
- **Approached**: the HP bar is a BillboardGui with `MaxDistance` 70 — per-viewer culling, no loop, same green/amber/red bands as the enemy bars.
- **Dead**: hum and zap stopped, `generator_dead` one-shot, sparks off, one last flare, smoke on, bar replaced by a **DISABLED** sign readable from 110 studs, and 6 Salvage to whoever landed the killing blow.

**Why so little of it is new code:** the three damage sites already find a tagged Model and subtract from its `HP`, so making a generator destructible is one tag in each of their target lists (three lines), and every reaction hangs off `HP` changing. No new remote, no new damage path, and **no per-frame loop anywhere** — three props that cost nothing to stand still.

**Two traps that would have shipped as bugs:**
1. A dead generator's light would have **switched itself back on at dusk** — `LightController` re-applies every `NightLight`-tagged light at 17.5 h, so death has to REMOVE the tag, not just set `Enabled = false`.
2. `Generator3` is the same asset at **half scale** on a tower, so a hard-coded bar height or particle size would have looked right on two of the three. Every offset is derived from `GetBoundingBox`: the bar sits 6.2 studs up on the big ones and 4.2 on the small one, sparks 0.50 vs 0.25.

Scope note: destroying a generator has no world consequence yet (no doors, no power). `Generators.onDisabled(fn)` and `Workspace.GeneratorsDisabled` exist so that job needs no changes here.

### ✅ Auto-synced files

- `sync/ServerScriptService/World/Generators.luau`
- `sync/ServerScriptService/World/GeneratorServer.server.luau`
- `sync/ServerScriptService/Combat/MeleeServer.server.luau`
- `sync/ServerScriptService/Combat/WeaponServer.server.luau`
- `sync/ServerScriptService/Combat/GunServer.server.luau`
- `sync/ServerScriptService/Economy/KillReward.luau`

### 📄 Docs (not Studio content)

- `ASSETS.md` — §3.7 gets the generator + generator-audio rows and a do-not-rename warning
- `../roblox.workspace/Assets/registry/audio.md` — both ids, measured lengths, their two roles

### ⚠️ Manual Studio copy required

- _none_ — both new scripts are under auto-synced paths and were confirmed in Studio by `script_grep`

## Proof it works better - MANDATORY (GROUND-RULES 7)

All of the below was read back **in PLAY** in the game place (Last River COOP Game, 138141472932347)
on 2026-08-25, off the live server, and re-run once more on the final tuned build.

### Before

No such prop. The three generators were inert scenery: no `HP`, no tag, no `PrimaryPart`, nothing to
damage, no sound and no particles. `CollectionService:GetTagged("Generator")` returned 0.

### After — the numbers

| Check | Result |
|---|---|
| Cold boot | `[Generator] 3 wired (Generator1, Generator2, Generator3) — 150 HP each, destructible by melee, handheld guns and the turret`, no warnings anywhere in the log |
| Wiring | all three `HP=150/150`, `Disabled=false`, `PrimaryPart=Generator`, hum `IsPlaying=true` |
| Per-model scaling | bar offset **6.20 / 6.20 / 4.20** studs, spark size **0.50 / 0.50 / 0.25**, light range **13.0 / 13.0 / 6.5**, smoke size **3.2 / 3.2 / 1.6** — the half-scale one is scaled everywhere, from `GetBoundingBox` |
| Melee kill (axe) | exactly **10** swings: `150 135 120 105 90 75 60 45 30 15 0`, server log `[Melee] HIT Generator1 … (KILLED)` → `[Generator] … DISABLED (1 of 3 down)` |
| Gun kill (pistol) | exactly **8** shots: `150 130 110 90 70 50 30 10 0`, `[Weapon] HIT Generator2 … (KILLED)` — bullets beat melee on the weapons' own numbers, as asked |
| Hit reaction | zap sampled 0.15 s after each swing: `playing=true t=0.12…0.17`; silent again by 0.75 s (`ZAP_TAIL` 0.5 s). Burn emitter `Rate=7` between hits, back to 0 after |
| Death state | `hum playing=false`, `sparks enabled=false`, `burn Rate=0`, `smoke enabled=true`, sign `"DISABLED" visible=true`, bar `Visible=false`, `MaxDistance 70 → 110`, death Sound created on the prop with id `119782619832290` |
| The dusk trap | `NightLight` tag on the dead generator's light: **false** — so `LightController` cannot relight it at 17.5 h |
| Payout | `Workspace.GeneratorsDisabled` 1 → 2, player Salvage **0 → 6 → 12** (6 per generator, via `RewardFeed`) |
| Spawn-later path | cloned `AssetLibrary.Structures.Generator`, placed it, **only tagged it** → came up `HP=150/150`, `PrimaryPart` set and all 13 FX children built; `Destroy()` dropped it back to 3 tagged and left the template untagged |
| Static analysis | `luau-lsp analyze` (v1.69.0, rojo sourcemap + downloaded globalTypes) — zero diagnostics on all six code files; the run was proved able to fail first on a throwaway type error |

### What failure would have looked like

Swings landing with no HP change (the tag missing from a target list); HP falling but nothing reacting
(the `HP` watcher not connected); a melee hit with no impact burst (`PrimaryPart` left nil); the small
generator wearing the big one's bar inside its own roof (hard-coded offsets); a dead generator humming,
sparking, or lighting up again at dusk; or Salvage not moving on the killing blow.

### 🔴 What could NOT be verified by tooling, and why

**The LOOK.** `screen_capture` does not render the world-space layer at all — no `BillboardGui`, no
`ParticleEmitter`, no legacy `Smoke`. Proved by control in this session: a locally created magenta Neon
**part** 9 studs above the generator appears in the capture, while in the same frame a control
BillboardGui, the prop's Smoke forced to size 9 / opacity 1, and its spark emitter all render nothing —
and a capture of the extraction pad shows the pad but neither its `ExtractionSign` billboard nor its
`PadMotes`, both of which were tuned BY EYE in Job #111 and therefore certainly render in the real
client. So every visual claim above is a property read-back plus an on-screen projection test
(`WorldToViewportPoint` put the sign dead centre of the viewport at 20 studs), **not** a screenshot.

👉 **Left for the user:** confirm the FEEL of the four visuals in game — spark density (Rate 20, ~7
alive at once), the red burst size on a hit, the smoke plume, and the hum/zap volumes (0.32 / 0.9).
Every one of those is a single constant at the top of `Generators.luau`.

✅ **CLOSED 2026-08-25** — the user played it and confirmed: *"it works fine"*. That closes the one gap
this job could not close itself (the look and the mix), so the shipped tuning is the approved tuning: no
constant below is provisional any more. Anything further is a new job.

## Verification

- [x] Both new scripts confirmed present in Studio (`script_grep` → `ServerScriptService.World.Generators`, `…World.GeneratorServer`)
- [x] Damage verified through the REAL remotes (`SwordSwing` / `FireWeapon` fired from the client, server-side validation intact) — not by writing `HP` directly
- [x] `sourcemap.json` regenerated and KEPT this time: two new script files belong in it
- [x] Play session stopped; Studio left in Edit
- [x] The AssetLibrary template was checked untagged and unwired after the spawn test
- [ ] **Independent reviewer agent NOT run** — GROUND-RULES 8 asks for one, but this session is
      instructed not to call the Agent tool unless the user asks. Recorded, not skipped quietly.

## Notes for whoever picks this up next

- **A fourth generator needs no code**: place a copy named `Generator4` anywhere in Workspace, or call
  `Generators.spawn(cframe, parent, scale)`, or just tag an existing model `Generator`.
- **Do not rename a generator** to something not starting with `Generator` — it silently un-wires
  (ASSETS.md §3.7 now carries that warning).
- **Consequences are the open half.** `Generators.onDisabled(fn)` fires with the model, and
  `Workspace.GeneratorsDisabled` counts them, so wiring the bunker doors / base power / an objective to
  "all three down" needs nothing changed in this module.
- One thing worth knowing that this job did not touch: **foliage blocks bullets**. A first firing test
  did zero damage because a fern leaf sat 0.5 studs in front of the shooter's root and ate the ray. That
  is pre-existing behaviour for every gun in the game, not a generator problem — but it is a real
  gameplay consideration for a prop standing in tall grass.
