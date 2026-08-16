# Job #084 — open follow-ups (not built)

Raised during the 2026-08-16 playtests, recorded here rather than built. Nothing below is done.

---

## 1. 🔴 The held weapon / torch drifts off the boat while it moves

**Reported:** *"weapon and lamp flys away from boat when move, they are like drifting."*

**Where:** `ServerStorage/Inventory/InventoryService.luau:237-241`

```lua
local weld = Instance.new("WeldConstraint")
weld.Part0 = hand
weld.Part1 = part
weld.Parent = part      -- ⚠️ part.Parent is still nil here
part.Parent = char      -- ← only enters the DataModel on the NEXT line
```

**Likely cause — constraint ordering.** A `WeldConstraint` binds `Part0`/`Part1` when it becomes active
in the DataModel. Here it is parented to a part that is not yet in the world, which is the classic
Roblox ordering gotcha. The held item is otherwise a free physics body (`Anchored = false`,
`Massless = true`) whose only tie to the hand IS that weld — so if the bind is weak or missed, the part
keeps its own momentum and lags behind a moving boat. That matches the report exactly: fine standing on
land, drifts away at speed.

**Fix direction (verify, don't assume):**
- Parent the part FIRST, then create the weld — the safe order.
- If it still drifts, the weld is binding but soft under the boat's moving reference frame; a `Motor6D`
  to the hand (the same joint type the R15 rig itself uses) is the rigid alternative.
- ⚠️ Check network ownership too: the character is client-owned, and a server-created loose part next
  to it can end up owned by the server, which shows as exactly this lag.

**Affects both the gun and the torch** — same code path builds both (`Light` kind included).

---

## 2. 🟡 Campfire heal rate vs the Medic station — a balance conflict I introduced

Job #084 shipped campfire healing at **4 HP/s** (clear) / **1 HP/s** (contested).

⚠️ **The boat's Medic station heals the whole crew at 3 HP/s** (`RoleServer:17`, `MEDIC_REGEN`, Job 057)
and requires a crew member to stand at it — costing that player their station.

So the campfire currently **out-heals the dedicated Medic role**, works solo, and costs nothing but
time. That devalues Job 057's whole mechanic.

**Suggested fix:** drop the campfire clear rate to ~**2.0–2.5 HP/s** so the Medic station stays the best
heal in the game and the fire is the ashore fallback. One constant: `CampDefs.HEAL.rate`.

---

## 3. 🟡 Bandages still have no world source

Only sources are the 3 you start with (`PlayerCombat:17`) and 50 Salvage each at the village trading
post. They never drop from loot crates, camps or enemies. If bandages should be findable, that is a
change to `ExcursionServer`'s loot tables — not started.

---

## 4. 🟢 Docs debt — 7 Jungle jobs are built but have no `final-summary.md`

072, 076, 078, 080, 081, 082, 083. All verified built in code; only the write-up is missing.
(080 is now marked as absorbed into this job.)
