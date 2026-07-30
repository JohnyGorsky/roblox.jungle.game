--!strict
-- EntryBar.local.luau — the lobby's single on-screen entry bar (Job 065).
--
-- REPLACES four ad-hoc open buttons. Until now every panel script built its own button at a hardcoded
-- pixel offset (RobuxShop at (0,14),(1,-224); RetentionClient at (1,-154); ModulesShop at (1,-14);
-- AdminClient bottom-right). That was four copies of the same idea, manually stacked — and on a phone
-- the fixed offsets overlap or fall off screen, which §6.10 forbids.
--
-- One bar, scale-based and safe-area aware, owned by Components.iconBar. Walking up to a station kiosk
-- still opens the same panels (LobbyStations → OpenPanel), so both routes work; this is the route for
-- players who don't want to walk.
--
-- Admin is deliberately NOT here — it stays its own corner button, gated to allowlisted users.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = ReplicatedStorage:WaitForChild("UI")
local Components = require(UI:WaitForChild("Components"))
local UIBus = require(UI:WaitForChild("UIBus"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Order is deliberate: the two progression shops first (what a returning player came for), then
-- bounties, then the Robux shop last — convenience, never the loudest thing on screen.
Components.iconBar(playerGui, {
	{ icon = "wrench", label = "BOAT", onActivated = function()
		UIBus.open("modules")
	end },
	{ icon = "star", label = "SKILLS", onActivated = function()
		UIBus.open("skills")
	end },
	{ icon = "bounty", label = "BOUNTIES", onActivated = function()
		UIBus.open("weekly")
	end },
	{ icon = "shop", label = "SHOP", onActivated = function()
		UIBus.open("robux")
	end },
})
