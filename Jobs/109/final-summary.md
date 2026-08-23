# Final Summary — Job #109

**Project**: `roblox.jungle`
**Completed**: 2026-08-23 21:36:38
**Status**: ✅ Completed

## What was implemented

Four items from playtest feedback on Job #108. All four verified in Play.

1) THE TWO STRANGE BLOCKS - MY DEFECT, REMOVED
They were the EntryStep treads Job #108 built. Every Bahay Kubo ALREADY has its own staircase at its entrance; #108 never checked, measured the widest CLEAR ARC instead, called it the door, and bolted treads on beside the real steps. Deleted, and nothing replaces them - the huts are enterable on their own stairs.
The bearing is corrected too, and that half mattered on its own: the widest arc and the actual staircase are 152 degrees apart on BahayKubo5 (312 vs 160), so that hut was being turned with its steps facing away from the approach. CampDefs.VILLAGE.door is now .entrance and carries measured STAIR bearings: Kubo1 212, Kubo2 208, Kubo5 160, biggest single step 0.87/1.00/1.00 - all inside the ledge a Humanoid climbs without jumping.
The lesson is not 'check for stairs'. It is that '#108 measured everything' was not true of the one claim the job was built on: 'the model cannot do this' was an assumption dressed as a measurement. Recorded in the code, in ASSETS.md and in the shared registry so the next person placing these does not add a ramp either.

2) REWARD MESSAGES
New ServerScriptService/Economy/RewardFeed.luau + StarterPlayerScripts/UI/RewardFeed.local.luau. A small stacking feed directly UNDER the currency chips, top-right, so the message sits beside the counter it explains. Fires on: every salvage payout (loot crates, hut stashes, yard crates, weapon and ammo crates - all funnel through awardSalvage, so one call covers them), the gold nugget (two lines: the gold and the salvage), the picked-up resource BY NAME, weapon and ammo grants, land kills, and objectives.
NOT on the distance drip. That was the design decision: a client watcher on the Salvage attribute would have been fewer lines and caught everything automatically, but the drip pays 1 salvage per 60 studs for the whole 18000-stud run, so a watcher toasts every few seconds forever - and a bare delta cannot say Gasoline.

3) THE VILLAGE IS DRESSED
CampDefs.VILLAGE.dressing - 5-9 rocks/logs/bushes/ferns/palms per hut in a band of 1.25-2.6 hut half-diagonals. Rocks and logs collide (cover), plants do not (no invisible-wall mazes). A hard 34-degree keep-out wedge around the entrance so item 1 is not undone by a boulder on the steps. Plus CampDefs.VILLAGE.yardLoot - 3-5 searchable barrels outdoors among the clutter at 12-22 salvage, below the 25-40 of an interior stash, because what you can see from the path should pay less than what you went inside for.

4) HUT AMBUSHERS
Two bandits per landing site, in two randomly chosen huts, standing on the floor and waiting. Sight cut to 24 studs from the def's 95 - at 95 an ambusher walks out to meet you before you reach the village, which is the opposite of waiting. Each is its own camp for alert and chase-slot purposes, so shooting one does not wake a garrison 200 studs away, and none is registered in garrisons, so none respawns.
Guards are seated by groundAt, which only sees terrain, so a bandit on a 3.5-stud-high floor would be re-seated onto the dirt between the stilts. GuardState gains a perch. Two things about it are load-bearing and both were found by testing, not by reading: it must SET seatY and fall through rather than return (an early return skips the bite, and the ambusher stands there politely declining to attack); and the release test is a RAYCAST FOR FLOORBOARDS UNDERFOOT, not a radius - a flat 14-stud radius was tried and measured, and the bandit committed, walked 6.8 studs out of its own doorway and was still 5.2 studs above the ground. No radius describes a 24x14 floor.

ALSO: the footprint fix from #108 stands; CampLayout still reads CampDefs.FOOTPRINT.

