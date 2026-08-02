--!strict
-- LobbyConfig.luau — lobby/teleport tunables (Job 017). Lives in the LOBBY place.

local LobbyConfig = {}

-- The GAMEPLAY place ("Last River COOP Game") players teleport into. (Place ID from the Creator Hub URL
-- .../places/<ID>/configure.) 0 would disable teleport for Studio testing.
LobbyConfig.GAMEPLAY_PLACE_ID = 138141472932347

-- NO PAD_COUNT HERE, DELIBERATELY (Job 069, audit Job 068 gap D1). Launch pads are DISCOVERED at
-- runtime by `LobbyServer`, which scans for Models with the attribute Station = "PartyPad" — add or
-- remove a pad in the editor and nothing here needs touching. The old `PAD_COUNT = 3` was read by
-- nothing and had drifted to a lie (the place has 4 pads: Blue/Red/Green/Yellow).
LobbyConfig.MAX_PER_PAD = 6 -- party size cap per pad
LobbyConfig.COUNTDOWN = 3 -- seconds from Start → teleport

return LobbyConfig
