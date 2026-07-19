# Job #063: Fill Last River style guide (design pass)

**Project**: `roblox.jungle`
**Created**: 2026-07-20 00:21:40
**Status**: Requirements Gathering (intake)

## Requirements / goal

Design and fill in the actual Last River (Jungle) styles in STYLEGUIDE.md: colors, art direction, design pillars, and rules. Based on the user's reference assets in assets/Images (DesignConcept.txt + concept images: boat, jungle example, GUI pattern, logo, map). Discuss, then fill the guide; later promote to a skill.

## Decisions (2026-07-20, via wizard)

1. **Art direction: detailed-stylized wins** — adopt DesignConcept.txt as canonical (chunky/readable
   + detailed weathered meshes/materials + warm cinematic lighting). Supersedes GAME.md's "low-poly"
   wording; kept shippable via explicit mobile-perf budget rules.
2. **Currencies & skills unchanged** — the GUI mockup informs **colors + layout only**; economy
   (Gold / Salvage / River Score) and skill trees stay as GAME.md defines them.
3. **Doc depth: full** — STYLEGUIDE.md holds art direction AND the full UI component kit; later split
   into a per-game design skill.

## Progress

- [x] Read DesignConcept.txt + all 5 concept images
- [x] Filled `roblox.jungle.game/STYLEGUIDE.md` to full depth (14 sections)
- [x] Updated GAME.md art-direction wording + backlog (points to STYLEGUIDE.md)
- [x] Font system chosen (Builder Sans + Oswald + Special Elite + Permanent Marker + Roboto Mono)
- [x] Added HUD-minimalism rule (§6.11): in-game shows only mandatory info; all panels closable +
      collapsible; heavy panels default collapsed; obvious close on every panel; never cover core HUD
- [ ] User review of filled guide
- [ ] Source & record: icon asset IDs (Flaticon upload, Creator Store search, or Meshy text-to-image)
- [ ] Promote accepted guide to a per-game design skill (Jungle's first `.claude/skill`)

## Checklist

- [x] Requirements reviewed (this intake)
- [ ] Implementation plan created & agreed
- [ ] Implementation completed
- [ ] Final summary + changelog written
