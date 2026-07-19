# TODO 0004: River obstacles that actually do something

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-07-19 16:19:47

Right now river obstacle placeholders do nothing. Add basic collidable obstacle objects (rocks, logs/deadwood, sandbars, wreck debris) that AFFECT the boat on hit: slow it down + damage the hull, scaled per object type (e.g. sandbar = big slow, little damage; rock = hard stop + big damage; log = medium both). Server-authoritative hit detection; tie into boat HP + speed. Different objects = different slow/damage values. Driver must weave around them (core driver-skill loop). POC greybox shapes.
