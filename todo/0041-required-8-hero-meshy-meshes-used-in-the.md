# TODO 0041: REQUIRED: 8 hero Meshy meshes used in the lobby are recorded NOWHERE but the place file

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-02 13:29:48

Found by the Job 069 lobby asset inventory, 2026-08-02. These mesh ids are live in the LOBBY place but absent from the shared registry, from ASSETS.md and from every script -- the .rbxl is the only record of them. If the place file were lost, or the GAME place needs the same props, there is no way back to them. Plane 118873896425222 | char1 (the Pilot body) 108352617907497 | SkillTrainer 107408955523438 | Boutnies [sic] 119564283624615 | RobuxhShop [sic] 81119390187013 | BoatUpgrade 118860073556013 | RunWay 114620021340964 | Mesh1.0 139814217941669 (UNIDENTIFIED -- generic name, needs someone to look at what it actually is). Add all 8 to roblox.workspace/Assets/registry/meshes.md with their in-place names and what they are. NOTE: two are misspelled in the place (Boutnies, RobuxhShop) -- harmless today because LobbyStations finds stations by the Station ATTRIBUTE not by name, but worth knowing before anyone writes a find-by-name against them. Full context: LOBBY-ASSET-INVENTORY.md section 5. By contrast all 53 script-declared ids (audio, UI icons, product art) ARE registered, and so are the 18 boat meshes.
