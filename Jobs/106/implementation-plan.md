# Implementation Plan — Job #106

**Project**: `roblox.jungle`
**Place**: GAME (`Last River COOP Game`, PlaceId 138141472932347) — `sync/` tree only. The lobby
(`lobby/sync/`) is NOT touched: it has its own shops and is a separate place.
**Created**: 2026-08-23
**Status**: DONE - implemented and verified in Play. Final shape differs from the plan below; see final-summary.md.

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

- [x] SKIPPED at the user's explicit direction (session instruction forbids spawning agents unless asked)
- **What it said to check first**: n/a - not run
- **What came of it**: n/a - not run

## What I need from you

- [x] Go-ahead on the plan.
- [x] Decision on the §8 agent reviewer: skip.
- [x] Studio stays open on **Last River COOP Game** so I can Play-test. I will start and stop the Play
      session myself and will not leave one running.

## Verification - MANDATORY GATES (GROUND-RULES 7)

None of these was ticked from an Edit session. Full detail in `final-summary.md`.

- [x] **Reproduced in PLAY first.** At the sign, before any change: dCounter 16.6 vs reach 14 -> no
      prompt shown. Could have failed by showing a bubble already; it did not.
- [x] **After the change, at the sign: E opens the shop.** Walked in, parked 9.2 studs out, sent
      keyDown E / 900 ms / keyUp -> `OpenShop` fired once and the `DockShop` panel opened.
- [x] **Reach actually widened.** Control prompt at reach 35 on the same pad displays from 33 studs,
      and the real prompt does too along the swept axis - so 35.1 is honoured, not clamped.
- [~] **"Only one bubble on screen"** - REPLACED. This gate assumed screenshots can show prompts. They
      cannot (see below), and the two-prompt design was dropped anyway. There is now exactly one
      `ShopPrompt` in the camp, confirmed by enumerating every `ProximityPrompt` under `LandingSite`.
- [~] **Before/after from the same camera** - kept, but the pair does NOT show the prompt, because
      `screen_capture` does not render `ProximityPrompt` billboards. Proved by control: 5.7 studs from
      a `LootPrompt` with promptUI = 1, the capture shows no bubble either. The captures are still
      valid evidence for the SIGN's placement and the scene; prompt state came from
      `#PlayerGui.ProximityPrompts:GetChildren()` and from pressing the key.
- [x] **Sign standoff judged from the Play screenshot.** The board reads clearly in front of the stilt
      house from the approach. Left where it is - no change made on speculation.
- [x] **The fix accounts for the REPORTED symptom.** The complaint was that the trigger is hidden
      inside the house; the trigger is now on the sign and opens the shop from there.

### Corrections to this plan, made from Play evidence

1. The plan's "two prompts cannot fight - only the nearest renders" was wrong. `OnePerButton` is
   right, but the survivor is not simply the nearest, so two prompts were dropped for one on the sign.
2. Mid-job I concluded the counter's bubble was "occluded by the house" from a screenshot. That
   inference was invalid - captures never show prompts. The single-prompt design still stands on
   determinism and on the prompt being adorned to the visible landmark, not on that claim.
