# TODO 0018: Physical entry sign per station/upgrade (3D signboard, not a decal/floating label)

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-07-20 20:46:48

Every station/upgrade (SkillTrainer, Bounties, RobuxShop, BoatUpgrades, party pads, boat-upgrade modules) needs its OWN physical entry sign that says what it is — a real 3D signboard (posts + board + engraved/SurfaceGui text in jungle-style Special Elite, cream + stroke) placed at the station like an outpost sign you walk up to. NOT a flat decal, and NOT just the distance-culled BillboardGui label. Should read clearly and match the weathered wood/metal look. Ref: user screenshot of Bounties board 2026-07-20.

## Narrowed by the Job #068 lobby audit (2026-08-02) — gap B2, **REQUIRED**

Not a duplicate todo: this one already owns the work, and the audit scoped down what is actually left.

**Two of the four stations already have their sign** — SkillTrainer and RobuxShop each picked one up
during their Meshy swap (ASSETS.md §1.3 notes them as *"…grounded, entry sign, localized"*).
**Bounties and BoatUpgrades did not** — their rows list only *"Station attr + Anchor/prompt transferred,
grounded, localized"*, with no entry sign.

So those two stations are identified today by nothing but the distance-culled `BillboardGui` that this
todo explicitly calls insufficient. That is the last visibly-unfinished piece of an otherwise-complete
station set, which is why the audit marks it REQUIRED.

Party pads and boat-upgrade modules (the rest of this todo's original scope) stay OPTIONAL — the pads
carry colour, a light column and a party badge, so they read fine without a signboard.

Tracked in `Jobs/068/intake.md` → Part B, gap B2.
