# Job #032 — Implementation plan: visual in-lobby upgrade stations

**Project**: `roblox.jungle` · POC · From todo 0002. **Lobby-only.** GREYBOX mechanics — design pass replaces the art later.

## Idea
A dry-docked **boat in the lobby** + labelled walk-up **kiosks**; approaching one opens the existing purchase
panel. The bottom-left buttons stay too. Purchase logic is unchanged (Jobs 024/025/027/028).

## Mechanics
- New `OpenPanel` RemoteEvent. A kiosk's ProximityPrompt → `OpenPanel:FireClient(player, id)`.
- Each existing panel listens: `OpenPanel.OnClientEvent` → open itself when `id` matches.

Kiosks: `modules` (BOAT UPGRADES), `skills` (SKILL TRAINER), `robux` (ROBUX SHOP), `weekly` (BOUNTIES).

## Files (lobby tree)
- **New:** `ServerScriptService/LobbyStations.server.luau` — greybox boat + dry-dock + 4 labelled kiosks
  (post + BillboardGui title + prompt); creates `OpenPanel`; prompt fires it.
- **Edit:** `StarterPlayer/StarterPlayerScripts/UI/ModulesShop.local.luau`,`SkillShop.local.luau`,
  `RobuxShop.local.luau`,`RetentionClient.local.luau` — each adds an `OpenPanel` listener calling its open fn.

## Verification (Studio)
- Analyzer-clean.
- Lobby boat + 4 kiosks appear with titles; triggering each kiosk opens the right panel (screenshot).

## Out of scope
Real boat/kiosk art (design pass); per-module part markers (one Boat-Upgrades kiosk for POC); opening a panel
focused on a specific module.
