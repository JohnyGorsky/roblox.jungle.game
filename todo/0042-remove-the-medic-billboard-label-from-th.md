# TODO 0042: Remove the MEDIC billboard label from the boat medic station

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 21:53:42

User call (Job 073 playtest): the MEDIC world label is not wanted. It is a BillboardGui built in sync/ServerScriptService/Cargo/CargoServer.server.luau (lbl.Text = 'MEDIC', ~line 177) on the medic station model. It is AlwaysOnTop, which is also why IntroHudGate has to hide world billboards during the cold open (Job 072). Removing the label may let part of that gate's billboard handling be simplified - check before deleting, the ROBUX SHOP tag still needs it. The station itself and the Medic ROLE stay; only the floating text goes.
