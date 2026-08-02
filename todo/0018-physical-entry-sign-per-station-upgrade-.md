# TODO 0018: Physical entry sign per station/upgrade (3D signboard, not a decal/floating label)

**Project:** `roblox.jungle`
**Status:** resolved (2026-08-02) — Done in Job 069, 2026-08-02 -- both halves resolved, one built and one deliberately declined. STATION SIGNS: already existed on all 4 stations, verified by the Job 068 sweep (EntrySign = Board 8x3x0.4 WoodPlanks on two Posts, SurfaceGui on BOTH faces, Special Elite font). The audit reported a false gap from asymmetric ASSETS.md notes; 1.3 is corrected. PARTY PADS: user decided 2026-08-02 to SKIP -- a pad already carries a coloured deck, glowing accent ring, light column, eight edge lights, a "Blue PAD" BillboardGui with the party icon badge, AND the runtime PadSign roster naming it "LAUNCH PAD n". A wooden signboard would be a THIRD text label on the least ambiguous object in the lobby. BOAT-UPGRADE MODULES: BUILT. LobbyBoat now adds one distance-culled BillboardGui per OWNED module (MaxDistance 45, far shorter than the owner tag 120 so a harbour of 5 boats stays readable). Display names come from ModuleDefs and are never written in LobbyBoat, so a shop rename cannot leave the boat advertising a stale name. Anchors are a CANDIDATE LIST not one name, because some modules render differently with/without art (trailer = one Trailer mesh host, or four CargoCrate* greybox pieces); a miss warns rather than silently skipping. Styled from Theme (server-safe tokens, same as LobbySignage). VERIFIED in Play: 7/7 nameplates present, each on the right anchor -- MOUNTED GUN UPGRADE on GunBarrel, TWIN MOTORS MOUNT on Motor2, REINFORCED HULL on HullPlateR2, EXTENDED FUEL TANK on FuelTankModule, SEARCHLIGHT RIG on SearchlightHead, CARGO RACKS on Trailer, RAMP BOW & HULL SHAPE on RampBow -- no warns. Analyzer clean.
**Created:** 2026-07-20 20:46:48

Every station/upgrade (SkillTrainer, Bounties, RobuxShop, BoatUpgrades, party pads, boat-upgrade modules) needs its OWN physical entry sign that says what it is — a real 3D signboard (posts + board + engraved/SurfaceGui text in jungle-style Special Elite, cream + stroke) placed at the station like an outpost sign you walk up to. NOT a flat decal, and NOT just the distance-culled BillboardGui label. Should read clearly and match the weathered wood/metal look. Ref: user screenshot of Bounties board 2026-07-20.

## ✅ Station half DONE — corrected by the Job #068 live sweep (2026-08-02)

**The narrowing written below was wrong and is superseded by this block.** The live place has an
`EntrySign` on **all four** stations, each a real 3-D signboard (`Board` 8×3×0.4 WoodPlanks on two
`Post`s 0.6×4.5×0.6 Wood) — exactly what this todo asked for:

| Station | EntrySign | Text |
|---|---|---|
| `SkillTrainer` | ✅ | "SKILL TRAINER" |
| `Bounties` | ✅ | "BOUNTIES" |
| `RobuxShop` | ✅ | "ROBUX SHOP" |
| `BoatUpgrades` | ✅ | "BOAT UPGRADES" |

The desk audit inferred a gap from `ASSETS.md` §1.3's per-row notes, where two rows mention an entry
sign and two don't. That asymmetry is a **doc-writing inconsistency, not a build gap**. §1.3's last
row (*"Sign boards (per station) · ▫ queued"*) should be marked done — folded into `todo/0035`.

**What is still open on this todo:** the OPTIONAL remainder — signs for the **party pads** and the
**boat-upgrade modules**. The pads carry colour, a light column and a party badge, so they read fine
without one.

---

## ~~Narrowed by the Job #068 lobby audit (2026-08-02) — gap B2, REQUIRED~~ *(superseded — see above)*

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