VERIFIED IN PLAY (fresh server, landing site 1)
- 0 EntryStep parts anywhere in the site.
- 7 huts, 3 yard crates, 63 dressing props standing within 55 studs of a hut, 2 hut bandits.
- WALKED IN on the hut's own stairs with Jump never pressed: feet 17.0 -> 20.20 (the floor). Verified at the placed stair bearing; the hut's own steps carry the player up.
- Yard crate looted: salvage +12, rendered row '+12 SALVAGE'. Interior stash +30. Camp resource crate +40 and Carrying=Gasoline.
- Land kill: remote delivered salvage|Salvage|6, rendered row '+6 SALVAGE'. The double-payment guard still holds (a repeat call on the same corpse paid nothing).
- Ambusher: held its post with the player 45 studs away for 6s (moved 0.00 studs); with the player standing on the floor beside it, player HP 100 -> 66.8. Never floated - sampled every 0.4s for 12s while it committed, and it was over its own floorboards at every sample.
- Analyzer clean (luau-lsp with Roblox definitions) across all seven Luau files.
- Play stopped, scriptable camera released, probe folder removed, nothing left in Edit.

KNOWN LIMITS, both honest and neither new
- The huts' stairs are narrow, so a badly aligned run at a hut can miss them and walk into the wall instead. Measured: entering works reliably within roughly +/-10 degrees of the stair line. A player steering themselves sees the steps; this only bit an automated test aiming at the hut centre.
- PathfindingService will not route up those stairs, so an ambusher that commits walks to the floor edge nearest the player rather than descending. It fights properly once the player is on the floor, which is the ambush that was asked for. Direct steering (not pathfinding) is the existing, deliberate movement model for every guard in this game.

TEST-HARNESS TRAPS THAT COST TIME HERE, recorded so they do not cost it twice
- execute_luau client and server are separate contexts reached by separate MCP round trips: a server task.delay(3) fires before the client listener connects, which reads exactly like a broken RemoteEvent. Use ~20s.
- StreamingEnabled is on. A crate the server can see may not exist on the client, and InputHoldBegin on an unstreamed prompt silently does nothing.
- A ModuleScript edited after Play started keeps its CACHED body even though .Source shows the new text. Restart Play before concluding a module change did not work.
- Damage lands on a character HP ATTRIBUTE, not Humanoid.Health. Watching Humanoid.Health reports every enemy as passive.

### ✅ Auto-synced files

- `sync/ServerScriptService/World/CampDefs.luau`
- `sync/ServerScriptService/World/VillageLayout.luau`
- `sync/ServerScriptService/Excursion/ExcursionServer.server.luau`
- `sync/ServerScriptService/Economy/RewardFeed.luau`
- `sync/ServerScriptService/Economy/KillReward.luau`
- `sync/ServerScriptService/Progression/ObjectiveServer.server.luau`
- `sync/StarterPlayer/StarterPlayerScripts/UI/RewardFeed.local.luau`
- `ASSETS.md`

### ⚠️ Manual Studio copy required

- _none_

## Proof it works better - MANDATORY (GROUND-RULES 7)

Evidence, not assertion. A claim here without data behind it means the job is not done.

| | |
|---|---|
**Before** | _screenshot / measurement / log_ |
**After** | _same camera, same state_ |
**What failure would have looked like** | _TODO_ |

- [ ] Captured in **PLAY**, not the editor
- [ ] Same camera and same game state in both
- [ ] Numbers where numbers are possible, not only screenshots

## Verification

- [ ] All mandatory gates in the implementation plan are ticked
- [ ] Independent reviewer agent run, and its finding recorded
- [ ] _TODO: anything else confirmed working_

---

## Follow-up during playtest — the badge layout, and full reward coverage

**Reported:** *"that message is weird and thin"*, with a screenshot.

Two layout mistakes, both mine:

1. **It stretched.** The row was `Size = fromScale(1, ROW_H * 0.86)` inside a 0.30-wide holder, so every
   message — three words or thirty — rendered as a **576 × 39 px strip** with a speck of an icon at the
   far left. A message box has to be as wide as its message. Rebuilt to size exactly the way
   `Components.chip` does (the currency pills it sits under): fixed pixel height, `AutomaticSize.X`,
   content-hugging. Measured after: 108 / 123 / 144 / 146 / 185 / 197 px wide × 46 tall, one width per
   message.
   ⚠️ `TextScaled` must stay **false** for this — `Components.applyText` turns it on, and a scaled label
   has no meaningful `TextBounds`, so `AutomaticSize` collapses. That is why the first cut could not hug.

