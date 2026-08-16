# Job #084 — open follow-ups

Raised during the 2026-08-16 playtests. ✅ = done in this job · ⬜ = not built.

> **Dropped 2026-08-16 at the user's call:** *deposit from the pier*. Not wanted — deposits stay a
> boat-side action. Do not re-raise it from the playtest notes.

---

## ⬜ 1. 🔴 Drop what you are carrying, where you stand

**Reported:** *"we need to be able drop if you something holding, then it drops where you stand."*

**Why it is urgent, not cosmetic.** Carrying sets `Busy = true`, which disables the gun AND the axe.
Combined with the full-cargo case below, a player can reach a state with **no way out**: the deck is
full so `Deposit` refuses, and there is no drop — so they are stuck hauling a crate they cannot deposit,
cannot fight with, and cannot put down, until they die. There is currently **no code path anywhere that
clears `Carrying` except a successful deposit** (`ExcursionServer`).

**Design to settle before building:**
- **Input** — a `ProximityPrompt` competes with Deposit and the loot prompts when they overlap. A
  keybind (G) plus a HUD hint is probably cleaner, but it needs a mobile equivalent — this game is
  mobile-first, so a button on the carry chip may be the real answer.
- **What lands** — does it drop as a re-lootable crate (a new `LootPrompt` object, so nothing is
  destroyed), or does it just vanish? Re-lootable is the honest choice; the crate model already exists.
- **Where** — "where you stand" per the report. Needs a ground raycast so it does not land inside
  terrain, and must be safe on the moving boat deck (weld it or it slides off — see the drifting-item
  bug below, same class of problem).

**Must clear all three:** `carrying[player]`, `player.Busy`, `char.Carrying` — and call
`refreshDeposit()`.

---

## ⬜ 2. 🔴 The held weapon / torch drifts off the boat while it moves

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
in the DataModel; here it is parented to a part not yet in the world. The held item is otherwise a free
physics body (`Anchored = false`, `Massless = true`) whose only tie to the hand IS that weld — so if the
bind is weak or missed it keeps its own momentum and lags behind a moving boat. Matches the report: fine
on land, drifts at speed.

