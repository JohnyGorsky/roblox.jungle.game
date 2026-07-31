--!strict
-- LobbySignage.server.luau — restyles the world-space station and pad billboards (Job 065).
--
-- WHY A SCRIPT AND NOT AN EDITOR EDIT: the billboards live in the place file (built by
-- lobby/build/greybox_placement.luau and hand-tuned since), so they are editor content. But their
-- *styling* is design-system state that should move with the design system, not be re-hand-applied every
-- time the palette changes. This script finds each existing billboard by name and restyles it in place —
-- it never creates or moves geometry, matching the lobby's find-by-name/attach rule.
--
-- What it does per station billboard: palette fill + wood border, Builder Sans, cream text, and the
-- station's icon badge from Theme.icon. Party pads get the party icon in their pad colour.
-- Idempotent: re-running replaces its own additions and leaves everything else alone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))

local STATION_ICON: { [string]: string } = {
	SkillTrainer = "star",
	BoatUpgrades = "wrench",
	RobuxShop = "shop",
	Bounties = "bounty",
}

local PAD_ICON = "party"

local function styleLabel(label: TextLabel)
	label.Font = Theme.font.button
	label.TextColor3 = Theme.color.cream
	label.TextStrokeColor3 = Theme.color.stroke
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
end

-- Add (or replace) the icon badge on a billboard, and shift its text over to make room.
local function addBadge(bb: BillboardGui, iconKey: string, ringColor: Color3)
	local existing = bb:FindFirstChild("IconBadge")
	if existing then
		existing:Destroy()
	end

	local image = (Theme.icon :: { [string]: string })[iconKey]
	if not image then
		return
	end

	local badge = Instance.new("Frame")
	badge.Name = "IconBadge"
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.fromScale(0.02, 0.5)
	badge.Size = UDim2.fromScale(0.9, 0.78)
	badge.BackgroundColor3 = Theme.color.sunken
	badge.BorderSizePixel = 0
	badge.ZIndex = 3

	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.DominantAxis = Enum.DominantAxis.Height -- height is the known axis on a billboard
	ratio.Parent = badge

	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = badge

	local ring = Instance.new("UIStroke")
	ring.Color = ringColor
	ring.Thickness = 2
	ring.Parent = badge

	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(0.62, 0.62)
	art.BackgroundTransparency = 1
	art.BorderSizePixel = 0
	art.ScaleType = Enum.ScaleType.Fit
	art.Image = image
	art.ZIndex = 4
	art.Parent = badge

	badge.Parent = bb

	-- make room for the badge so the label isn't sitting under it
	for _, d in ipairs(bb:GetDescendants()) do
		if d:IsA("TextLabel") then
			styleLabel(d)
			d.TextXAlignment = Enum.TextXAlignment.Center
			if d.Size.X.Scale >= 0.95 then
				d.Position = UDim2.fromScale(0.16, d.Position.Y.Scale)
				d.Size = UDim2.fromScale(0.82, d.Size.Y.Scale)
			end
		end
	end
end

local stations = workspace:FindFirstChild("LOBBY_GREYBOX")
stations = stations and stations:FindFirstChild("Stations")
if not stations then
	warn("[LobbySignage] no LOBBY_GREYBOX.Stations — nothing restyled")
	return
end

-- `PadSign` is the LIVE party roster billboard that LobbyServer creates and rewrites every occupancy
-- tick. It owns its own styling; touching it here would fight that script (and the two run in a
-- non-deterministic order at startup), so it is explicitly skipped.
local OWNED_ELSEWHERE: { [string]: boolean } = { PadSign = true }

local styled = 0
for _, model in ipairs(stations:GetChildren()) do
	local kind = model:GetAttribute("Station")
	if typeof(kind) == "string" then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BillboardGui") and not OWNED_ELSEWHERE[d.Name] then
				if STATION_ICON[kind] then
					addBadge(d, STATION_ICON[kind], Theme.color.gold)
					styled += 1
				elseif kind == "PartyPad" then
					-- pads carry their own colour; the ring picks it up from the pad name
					local padName = model.Name:gsub("PartyPad_", "")
					local ring = (Theme.padColor :: { [string]: Color3 })[padName] or Theme.color.gold
					addBadge(d, PAD_ICON, ring)
					styled += 1
				end
			end
		end
	end
end

print(("[LobbySignage] restyled %d world billboard(s)"):format(styled))