2. **It landed on the objectives card.** Placed at y 0.088 to sit "just under the currency chips" — which
   is the one slot in the top-right already taken. Measured live: chips own y 25–79, `ObjectiveHud` owns
   119–213 (up to 335 expanded). Moved to bottom-right, stacking upward above `CrewToast`.
   ⚠️ And the clearance is MEASURED, not derived. On paper `CrewToast` anchors at 0.80 with three 0.045
   rows, so its top edge is 0.665 and 0.655 clears it. Measured at 1978×1313 it actually spans y
   **835–1004** — a top edge of 0.636, moved by the ScreenGui safe-area inset — so 0.655 sat *inside* it.
   Final: 0.60 desktop / 0.66 touch, verified at **82 px** of clearance.

**Coverage gaps closed at the same time**, after enumerating every grant site rather than assuming the
first pass was complete:

- Objective **gold** (`ObjectiveServer`) — salvage was wired, gold was silent.
- **Every shop purchase** (`SalvageServer.applyItem`) — bandage, gun, handheld ammo, fuel, turret ammo,
  repair. The ammo row especially: it lands on a Player attribute the gun reads, with nothing on screen
  to say it arrived.

Verified in Play, in one client call so there is no round-trip race: four real purchases through the real
`DockShop` handler returned `ok=true` and produced `+1 BANDAGE`, `+18 PISTOL AMMO`, `+1 GASOLINE`,
`+1 METAL` on screen.

**Still deliberately silent:** the distance drip (1 salvage / 60 studs, would toast forever), admin grants,
the end-of-run gold payout (the results screen already reports it), and Robux purchases (Roblox shows its
own receipt).

**Not verified:** the touch layout. `BOTTOM = 0.66` and `SLOTS = 2` are computed, not measured on a phone
viewport — worth a pass in the Studio Device Emulator before shipping.

### Mobile verification (Studio Device Emulator, user-enabled)

Measured, not reasoned about — and then looked at, per the `mobile` skill §1 and §4b.

**Device:** `TouchEnabled = true`, `ViewportSize` **666 x 374**, usable canvas **666 x 316**
(`CoreUISafeInsets`), GuiInset 58 px top. Confirms the skill's §2 warning applies here: a pixel value is
~2.3x larger relative to this canvas than a desktop test suggests.

**The feed as rendered:** x 492..656, y 111..209 — **25% of canvas width, 31% of height** at its
transient 3-row peak (two rows steady state; the third is a row mid-fade). Rows 124–164 x 30 px,
`TextSize = 14`, and `TextFits = true` on the longest label in the game (`+6 SHOTGUN AMMO`), so nothing
wraps or clips.

**Diffed against every `TouchGui` child, visible or not** (§3 — including `JumpButton`, which the first
probe missed because it was not yet visible):

| Roblox control | Rect | Verdict |
|---|---|---|
| `DynamicThumbstickFrame` | x -100..266, y 105..416 | clear (feed starts at x 492) |
| `ThumbstickStart` / `End` | x 29..103 / 48..84 | clear |
| `JumpButton` | x 571..641, y 226..296 | clear — feed bottom is 209, **17 px above it** |

And against our own HUD: `CrewToast` sits at y 224..253, so the feed clears it by 15 px. The only
"overlaps" the checker reported are full-screen layers — `TouchControlFrame`, `IntroFadeGui.Black`,
`HealthVignette.Vignette` — which are containers, not competing UI.

**Screenshot read:** badges sit mid-right, legible, clear of both thumb zones, covering nothing. The
bottom-left movement quadrant and the bottom-right jump button are untouched, and the hotbar and vitals
column are unaffected.

Non-interactive by construction (`Active = false`, Frames not GuiButtons), so they absorb no taps and the
58 px tap-target floor does not apply.

⚠️ Not testable at a desk, per §7: multi-touch. Nothing in this feature responds to touch, so there is
nothing multi-touch to defer.
