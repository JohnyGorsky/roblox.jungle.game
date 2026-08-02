# TODO 0023: REQUIRED (Job 068 D1): LobbyConfig.PAD_COUNT = 3 is dead code AND wrong (there are 4 pads)

**Project:** `roblox.jungle`
**Status:** resolved (2026-08-02) — Fixed in Job 069, 2026-08-02. PAD_COUNT deleted from lobby/sync/ReplicatedStorage/LobbyConfig.luau rather than corrected to 4 -- a constant nothing reads would just drift again the moment a fifth pad is placed. A comment now sits where it was, recording that LobbyServer DISCOVERS pads by the Station=="PartyPad" attribute, so the next person looking for a pad-count knob finds the answer instead of the gap. Verified: grep for PAD_COUNT across lobby/ and sync/ now returns only that comment (the two other hits are Job 017 historical docs, correctly left alone). Analyzer clean on LobbyConfig + LobbyServer.
**Created:** 2026-08-02 10:50:31

Audit Job 068, gap D1. The place has 4 pads (Blue/Red/Green/Yellow). grep PAD_COUNT across both trees returns exactly one hit -- its own declaration. LobbyServer discovers pads by the Station=="PartyPad" attribute, so the constant is never read. Nothing breaks, but it is a lying config value in the first file a future reader opens to change the party setup. Delete it, or make it authoritative.
