# Job #015: Weapons Loadout Sword Guns

**Project**: `roblox.jungle`
**Created**: 2026-07-18 19:48:55
**Status**: Requirements Gathering (intake)

## Requirements / goal

# Weapon loadout — sword default + guns earned at camps

**Source:** GAME.md "Weapons & combat" (2026-07-18). **Depends:** #006/#014 (handheld + mounted gun exist).

Turn the current always-on handheld gun into a proper **loadout**:

## Scope
- **Sword = the default.** Every player without a gun carries a **melee sword**: hit enemies at **very
  short range** only, always available. Needs a melee hit system (swing → short-range hitbox/raycast →
  damage, server-authoritative), a greybox sword tool, a swing anim later (P9).
- **Guns are earned at camps.** A player only free-aims a **gun** once they've **looted one at a camp**
  (a weapon crate → grants a pistol to that player). Track a per-player "has gun" state; the handheld
  weapon (already built) is gated behind it. Different guns/tiers later.
- **Reconcile with existing weapons:** the handheld free-aim (#006) becomes the pistol; the mounted gun
  (#014) is the gunner's; the sword is the fallback. One clean "what am I holding?" model.

## Decisions (2026-07-18, via wizard)
- **Inventory:** **4 limited slots**, **one item active at a time**. Slots hold sword / pistol / shotgun /
  small items; **each gun has its own ammo type**.
- **Carry/drag mode (Dead Rails-style):** a large object (gasoline canister, metal) can be **physically
  picked up & carried** *without* consuming a slot — but **while carrying it you can't use any
  weapon/item** (hands full). This is the resource-haul mechanic.
- **Sword = default, pure fallback:** short range, modest damage/cooldown, always in a slot from spawn.
- **Guns = scarce camp loot:** everyone **starts sword-only**; a weapon crate at a camp grants a
  pistol/shotgun into a slot. Guns are a rare top-tier reward.
- **Persistence:** looted guns are **kept for the whole run** — death/revive does **not** strip them.
- **Hand-carry to trailer (ties into #013):** loot canister/metal → carry it back → **deposit into the
  trailer cargo**. Inventory/carry is the courier; the trailer is the store.
- **Reconcile weapons:** handheld free-aim (#006) **becomes the pistol** (gated behind looting one);
  mounted gun (#014) stays the gunner's; the sword is the fallback. One "what am I holding?" model.

## Open questions (remaining — for the plan)
- Exact sword numbers (damage/range/cooldown) and per-gun ammo capacities.
- Weapon-crate spawn rate at camps / which camps drop pistol vs shotgun.
- Carry-mode movement penalty (slower while hauling?) — likely yes, tune later.

## Why it matters
Gives combat **progression** (sword → gun) and makes camp raids meaningful (guns are a top reward),
and fits the role model (helpers = fighters with sword/gun).

→ Promote to a job.


## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] Final summary + changelog written
