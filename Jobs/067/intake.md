# Job #067: Audit: skills, boat upgrades & monetization coverage

**Project**: `roblox.jungle`
**Created**: 2026-08-01
**Status**: Requirements Gathering (intake)

## Requirements / goal

Check whether `SkillDefs`, `ModuleDefs` and `MonetizationDefs` actually deliver the progression `GAME.md`
describes — and find what's missing, what's promised but absent, and what's **sold but not implemented**.

Audit first, fixes second. Everything below is verified against the code, not assumed.

---

## 🔴 Finding 1 — TWO PASSES ARE LIVE AND DELIVER NOTHING

**Severity: highest. Real money, right now.**

| Pass | Price | Status |
|---|---|---|
| **Boat Paint Pack** | 99 R$ | Live on the Creator Hub · **no implementation anywhere** |
| **Cosmetic Bundle** | 249 R$ | Live on the Creator Hub · **no implementation anywhere** |

`MonetizationServer` correctly checks ownership and sets `Owns_boatPaint` / `Owns_cosmeticBundle`.
**Nothing in either tree ever reads those attributes.** There is no hull-colour system, no trails, no wake
FX, no emote. A player who buys either gets an entry in their purchase history and **zero in-game effect**.

Both have finished art and icons (`ASSETS.md` §5.1), which is what makes this easy to miss — it looks done.

**Options:** implement them, or **unlist them on the Creator Hub until they work**. Doing nothing is not
neutral — this is a live storefront.

## 🔴 Finding 2 — THE ARMORED BOAT PASS SELLS POWER

`{ key = "armoredBoat", robux = 499, power = true, blurb = "+20% hull HP & +20% weapon damage" }`

It is **implemented** (`BoatModules`): if any crew member owns it, the whole boat gets +20% MaxHP and +20%
weapon damage.

This contradicts the design pillar in `GAME.md`, stated twice:

> *"**Robux** — **convenience & cosmetics only**: paid self-revive, extra inventory slots, cosmetics/skins…
> **Core power stays earnable.**"*
> *"Dead Rails' monetization works because it 'feels fair.' Paid = convenience + cosmetics, **never raw
> power**. We hold to that — it's why the model sells long-term."*

The def literally flags itself `power = true`. It is also the **most expensive** item we sell.

Mitigating: it's *shared* with the crew, so one buyer helps everyone — closer to Dead Rails' "someone
brought good gear" than a solo advantage. That's a judgement call, not a technicality.

## 🟠 Finding 3 — `GAME.md` PROMISES A MODULE THAT DOESN'T EXIST

> *"**Ramps / hull shape** — parts that let the boat **launch off jumps** and handle rapids better."*

There is no such module. Ramps/jumps exist in the river (Job 019), so this is a real gap in the upgrade
line, not a stale sentence — the boat can jump but can't be *built* for jumping.

## 🟠 Finding 4 — TWO PROMISED ROBUX ITEMS ARE MISSING ENTIRELY

`GAME.md`'s monetization list names four things. We sell one of them (cosmetics — broken, see #1):

| Promised | State |
|---|---|
| **Paid self-revive** | ❌ not implemented, not sold. `GAME.md` calls this "the monetized safety net" |
| **Extra inventory slots** | ❌ not implemented, not sold (open todo `0016`) |
| Cosmetics / skins | ⚠️ sold, does nothing (finding 1) |
| Starter boat / game pass | — optional |

So the *fair* monetization the design is built around is largely unbuilt, while the one **unfair** item is
the one that works.

## 🟢 Skills — coverage is good

10 skills, all implemented and levelled 1–10, split Boat / Crew:

| Group | Skills |
|---|---|
| Boat | Twin Motors (speed) · Rudder Tuning (turn) · Hull Plating (HP) · Diesel Efficiency (fuel) · Cargo Rigging (capacity) |
| Crew | Field Repair · Fuel Handling · Combat Medic · Gun Discipline · Scavenger's Instinct |

They map cleanly onto the four specialist roles plus the boat's core stats. **No gap found.** Two notes:

- **Crew skills are per-player but boat skills apply at max crew level** — the best player's level carries
  the boat. Deliberate and co-op friendly; worth confirming it's still wanted.
- Nothing covers **on-foot excursions** (the second core pillar) — no stamina, swimming, carry or combat
  skill for land raids. Not a bug; a possible future group.

## 🟢 Modules — 6, all implemented and visible

`motor2` · `hullkit` · `searchlight` · `fueltank` · `trailer` (Cargo Racks) · `gunupgrade`. All grant an
attribute **and** a visible part, which is the "upgrades are physical" pillar working as intended.

**Gaps against `GAME.md`'s module list:** ramps/hull shape (finding 3). "Chairs/stations" was resolved in
Job #066 — all 6 crew positions ship free with the hull.

## ⚪ Weapons — thin, but by design so far

`ItemDefs` has **Sword · Torch · Pistol · Shotgun** (in-run items). The only weapon *upgrade* is
`gunupgrade`, a single tier on the mounted gun. There is no weapon progression in the lobby, no tier 3,
no alternative mounted weapons. `GAME.md` doesn't promise more, so this is an **opportunity**, not a defect.

---

## What "skins / colours" would actually need

Worth knowing before deciding, because the Paint Pack implies it:

- A **colour/skin choice must persist** (profile field + migration) and **replicate** to everyone.
- The boat is now **mesh-skinned** (Job #066). Recolouring means either `SurfaceAppearance`-swapped
  variants (more textures to generate) or a tint applied to hull parts — the latter is cheap but fights
  the baked-in weathering of the current art.
- It must apply to **both** the game boat and the lobby showroom boat — they share `BoatParts`, so one
  hook covers both.
- Trails / wake FX are separate work (VFX on the boat), and an emote is separate again (animation).

So "Cosmetic Bundle" is really **three** features behind one price.

## Open questions

See the implementation plan — the decisions needed are: what to do about the two dead passes, whether the
Armored Boat keeps its power, and which gaps are worth building now vs later.

## Checklist

- [x] Audit completed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
