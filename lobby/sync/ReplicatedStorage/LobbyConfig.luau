--!strict
-- LobbyConfig.luau — lobby/teleport tunables (Job 017). Lives in the LOBBY place.

local LobbyConfig = {}

-- The GAMEPLAY place ("Last River COOP Game") players teleport into. 0 = not set yet → Start won't
-- teleport (it logs a warning instead) so the lobby is still testable in Studio. HUMAN: set this to the
-- gameplay Place ID from the Creator Hub.
LobbyConfig.GAMEPLAY_PLACE_ID = 0

LobbyConfig.PAD_COUNT = 3 -- number of launch pads
LobbyConfig.MAX_PER_PAD = 6 -- party size cap per pad
LobbyConfig.COUNTDOWN = 3 -- seconds from Start → teleport

return LobbyConfig
