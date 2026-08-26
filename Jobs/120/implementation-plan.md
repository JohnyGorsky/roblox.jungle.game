# Job #120 — Implementation plan

**Project**: `roblox.jungle` · GAME place (`sync/`) only
**Status**: awaiting agreement

## 1. What was measured in PLAY before planning anything

Reproduced in a live Play session (GROUND-RULES §7 — the editor is not evidence). The run was started
via `ServerStorage.ForceStartRun`, the boat moved to the first river dock at `z = 1600`, and the player
seated in the `DriverSeat` for the real approach camera.

**Before-shot**: `before_pier_approach` — driver's camera, boat abeam the pier. The pier is a bare
wooden quay. There is nothing on it, over it, or near it that mentions tying up.

### Measured geometry of a live river pier (dock @ z=1600)

| Fact | Measured value | Where the code says otherwise |
|---|---|---|
| Pier bounding box | 32.19 × 8.39 × 12.68 | matches `CampDefs.MODEL.dock` comment (62 parts, 32×8×13) ✅ |
| Pier long axis | **along the river tangent** `(0.306, 0, 0.952)` | It is a **quay running along the bank**, not a jetty poking into the river. Half of it overhangs water. |
| **Walkable deck surface** | **Y = 15.08**, flat across the whole deck (7×5 probe grid) | ⚠️ `DockServer.DECK_Y` is **16**. Standing anything on `DECK_Y` floats it **0.92 studs**. |
| Railing posts | top out at **Y = 17.39**, at three outer spots: `(water+6, t+6)`, `(water−6, t−12)`, `(water−6, t+12)` | not documented anywhere — a sign post dropped blind can intersect one |
| Water side | toward `-side` in world **X** (`RiverData` derives `dock.x` with a world-X offset, so world X *is* the bank normal here) | — |
| Deck gaps | a down-ray at some XZ **misses entirely** (between planks) | a single raycast to find the deck is not reliable — must retry/offset |

### Measured state of the thing we are replacing

| | Today | Consequence |
|---|---|---|
| Tie trigger | `ProximityPrompt "Tie Boat"` on a `TieSpot` Attachment on `Deck` (`DockServer:301-311`) | `Deck` is `Transparency = 1` since Job #077 (`DockServer:279`). **The prompt hangs off an invisible part** — a bubble over nothing, at the geometric centre of a 32-stud quay. |
| Prompt reach | `MaxActivationDistance = 18`, `HoldDuration = 0.6` | — |
| Rope dock end | `a1.WorldPosition = pos + (0, 2, 0)` → **Y = 14.0** (`DockServer:388`) | The deck surface is **15.08**. ⚠️ The "visible rope" is currently anchored **1.08 studs inside the pier structure** — it disappears into the planking. |

**So the diagnosis is not "the feature is missing".** The tie flow works and its `ActionText` already says
"Tie Boat". What is missing is a *body* for it: an object in the world that says the pier is for tying up
and that the player can aim at. This job gives the trigger and the rope something physical to live on.

## 2. Decisions already taken (intake wizard, 2026-08-26)

1. **Extract the sign recipe to a shared module.** Approved to edit `ExcursionServer` for this.
2. **Rope ties round the signpost at deck level**, not to the board 6 studs up.

## 3. The change

### 3.1 New — `sync/ServerScriptService/World/WorldSign.luau`

`buildShopSign` (`ExcursionServer:1981-2015`) lifted verbatim into a module, with the caption and the
board name as parameters. Nothing about the recipe changes: 8×3×0.4 `WoodPlanks` board at `+6.2`, two
0.5×7×0.5 `Wood` posts at `±3.4`, both `CanCollide = false`, a `SurfaceGui` on **Front and Back**
(`PixelsPerStud = 50`, `MaxDistance = 320`), `Theme.font.sign` (SpecialElite), `Theme.color.cream` with
`Theme.color.stroke` — i.e. exactly what ships today at every trading post, and what `ASSETS.md` §1.3
records as the game's built sign (`Board` 8×3×0.4 WoodPlanks on two `Post`s).

```
WorldSign.build({
    position, faceTo, parent, ground,   -- same four args buildShopSign takes
    text, boardName,                    -- new: the caption and the board's Name
}) -> board: Part, posts: { Part }
```

Returns the posts as well as the board — DockServer needs a post to tie the rope to; ExcursionServer
ignores the second return.

⚠️ `CanCollide = false` on every sign part is **load-bearing here, not cosmetic**. `DockServer`'s header
records the standing rule that *"physical collision with the boat assembly blows the boat apart"*, which
is why the whole pier below `WATER_Y + PILING_CLEAR` is de-collided. A sign standing on the pier's water
edge is squarely in the hull's path at a sloppy mooring. The recipe is already safe; this note is so it
stays that way.

### 3.2 `ExcursionServer.server.luau` — delegate, change nothing visible

`buildShopSign` becomes a thin wrapper over `WorldSign.build(... text = "TRADING POST", boardName =
"ShopSign")`. Same board name, same size, same position, same `Theme` tokens, so the existing
`ShopPrompt` that parents to the returned board (`ExcursionServer:2245`) is untouched. **Camp signs must
render identically after this change** — verified by diffing a camp sign's properties before/after.

### 3.3 `DockServer.server.luau` — the sign, the prompt, the rope

**(a) Stand the sign on the pier.** In `buildDock`, after `buildPier` has done its final positioning:

