# Final Summary — Job #032: Visual in-lobby upgrade stations

**Project**: `roblox.jungle` ("Last River") · **Completed**: 2026-07-19 · POC · From todo 0002. Lobby-only.
**GREYBOX / mechanics only — the design pass replaces the art.**

## What was built
A dry-docked **greybox boat** in the lobby + four labelled walk-up **kiosks** that open the existing purchase
panels. The bottom-left buttons still work too; purchase logic is unchanged.

### Files (lobby tree)
- **New:** `ServerScriptService/LobbyStations.server.luau` — greybox boat + dock + 4 kiosks (post +
  BillboardGui title + ProximityPrompt); creates the `OpenPanel` RemoteEvent; each prompt fires it with an id.
- **Edit:** `ModulesShop` / `SkillShop` / `RobuxShop` / `RetentionClient` `.local.luau` — each adds an
  `OpenPanel` listener that opens its panel on the matching id (`modules`/`skills`/`robux`/`weekly`).

Kiosks: **BOAT UPGRADES** → modules, **SKILL TRAINER** → skills, **ROBUX SHOP** → robux, **BOUNTIES** → weekly.

## Verified (live in Studio)
- [x] Analyzer-clean.
- [x] Lobby boat + 4 titled kiosks appear (screenshot).
- [x] Firing `OpenPanel "modules"` (as the BOAT UPGRADES kiosk does) **opened the BOAT UPGRADES panel**
      (screenshot). The other three kiosks use the identical path.

## Notes / follow-ups
- **Not committed.** Test account reset to clean.
- Greybox: real boat/kiosk art + placement come in the design pass; per-module part-markers (open the panel
  focused on a specific module) is a future nicety.
- **All three promoted todo-jobs (#030 untie, #031 admin, #032 stations) are done.**
