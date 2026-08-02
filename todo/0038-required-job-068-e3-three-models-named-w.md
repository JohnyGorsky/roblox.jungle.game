# TODO 0038: REQUIRED (Job 068 E3): Three models named Watchtower_NW -- four towers exist, spec says two

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 11:32:33

Found by the Job 068 live sweep, 2026-08-02. Scenery holds Watchtower_NE at (96,28,-115) and THREE models named Watchtower_NW: (-88,28,-110) which is the intended NW, plus (34,28,151) and (-63,28,153) which are both in the SOUTH of the map. ASSETS.md 1.6 specifies 2 watchtowers. Two consequences: the map has four towers where the design says two, and LobbySoundscape:114 resolves Watchtower_NW BY NAME and attaches the rope creak to whichever it finds first -- so two of the four are silent and which one gets the sound is arbitrary. Decide whether the southern towers are wanted (then rename them, e.g. Watchtower_SW/SE, and update the soundscape list) or are accidental copies to delete.