- `waterDir = Vector3.new(-dock.side, 0, 0)` — toward the channel.
- Sign at `pos + waterDir * 3`, at the pier's mid-length (`t = 0`), **facing the water**
  (`faceTo = signPos + waterDir * 40`). Board width therefore lies along the tangent, along the 32-stud
  quay, and reads from the river — which is the direction the player arrives from.
- `t = 0, water+3` was chosen **from the probe grid**, not by eye: it is clear of all three railing posts
  (nearest is `(water+6, t+6)`, ~4 studs away) and 3 studs inboard of the water edge.
- **Ground is measured, never `DECK_Y`.** A new `measureSurfaceY(pier, xz)` raycasts down at the sign's
  own XZ, filtered to the pier, keeping the highest `Normal.Y > 0.7` hit above water, and **retries at
  small offsets when it misses a plank gap** (the probe grid proved misses happen). If it cannot find a
  surface at all, the sign is skipped and a `warn` is emitted — never seated on a guess.

**(b) Move the tie trigger onto the sign.** The prompt is created exactly as today but parented to the
sign board instead of the `TieSpot` attachment.

- 🔴 **Exactly ONE prompt.** Job #106 measured this the hard way at the trading post
  (`ExcursionServer:2132-2137`): two prompts on the same default `KeyCode.E` with `Exclusivity =
  OnePerButton` means only one ever renders **and it is not the nearest** — "a trigger that is visible
  half the time is the reported bug, shipped again". The `TieSpot` attachment stays (it is referenced by
  nothing else, and it keeps the geometry note in the header true) but it no longer carries a prompt.
- `MaxActivationDistance` 18 → **24**. Reason, from the measurement: the driver's seat sits ~11 studs
  out and ~6 down from the board when berthed alongside; 18 works for a tidy mooring and fails for a
  sloppy one. 24 covers the width of the boat plus the vertical drop with margin, and still cannot be
  seen from across a 162-stud channel. `HoldDuration` stays 0.6.
- The server-side gate is unchanged: `(hull.Position - pos).Magnitude <= REFUEL_RANGE` (65).

**(c) Run the rope from the sign.** `a1` is parented to the **nearer signpost** (chosen at tie time by
distance to the hull, so the rope never crosses the sign) with `WorldPosition` at that post's base
`+1.0` stud — a mooring line round the foot of the post.

- Everything else about the rope is untouched: `Thickness 0.15`, `Visible`, Brown, and
  `Length = |a0 − a1| + ROPE_SLACK`. The slack rule still holds — `DockServer:64-70` records that the
  rope became **load-bearing** when Job #084 made the hull dynamic, and that slack is what keeps it
  decoration. The hold parks the boat within 0.3 studs, unchanged.
- This also fixes the buried anchor: the dock end moves from Y 14.0 (inside the planking) to ~16.1 (on
  the deck, at the foot of the sign).

### 3.4 Explicitly NOT changed

`Tied` attribute · the `DockMoor` `LinearVelocity` and its centre-of-mass `DockMoorPoint` · `RequestUntie`
· `activeUntie` · `UntieButton.local.luau` · the creak sound · `StagingServer` (spawn dock) · the LOBBY
place. This job moves where the trigger and the rope *hang*; it does not touch what they *do*.

## 4. Open risk to check during the test

**Prompt exclusivity against the camp's shop sign.** Landing docks also get a camp with a
`ShopPrompt` on its own sign, also on `KeyCode.E`, also `OnePerButton`. If the two are ever in range at
once, one of them silently stops rendering — the exact Job #106 failure. To be **measured in Play at a
landing dock**, not reasoned about. If they do overlap, the fix is to separate them (reach or key), and
it is part of this job.

## 5. How this gets verified (and what failure looks like)

Every check below can fail; that is the point (GROUND-RULES §7).

| Check | Passes if | **Fails if** |
|---|---|---|
| Sign is seated on the deck | sign post base Y within 0.15 of the measured deck surface at its XZ | it floats or sinks — the `DECK_Y` trap |
| Sign is legible from the water | driver-camera screenshot from the same camera as `before_pier_approach` shows "TIE BOAT" | text unreadable, faces the jungle, or is behind the railing |
| Sign does not collide | every sign part `CanCollide == false`; boat driven into the pier does not break up | hull loses parts / boat despawns |
| Prompt is on the sign and unique | exactly one `ProximityPrompt` under the `Dock` model, parented to the board | zero, or two (the Job #106 bug) |
| Prompt actually renders | `PlayerGui.ProximityPrompts` has a live entry while berthed | empty — ⚠️ screenshots **cannot** show prompt bubbles, so this must be read from the GUI tree, not a picture |
| Tie works from the sign | pressing it sets `Boat.Tied = true` and creates `DockMoor` on the hull | attribute stays false |
| Rope is visible and starts at the sign | `RopeConstraint.Visible`, `a1` parented under the sign, `a1.WorldPosition.Y ≈ deck + 1`, and it is **visible in a screenshot** | rope absent, buried in the pier, or taut/suspending the boat |
| Untie still works | prompt flips to "Untie Boat", `RequestUntie` from the seat still releases | either path dead |
| Camp signs unchanged | a trading-post sign's board size/CFrame/text/font identical to before the refactor | any drift ⇒ the extraction was not verbatim |

## 6. Checklist

- [x] Symptom reproduced in Play, at the player's camera, before any fix
- [x] Geometry measured live, not assumed
- [ ] Plan agreed
- [ ] Implemented
- [ ] Verified in Play with the table in §5
- [ ] Before/after from the same camera
- [ ] Final summary + changelog
