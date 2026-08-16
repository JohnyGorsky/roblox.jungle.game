# Job #088: Playtest batch: shore aggro, creature seating, carried loot

**Project**: `roblox.jungle`
**Created**: 2026-08-16 22:48:19
**Status**: Requirements Gathering (intake)

## Requirements / goal

Three items chosen by the user from the 2026-08-16 playtest, following Job #086.

ITEM 1 - Land creatures ignore players ashore. EnemyServer.server.luau:261-262 states it plainly: land creatures target ONLY the boat, because they were assumed unable to cross water to reach a swimmer. Sea creatures gained swimmer-hunting in Job #084; land creatures never got the equivalent. Result reported in play: 'why do boars just follow on shore' - stepping ashore makes you SAFER, which is backwards. Fix: give land creatures the same nearest-person targeting, preferring an on-foot player over the boat when closer, and make sure a creature hunting a person cannot damage the hull (the canHitBoat flag applyBite already takes).

ITEM 2 - Land creature visuals sink into the ground. Measured in Studio: the Wolf rig is 1.71 x 4.23 x 6.22 authored, x art.scale 1.3 = 2.22 x 5.50 x 8.09, with its pivot 0.53 (0.69 scaled) ABOVE the bounding-box centre. EnemyRig pivots the visual to the hitbox CENTRE (ground + def.size.Y/2 = ground+2), so the rig's bottom lands at ground - 1.44: a quarter of the wolf buried. Pre-existing, not caused by #086 - over water it read as 'swimming', which is why the first report looked like a swimming wolf. Putting wolves on land at camps exposed it. Fix: seat LAND creatures so the visual's bottom meets the hitbox bottom, measured from the model. Sea creatures must keep their water-line seating so crocs stay half-submerged.

ITEM 3 - Carried loot rides on the player's head. ExcursionServer.server.luau:615 pivots the carried barrel to root.CFrame * CFrame.new(0, 3, 0) - 3 studs straight up. Should sit slung on the upper back instead.

NOT IN SCOPE - glowing eyes sit wrong on every creature because no model has EyeLeft/EyeRight Attachments, so EnemyRig falls back to guessing offsets from the (Panther-inherited) hitbox. The USER is placing those attachments by hand in Studio; the code path already prefers them and needs no change.

## Checklist

- [ ] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
