# Implementation Plan — Job #115

**Project**: `roblox.jungle`
**Created**: 2026-08-25 00:40:54
**Status**: Planning (awaiting go-ahead)

## Analysis

The whole feature can hang off ONE attribute. MeleeServer, WeaponServer and GunServer already do the same three things — find a Model carrying a known TAG, subtract from its HP attribute, and move on — so making a generator destructible is one tag added to each of those three target lists, and every reaction (zap, burning particles, health bar, death) is a reaction to HP CHANGING. That means no new damage code, no new remote, no per-frame loop, and the damage numbers stay whatever the weapons already deal. 'Show the bar when approached' is BillboardGui.MaxDistance, which culls per-viewer on the client for free; a server-side proximity loop would have had to pick one answer for the whole crew. Measured first: Generator1/2 are 8.96x8x5.31 single-MeshPart models with NO PrimaryPart, Generator3 is the same asset at half scale up a tower at y 63.5 — so every offset and particle size is derived from GetBoundingBox, never hard-coded. Sound lengths were measured too (eletricity_going 3.94 s, generator_dead 1.10 s), which is what decided the looped-idle vs restarted-and-cut-at-0.5s split.

## Implementation steps

1. NEW sync/ServerScriptService/World/Generators.luau — the reusable module: attach(model) (idempotent; sets PrimaryPart, HP/MaxHP=150, builds the FX rig, connects the HP watcher, adds the tag last), attachAll(root), spawn(cframe, parent, scale) from ServerStorage.AssetLibrary.Structures.Generator, onDisabled(fn), isAlive, all().
2. Generators.luau FX rig, all scaled off the model's bounds: looped positional hum (0.32, 90-stud InverseTapered tail); a second reused Sound for the hit zap (0.9, PlaybackSpeed 1.15, stopped after 0.5 s via a token so a later hit cannot be cut short by an older timer); blue-white sparkles emitter at Rate 20 falling (Acceleration -6Y, SpreadAngle 180); a red/orange fire-texture emitter at Rate 0 that Emits ~16 on a hit then smoulders at Rate 7 for 1.6 s; a legacy Smoke disabled until death; a PointLight tagged NightLight so LightController owns it.
3. Generators.luau status billboard: BillboardGui on the part, StudsOffsetWorldSpace = bboxY/2 + 2.2, MaxDistance 70 while alive. Track/Fill frames in Theme colours with the same green/yellow/red bands as EnemyHealthBars; a TextLabel that is hidden while alive and shows DISABLED on death, with the bar hidden and MaxDistance widened to 110.
4. Generators.luau death path: stop hum + zap, one-shot generator_dead, sparks off, one last burn flare, smoke on, REMOVE the NightLight tag (or LightController relights a dead generator at dusk), swap the sign, set Disabled, publish Workspace.GeneratorsDisabled, fire the onDisabled listeners.
5. NEW sync/ServerScriptService/World/GeneratorServer.server.luau — boot only: attachAll(Workspace) by the Generator* name prefix, plus CollectionService:GetInstanceAddedSignal('Generator') so anything spawned later is wired by tagging alone. Scans Workspace, never ServerStorage, so the AssetLibrary template is never wired.
6. MeleeServer / WeaponServer / GunServer — add the Generator tag to their existing target lists (a third GetTagged loop in melee, a third HasTag in each gun walk-up). No other change in the combat path.
7. KillReward.luau — a Generator branch before the Category test (a prop has no Category and would be filtered out like a fish): 6 Salvage on the killing blow, guarded by the existing SalvageAwarded marker, announced through RewardFeed.
8. Docs: ASSETS.md section 3.7 gets the generator + generator-audio rows and a do-not-rename warning; the shared registry Assets/registry/audio.md gets both ids with their measured lengths and their two different roles.
9. VERIFY IN PLAY: cold boot prints '3 wired'; melee-kill one (10 x 15 HP) and gun-kill another (8 x 20 HP) reading HP off the server each hit; assert the dead state (hum stopped, sparks off, smoke on, DISABLED shown, NightLight tag gone, GeneratorsDisabled counted, 6 Salvage paid); and exercise the spawn-later path by cloning the library template, tagging it, and checking it wires and cleans up on Destroy.

## Independent review (GROUND-RULES 8)

Every job gets at least one agent, handed the symptom and the repo but NOT my hypothesis - the whole value
is that it is not anchored to my theory. A second agent is mandatory after one failed fix.

- [ ] Agent run, without being told my theory
- **What it said to check first**: _TODO_
- **What came of it**: _TODO_

## What I need from you

- [ ] _TODO: Studio actions, asset IDs, decisions, go-ahead_

## Verification - MANDATORY GATES (GROUND-RULES 7)

None of these may be ticked from an Edit session. Edit does not run LocalScripts and has nothing created at
runtime, so it cannot show a whole class of bug.

- [ ] **Reproduced in PLAY**, at the player's camera angle, BEFORE attempting a fix
- [ ] If this was "works in X, broken in Y": environments diffed FIRST - client scripts and their VFX,
      runtime-created instances, tick-driven systems, place settings
- [ ] Every check below says what a FAILURE would have looked like
- [ ] Before/after from the SAME camera, and the "before" is kept
- [ ] No world fact asserted from a constant - measured instead
- [ ] The fix accounts for the REPORTED symptom, not just for real bugs found on the way

### Checks

- [ ] _TODO: what is checked, and what failure would look like_
