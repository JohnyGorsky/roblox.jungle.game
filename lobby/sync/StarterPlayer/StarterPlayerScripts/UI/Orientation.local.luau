--!strict
-- Orientation.local.luau — lock the LOBBY place to landscape on mobile (Job #095).
--
-- The GAME place locked landscape in Job #094. Without the same lock here a mobile player browses the
-- lobby in portrait and is then flipped to landscape the moment they teleport into a run — and, worse,
-- every lobby layout is being exercised in an orientation nothing has ever tested.
--
-- The lobby's own reason to prefer landscape is narrower than the game's but real: the entry rail is a
-- tall left-hand column and the top bar is a wide row, so the layout already assumes width. The game's
-- two-thumb argument doesn't apply here — the lobby is menus — which is why this was asked rather than
-- assumed, and answered "match the game place" (Job #095 plan §5.4).
--
-- ── Why here and not on StarterGui ────────────────────────────────────────────────────────────────
-- `StarterGui.ScreenOrientation` would be the natural home, but `StarterGui` is NOT in this repo's
-- auto-sync set (jungle-project skill: StarterGui/StarterPack/Workspace are manual-copy). A property
-- set there would live only in the .rbxl — invisible to git and to review. `PlayerGui.ScreenOrientation`
-- is the same setting applied per player, from a script that DOES sync.
--
-- Kept as its own file rather than folded into `TopBar` or `LobbyClient`: orientation is a property of
-- the PLACE, not of any one piece of chrome, and the next person looking for it should find it by name.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- LandscapeSensor, not LandscapeLeft: the player still chooses which way up the phone is, we only
-- refuse portrait. Pinning one side would flip the screen for half the players holding it the "wrong"
-- way, which is a worse experience than the problem being solved.
playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
