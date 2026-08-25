# Job #117: M16 assault rifle — burst-fire weapon sold as a lifetime pass or per-run purchase

**Project**: `roblox.jungle`
**Created**: 2026-08-25 12:53:13
**Status**: ✅ COMPLETE — implemented, verified in Play, published by the user 2026-08-25

## Requirements / goal

Add the M16 to Last River as the first Robux-sold handheld weapon.

SELLING
- Lifetime game pass 'Lifetime M16' (1954603618, 150 R$): the owner starts EVERY run with the M16 in their loadout and 30 rounds, free.
- Per-run developer product 'M16' (3709767395, 30 R$): one purchase per run grants the M16 + 30 rounds for that run only. Bought in the LOBBY it is held on the profile and spent when the next run starts; bought IN-RUN it grants immediately. A second purchase in the same run is refused.
- Both offers appear in BOTH Robux shops (lobby + game start-area kiosk).
- NOT lootable at camps and NOT buyable with Salvage/scraps — for now.

FIRING (burst weapon)
- One trigger pull fires a 2-second continuous burst of 20 bullets (0.10 s apart) and costs ONE round.
- No new shot is accepted until the 2 seconds are over.
- 14 damage per bullet, range 250 (280 damage per full burst; 140 dps sustained).

ASSETS (already uploaded by the user, 2026-08-25)
- Model  Rifle.glb -> 84134973846203 (mesh 101680702520520) -> ServerStorage.AssetLibrary.Weapons.M16
- Audio  rifle_shoot.mp3 -> 138005496001979 (3.888 s sustained auto-fire; play ONCE per burst, stop at burst end)
- Icon   assault-rifle.png -> 87494055704448 (Theme.icon.rifle — hotbar + shop rows)
- Icon   bullet.png -> 134307949592665 (Theme.icon.rifleAmmo — the clip/ammo glyph)
- Hub art RobloxPassM16.png -> 118709115773836 (Creator Hub pass listing art; opaque, NOT for in-game badges)

ADMIN
- Add an admin-panel action that grants the M16 + rounds, so the user can test it without buying.

NOTE: this is the second deliberate 'power = true' exception after the Armored Boat. GAME.md's monetization section must record it.

## Checklist

- [x] Requirements reviewed (this intake)
- [x] **Independent reviewer agent run** - given the symptom/requirement, NOT my theory (GROUND-RULES 8)
      -> found a defect the plan would have shipped (`SkillGun` scaling the 2 s lockout to 1.401 s) plus
      four gaps. See `implementation-plan.md` §0b and `final-summary.md` §1.
- [x] **Symptom reproduced in PLAY**, at the player's camera, before any fix (GROUND-RULES 7)
      -> the user's "big yellow square" captured in first person BEFORE changing anything, which is what
      ruled out the muzzle flash (the first, wrong, suspicion) and identified the tracer.
- [x] Implementation plan created & agreed
- [x] Implementation completed
- [x] **Proof it works better** captured - before/after from the same camera, in Play
      -> plus 18 numbered checks, each stating its own failure condition (`final-summary.md` §4).
- [x] Final summary + changelog written

## Not closed by this job

- ⚠️ `ProcessReceipt` for the per-run product has never run for real (Marketplace prompts do not complete
  in Studio). The grant mechanism it calls IS verified. One 30 R$ purchase on the published place closes it.
- ⚠️ Mobile not measured in the Device Emulator. No new touch surface was added (`TouchFire` unchanged).
- 🔴 The **Bazooka** pass `1956512376` (250 R$) and product `3709767468` (80 R$) are `IsForSale = true` and
  wired to NOTHING. Re-checked after the user published, 2026-08-25: still for sale. Game passes are listed
  on the experience store page and buyable from the website without entering the game, so this currently
  takes money and delivers nothing — the same failure the Cosmetic Bundle had in Job #067.
