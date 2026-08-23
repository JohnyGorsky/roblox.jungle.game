# Implementation Plan — Job #106

**Project**: `roblox.jungle`
**Place**: GAME (`Last River COOP Game`, PlaceId 138141472932347) — `sync/` tree only. The lobby
(`lobby/sync/`) is NOT touched: it has its own shops and is a separate place.
**Created**: 2026-08-23
**Status**: Planning (awaiting go-ahead)

## Analysis

### Where the camp shop actually lives

`sync/ServerScriptService/Excursion/ExcursionServer.server.luau` builds one **village trading post**
per landing site (`buildTradingPost`, line 1545; called at line 1789). Everything below is in that
one file.

**The only shop trigger today** is `ShopPrompt` (line 1579), parented to an *invisible, non-querying*
`Counter` part placed at `pos + approach * 10`, with `MaxActivationDistance = 14`.

**Why nobody finds it — measured, not assumed.** `CampDefs.MODEL.post` is `BahayKubo7`. Read from the
live `ServerStorage.AssetLibrary` in this place:

| model | bounding box (studs) | parts |
|---|---|---|
| **BahayKubo7** (trading post) | **40.2 × 25.8 × 50.2** | 96 |

So the half-extent along the approach axis is **20–25 studs**, and the prompt anchor sits at **10**.
The counter is *inside the stilt house's own footprint* — the code already says so at line 1553-1556
and again at line 1565-1569 ("the first version of this put the chest under the stilt house's deck
where nobody can see it"). At 14 studs of reach the prompt therefore only lights up when you are
under/beside the house. That is the reported symptom: *"shop trigger is somewhere inside home and
noone knows"*.

**The sign is right there and carries nothing.** `buildShopSign` (line 1415) builds a physical
WoodPlanks board reading **"TRADING POST"** on two posts, at `pos + approach * 16 + lateral * 7`,
board centre `ground + 6.2`. It is pure scenery — no prompt, no attribute. That is the sign in the
report.

**The same bug was already fixed elsewhere and never back-ported.** The crash-site Robux kiosk
(`sync/ServerScriptService/Economy/StartShopServer.server.luau:91-95`) sizes its reach from the
model's bounding box:

```lua
local reach = 20
if station:IsA("Model") then
    local _, sz = station:GetBoundingBox()
    reach = math.max(math.max(sz.X, sz.Z) / 2 + 10, 20)
end
```

The camp trading post never got that treatment.

### Will two prompts fight each other?

No — measured in this place rather than recalled: `ProximityPrompt.Exclusivity` defaults to
`Enum.ProximityPromptExclusivity.OnePerButton`, and both prompts use the default `KeyCode.E`. Only
the nearest E-prompt renders. Standing at the sign shows the sign's prompt; standing at the counter
shows the counter's.

### Open risk to check in Play (not a change yet)

`approach * 16` may put **the sign itself inside the 40 × 50 footprint** — under the stilt house.
The gold chest 8 lines below steps out to `half-extent + 7 ≈ 26` for exactly this reason. If the Play
screenshot shows the sign standing under/behind the house, the sign gets the same support-function
standoff. I will not move it on speculation — I will look first.

### Client side

None. `OpenShop` is fired with **no arguments** (`DockShopClient.local.luau:212`), so a second trigger
needs no client change and no new remote.

## Implementation steps

1. `buildShopSign` — return the `board` Part it creates (currently returns nothing). No other change
   to the sign's geometry or text.
2. `buildTradingPost` — extract the prompt construction into a local
   `shopPrompt(host: BasePart, reach: number): ProximityPrompt` so the two triggers cannot drift
   apart (same `ActionText`/`ObjectText`/`HoldDuration`, both firing `openShop:FireClient(player)`).
3. Counter prompt: replace the hardcoded `MaxActivationDistance = 14` with a reach measured from
   `postModel:GetBoundingBox()`, using the same rule `StartShopServer` already uses. The building's
   own extents are already read a few lines above for the gold-chest standoff, so this is one more
   use of a measurement that is in hand.
4. Sign prompt: attach a second prompt to the returned board, named `SignShopPrompt`, reach ~12 so it
   belongs to the sign and not to the whole clearing.
5. Add a short header note under the existing Job #077 comment block recording *why* there are two
   triggers, so the next person does not "tidy" one away.

**Files touched: 1** — `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` (auto-synced
service per `.jobconfig.json`).

## Independent review (GROUND-RULES 8)

Every job gets at least one agent, handed the symptom and the repo but NOT my hypothesis.

⚠️ **Blocked on a rule conflict** — this session was started with an explicit instruction not to call
the Agent tool unless you ask for it, which contradicts GROUND-RULES §8. Flagged to you rather than
silently picking a side.

- [ ] Agent run, without being told my theory
- **What it said to check first**: _pending your call_
- **What came of it**: _pending_

## What I need from you

- [ ] Go-ahead on the plan.
- [ ] Decision on the §8 agent reviewer (see above).
- [ ] Studio stays open on **Last River COOP Game** so I can Play-test. I will start and stop the Play
      session myself and will not leave one running.

## Verification - MANDATORY GATES (GROUND-RULES 7)

None of these may be ticked from an Edit session.

- [ ] **Reproduced in PLAY first**: Play → admin `tpFirstCamp` (`ServerStorage.ForceFirstCamp`) →
      walk to the sign → **failure looks like**: the "Trade" bubble appears at the sign even before
      my change (which would mean I am in the wrong subsystem entirely and the plan is wrong).
- [ ] After the change, at the sign: prompt reads `Trade / Trading Post`, pressing E opens the
      DockShop panel. **Failure looks like**: no bubble, or a bubble that does nothing, or the panel
      opening empty.
- [ ] Walk a full circle around the hut at ~15-20 studs. **Failure looks like**: the prompt dropping
      out on the back side (reach not actually widened).
- [ ] Only ONE bubble on screen at the sign. **Failure looks like**: two overlapping "Trade" prompts,
      which would mean `OnePerButton` is not doing what I measured.
- [ ] Before/after screenshots from the **same player camera** at the sign; the "before" is kept.
- [ ] Sign standoff judged from the Play screenshot, not from the numbers — is the board clear of the
      house, or under it?
- [ ] The fix accounts for the REPORTED symptom (cannot find the shop), not just for real bugs found
      on the way.
