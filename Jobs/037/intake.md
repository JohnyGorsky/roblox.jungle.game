# Job #037: Lights: boat searchlight + carryable player torch

**Project**: `roblox.jungle`
**Created**: 2026-07-19 17:09:18
**Status**: Requirements Gathering (intake)

## Requirements / goal

From todo 0005. (1) Verify the boat SEARCHLIGHT module (BoatModules SpotLight) actually lights the way at night. (2) Add a carryable player TORCH/LAMP (Dead Rails-style): an inventory item that emits light (PointLight) while held, so night jungle excursions aren't blind. POC: give a Torch in the starting loadout (lootable later) + emit light on the held visual. Ties into inventory (ItemDefs/InventoryService), day/night, and the night set-piece (#035).

## Checklist

- [x] Requirements reviewed (this intake)
- [x] Implementation plan (inline)
- [x] Implementation completed — Torch item (slot 2) emits a PointLight when held; boat searchlight confirmed; analyzer-clean
- [x] Final summary + changelog written