**Fix direction (verify, don't assume):**
- Parent the part FIRST, then create the weld.
- If it still drifts, the weld binds but is soft in the boat's moving frame → use a `Motor6D` to the
  hand (the joint type the R15 rig itself uses).
- ⚠️ Check network ownership: the character is client-owned, and a server-created loose part beside it
  can end up server-owned, which looks exactly like this lag.

Affects the gun **and** the torch — one code path builds both.

---

## ⬜ 3. 🟡 Bandages have no world source

Only sources are the 3 you start with (`PlayerCombat:17`) and 50 Salvage each at the village trading
post. They never drop from loot crates, camps or enemies. Making them findable is a change to
`ExcursionServer`'s loot tables — not started.

---

## ⬜ 4. 🟢 Docs debt — 7 Jungle jobs built with no `final-summary.md`

072, 076, 078, 080, 081, 082, 083. All verified built in code; only the write-up is missing.
(080 is marked as absorbed into this job.)

---

## ⬜ 5. 🟡 "Deposited X" message, visible to every player

**Reported:** *"we need message like deposited x, and all players must see it."*

**Reuse the existing broadcast, not a new one.** `ReplicatedStorage.Announce` is already a server→all
RemoteEvent consumed by `ZoneBanner.local.luau`, fired by `ZoneServer` with:

```lua
announce:FireAllClients({ title = ..., subtitle = ..., color = ..., icon = ..., sound = ... })
```

⚠️ **Do not reuse `ZoneBanner` verbatim.** It is a large centre-screen banner with a HOLD, tuned for
rare beats — zone crossings, nightfall. A deposit happens many times per landing; that banner firing
each time would be obtrusive and would stomp real zone announcements. What is wanted is a small stacking
toast / feed line. Reuse the *shape* (one `FireAllClients` payload, `Components.iconId` for the icon
vocabulary, `Theme` colours) and give it its own lightweight client.

Should say who did it as well as what, since the point is crew awareness — e.g. *"Janis deposited
1 Gasoline · 4/25"*. The running total is already on the boat attributes.

---

## ✅ 6. Deposit silently did nothing — FIXED (first diagnosis was WRONG)

**Reported:** *"i sometimes deposit and nothing happens."*

⚠️ **I first blamed a full cargo deck and was wrong** — the user challenged it, and the live boat read
`Gasoline=0 Metal=0 Ammo=3, CargoMax=25`. Nowhere near full. Recorded because the wrong answer was
plausible and cost a round trip: the bare `return` on the full-cargo branch *looked* like the culprit
without anyone checking whether that branch could even be reached.

**The real cause, measured live.** The prompt hangs off `hull`, so it is anchored at the boat's CENTRE
with `MaxActivationDistance = 16`. But the boat is much bigger than the hull part:

| Measured | Value |
|---|---|
| `hull.Size` | 14 × 3 × 32 |
| Boat bounding box | 14.7 × 11 × 46 |
| Furthest **collidable** part from hull origin | **23.0 studs** |
| Prompt reach | **16 studs** |

So the outer ~7 studs of walkable deck — bow and stern — sat outside the prompt completely. The
reporting player was at **14.3 studs**, right on the edge. Intermittent for two compounding reasons:
where you stand decides whether it responds at all, and with a 0.5 s hold, one step mid-hold crosses
the boundary and cancels silently.

**Fixed:** reach raised to 26 (covers the measured 23 with margin for deck roll).

Kept as well, since it is a correct guard even though it was not the bug: the prompt now reads
**"Cargo FULL"** when the deck really is full, refreshing on `Gasoline`/`Metal`/`Ammo`/`CargoMax`.

## ✅ 6b. Dying while carrying disarmed you for the rest of the run — FIXED

Found while investigating the above. **Nothing cleared `carrying` or `Busy` except a successful
deposit** — the file had no `CharacterAdded`/`CharacterRemoving`/`PlayerRemoving` handler at all. On
death: the carried model died with the character, but `carrying[player]` kept pointing at the destroyed
instance (still truthy in Luau, so the "already carrying" guard blocked every future pickup), and
`Busy` is a PLAYER attribute so it survived respawn — leaving the new character permanently unable to
shoot or swing, "HANDS FULL" showing, and no crate to explain it.

Now cleared on character removal, character add, and player removal.

⚠️ Neither fix unsticks a **full** deck — that still needs the drop action in item 1.

## ✅ 7. Damage numbers were invisible — FIXED

**Reported:** *"decals is not flying when i hit or i am hit."*

Not a logic bug — the pipeline was working the whole time. Read live from the running client: 19 of 20
pooled parts had moved to real hit positions with real damage values in their labels (`8, 15, 18…`).

The cause was my own design call: `AlwaysOnTop = false` with **no** `StudsOffset`, on a billboard that
spawns at the *exact impact point* — i.e. inside the body of whatever you just hit, so it z-failed every
time. Now `AlwaysOnTop = true` with a 2.5-stud lift, a larger 110×40 box, and brighter world-space
colours (`Theme.color.green` is a dark olive tuned for flat UI behind a scrim; it read as mud over
sunlit water).

## ✅ 8. Campfire heal rate lowered to 2.5 HP/s

Shipped at 4.0, which **out-healed the boat's Medic station** (3 HP/s, `RoleServer:17`, Job 057) while
also working solo and ashore — making the dedicated Medic role pointless. Now 2.5, so the station stays
the best heal in the game and the fire is the off-boat fallback. Contested rate unchanged at 1.0.

## ✅ 9. "HANDS FULL" chip overlapped the health bar — FIXED

Moved from y=0.855 to y=0.797. Confirmed clear in a playtest screenshot.
