# Job #036: River obstacles that slow + damage the boat

**Project**: `roblox.jungle`
**Created**: 2026-07-19 16:53:37
**Status**: Requirements Gathering (intake)

## Requirements / goal

From todo 0004. Add collidable river OBSTACLES the driver must weave around: on boat contact they SLOW the boat and DAMAGE the hull, scaled per type (e.g. Sandbar = big slow, little damage; Rock = hard stop + big damage; Log/deadwood = medium both). Server-authoritative hit detection (debounced per object). Spawn them along the channel ahead of the boat (like the enemy/dock streamers), scaling density with distance/zone. Wire into boat HP + a speed penalty (BoatServer). Replace/repurpose any existing do-nothing obstacle placeholders. POC greybox shapes.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan (inline)
- [x] Implementation completed — real obstacles (rock/log/sandbar) on the obstacle hooks; slow+damage on
      contact verified (Rock −25 HP, destroyed; cumulative hits → BOAT 0%); tied-safe; analyzer-clean
- [x] Final summary + changelog written
