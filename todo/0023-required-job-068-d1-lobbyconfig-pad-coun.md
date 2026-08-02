# TODO 0023: REQUIRED (Job 068 D1): LobbyConfig.PAD_COUNT = 3 is dead code AND wrong (there are 4 pads)

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 10:50:31

Audit Job 068, gap D1. The place has 4 pads (Blue/Red/Green/Yellow). grep PAD_COUNT across both trees returns exactly one hit -- its own declaration. LobbyServer discovers pads by the Station=="PartyPad" attribute, so the constant is never read. Nothing breaks, but it is a lying config value in the first file a future reader opens to change the party setup. Delete it, or make it authoritative.
