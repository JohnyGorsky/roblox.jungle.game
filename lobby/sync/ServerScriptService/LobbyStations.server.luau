--!strict
-- LobbyStations.server.luau — greybox dry-docked boat + walk-up upgrade kiosks (Job 032). GREYBOX/mechanics
-- only — the design pass replaces the art. Each kiosk's ProximityPrompt opens the matching purchase panel
-- (via the OpenPanel remote); the bottom-left buttons still work too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local openPanel = Instance.new("RemoteEvent")
openPanel.Name = "OpenPanel"
openPanel.Parent = ReplicatedStorage

local root = Instance.new("Folder")
root.Name = "LobbyStations"
root.Parent = Workspace

local function block(name: string, size: Vector3, color: Color3, pos: Vector3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Position = pos
	p.Parent = root
	return p
end

-- greybox dry-docked boat (visual anchor for the upgrade area)
local BOAT_POS = Vector3.new(-52, 3.5, 52)
block("DryDock", Vector3.new(20, 1, 28), Color3.fromRGB(90, 90, 96), BOAT_POS - Vector3.new(0, 3, 0), Enum.Material.Concrete)
block("LobbyBoatHull", Vector3.new(14, 3, 22), Color3.fromRGB(120, 85, 55), BOAT_POS, Enum.Material.WoodPlanks)
block("LobbyBoatSeat", Vector3.new(4, 1, 5), Color3.fromRGB(60, 45, 30), BOAT_POS + Vector3.new(0, 2, 0))
block("LobbyBoatMotor", Vector3.new(2, 2, 3), Color3.fromRGB(40, 40, 46), BOAT_POS + Vector3.new(-3.5, 1, 10.5), Enum.Material.Metal)

local function kiosk(title: string, id: string, pos: Vector3, color: Color3)
	local post = block("Kiosk_" .. id, Vector3.new(3, 5, 3), color, pos, Enum.Material.Metal)
	local sp = Instance.new("Part")
	sp.Anchored = true
	sp.CanCollide = false
	sp.Transparency = 1
	sp.Size = Vector3.one
	sp.Position = pos + Vector3.new(0, 4, 0)
	sp.Parent = root
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(7, 2)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 140
	bb.Parent = sp
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 0.3
	lbl.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Text = title
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = lbl
	lbl.Parent = bb
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "KioskPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = title
	prompt.HoldDuration = 0.2
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = post
	prompt.Triggered:Connect(function(player: Player)
		openPanel:FireClient(player, id)
	end)
end

kiosk("BOAT UPGRADES", "modules", Vector3.new(-40, 2.5, 62), Color3.fromRGB(60, 100, 170))
kiosk("SKILL TRAINER", "skills", Vector3.new(-40, 2.5, 52), Color3.fromRGB(150, 110, 60))
kiosk("ROBUX SHOP", "robux", Vector3.new(-40, 2.5, 42), Color3.fromRGB(40, 130, 90))
kiosk("BOUNTIES", "weekly", Vector3.new(-40, 2.5, 32), Color3.fromRGB(90, 120, 70))

print("[LobbyStations] dry-docked boat + upgrade kiosks online")
