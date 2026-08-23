# Final Summary — Job #106

**Project**: `roblox.jungle` · **Place**: GAME (`Last River COOP Game`, 138141472932347)
**Completed**: 2026-08-23
**Status**: ✅ Implemented and verified in Play.

## What was implemented

The village trading post's shop trigger moved onto the physical **TRADING POST** sign board, and its
reach is now measured from the building instead of hardcoded (14 → 35.1 studs).

### ✅ Auto-synced files

- `sync/ServerScriptService/Excursion/ExcursionServer.server.luau`

### ⚠️ Manual Studio copy required

- _none_

## What was wrong

The shop had exactly one trigger: an invisible `Counter` part at `approach * 10` from the building
centre, `MaxActivationDistance = 14`.

`BahayKubo7` measures **40.2 × 25.8 × 50.2** studs (read from the live `ServerStorage.AssetLibrary`,
not quoted from a comment), so its half-extent along the approach is 20–25. The counter therefore sat
**under the stilt house's deck**, and 14 studs of reach did not come out from under it. The physical
sign built by `buildShopSign` — the thing players walk up to — carried nothing.

## Proof it works better — MANDATORY (GROUND-RULES §7)

All in **Play**, at the first landing, reached via `ServerStorage.ForceFirstCamp` after nudging the
boat downstream so `RiverBootstrap` had generated that stretch.

| | |
|---|---|
| **Before** | At the sign (9.6 from sign, 16.6 from counter, reach 14): **no prompt shown at all**. At the counter under the deck (5.1): `ShopPrompt on Counter`. |
| **After** | Walked in from the water side, camera over the shoulder: prompt UI 0 at 35.9 studs → **1 at 28.7** → stays 1 at 18.9, 9.3, 6.5. Then parked 9.2 studs from the sign, `keyDown E → 900 ms → keyUp`: **`OpenShop` fired once and the `DockShop` panel opened.** |
| **What failure would have looked like** | Prompt UI staying 0 across the whole walk-in; or E doing nothing; or the panel opening empty. Also: the "before" check could have failed by showing a bubble at the sign already, which would have meant the wrong subsystem. |

- [x] Captured in **PLAY**, not the editor
- [x] Same camera and same game state in the before/after captures
- [x] Numbers where numbers are possible, not only screenshots

## What changed, in code

One file, one function.

1. **`buildShopSign` now returns its board part** (it returned nothing).
2. **The shop prompt moved onto that board.** Same name (`ShopPrompt`), same `ActionText`/`ObjectText`
   /`HoldDuration`, same `openShop:FireClient(player)`.
3. **Reach is measured, not hardcoded.** `math.max(math.max(ext.X, ext.Z) / 2 + 10, 20)` — the rule
   `StartShopServer` has used for the crash-site Robux kiosk since Job 074. **35.1** studs here. The
   building's bounding box was already being read for the gold-chest standoff; it is now read once
   into `postExt` and shared.
4. **The `Counter` part is left in place but inert.** Grepped both trees — nothing outside this
   function reads it. Deleting an instance from every generated village is a content change this job
   was not asked to make, so it is logged as **todo 0060** instead.
5. A header block records the measurements and the dead ends below.

No client change: `OpenShop` is fired with no arguments. `tools/luau-analyze.sh` clean — and the
analyzer was proved able to fail first, by feeding it a deliberate type error.

## Two approaches tried and reverted

- **Widening the counter's reach alone.** Makes the shop usable at the sign but leaves the bubble
  adorned to a part under the deck, which is not what a player needs to find it.
- **Two prompts (counter + sign).** `Exclusivity` defaults to `OnePerButton` — verified by reading a
  fresh `ProximityPrompt`'s default in this place rather than from memory — and both would use
  `KeyCode.E`, so only one ever renders, and which one is not simply the nearest. One deterministic
  trigger beats two that compete.

## Three measurement traps hit on the way

Recorded because each produced a wrong answer first.

1. **`screen_capture` does not render `ProximityPrompt` billboards.** Established by control: standing
   5.7 studs from a `LootPrompt` with `promptUI = 1`, the capture shows no bubble either. Any "no
   bubble in the screenshot" reasoning about prompts is worthless — including an earlier conclusion in
   this job that the counter's bubble was occluded by the house, which the capture could not have
   shown either way. Use `#PlayerGui.ProximityPrompts:GetChildren()`, or press the key.
2. **Teleporting the character leaves the camera frozen at an arbitrary yaw**, which made a ring test
   report dead directions that do not exist. Walking the character in with `Humanoid:MoveTo` and a
   camera behind it gave a clean, monotone result.
3. **The camp garrison kills a parked test character**, and a stale `HumanoidRootPart` reference to a
   dead character still reports plausible positions — so samples silently became fiction. Re-fetch the
   character each sample and assert it is alive, or clear the guards and set `Health = math.huge`.

Also confirmed against a control prompt built in the open on the same pad: reach 35 genuinely displays
from 33 studs, so the value is honoured by the engine and not clamped.

## Verification

- [x] All mandatory gates in the implementation plan are ticked or explicitly replaced, with reasons
- [ ] **Independent reviewer agent — SKIPPED**, at your explicit direction, because this session was
      started with an instruction not to spawn agents unless asked. GROUND-RULES §8 not met; recorded
      here rather than left implicit.
- [x] Play session started and stopped by Claude; Edit camera left `Custom`; no test state left behind
