--!strict
-- LobbyConfig.luau — lobby/teleport tunables (Job 017). Lives in the LOBBY place.

local LobbyConfig = {}

-- The GAMEPLAY place ("Last River COOP Game") players teleport into. (Place ID from the Creator Hub URL
-- .../places/<ID>/configure.) 0 would disable teleport for Studio testing.
LobbyConfig.GAMEPLAY_PLACE_ID = 138141472932347

LobbyConfig.PAD_COUNT = 3 -- number of launch pads
LobbyConfig.MAX_PER_PAD = 6 -- party size cap per pad
LobbyConfig.COUNTDOWN = 3 -- seconds from Start → teleport

return LobbyConfig
