# FINDING 0017: Rejoining the same run re-seeds the loadout and destroys bought guns/ammo

**Project:** `roblox.jungle`
**Status:** open
**Severity:** high
**Created:** 2026-08-23 16:29:23

**Symptom:** InventoryService.seed guards on the per-PLAYER attribute InvSeeded, which is gone when a player rejoins. A crew member who buys a 750-salvage shotgun plus shells, disconnects and rejoins the same reserved server is re-seeded to Axe+Torch with zero ammo, silently. Job #104 makes ammo a paid item, so this now loses purchased goods as well as looted ones.
**Where:** _TODO: file / system_
**Repro / notes:** _TODO_
**Fix idea:** _TODO_

---

**Job #118 (2026-08-25) — the cost of this went up again, and it is now REAL ROBUX, not salvage.**

Re-verified while adding the Bazooka. `InventoryService.seed:280` still guards on the per-PLAYER attribute
`InvSeeded`, and `RifleGrant`'s own "already given this run" flag `Granted_<key>` is a per-player attribute
too — but the profile charge behind it was already spent by `Profiles.takeRunGrant` (`RifleGrant:115`).

So: buy the **80 R$ Bazooka charge** (or the 30 R$ M16 charge), receive the weapon, drop connection, rejoin
the same reserved server -> back to Axe + Torch, and the charge is gone from the profile. The player paid
Robux and holds nothing, with nothing in the log.

The lifetime PASSES are safe from this — `MonetizationServer.checkPasses` re-asks Roblox on every join, so
that entitlement is re-derived rather than stored. It is only the per-run charges that are lost.

Raised by Job #118's independent reviewer; **left unfixed on the owner's explicit call** (they scoped that
job to the Bazooka plus the pass-ownership money bug). Fix idea unchanged and now more valuable: persist the
spend on the PROFILE rather than as a session attribute, or re-grant on rejoin when the charge was already
consumed in this run.
