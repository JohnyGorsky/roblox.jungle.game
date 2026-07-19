# Job #038: Lights on at night only + hotbar slot deselect toggle

**Project**: `roblox.jungle`
**Created**: 2026-07-19 17:29:56
**Status**: Requirements Gathering (intake)

## Requirements / goal

Two tweaks. (1) LIGHTS DAY/NIGHT: the player torch PointLight and the boat searchlight SpotLight should be OFF during the day and turn ON at night/dusk. Tie to Workspace.Phase via a small LightController that toggles lights tagged NightLight (Enabled = phase==night), incl. newly-created ones. (2) DESELECT TOGGLE: clicking the already-active hotbar slot deselects it (empty hands / holster) so you can put the torch/weapon away. Server-authoritative (InventoryService.equip).

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan (inline)
- [x] Implementation completed — lights off by day/on at night (NightLight tag + controller) + hotbar deselect toggle; verified live; analyzer-clean
- [x] Final summary + changelog written
