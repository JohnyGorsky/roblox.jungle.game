--!strict
-- StartShopServer.server.luau — start-area Robux shop kiosk at the crash-site hub (Job 046).
-- A small greybox kiosk sits on the hub platform (where the crew wakes up, by the boat). Walking up + holding
-- the ProximityPrompt fires OpenRobuxShop to that client, which opens the Robux shop panel (RobuxShop.local).
-- Purchases go through MarketplaceService client-side; receipts are handled by MonetizationServer. Greybox.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- client opens the panel on this event (fired to the triggering player)
local openRemote = Instance.new("RemoteEvent")
openRemote.Name = "OpenRobuxShop"
openRemote.Parent = ReplicatedStorage

-- wait for the hub to exist (StagingServer publishes HubSpawn once the crash-site hub is built)
local t0 = os.clock()
while Workspace:GetAttribute("HubSpawn") == nil and os.clock() - t0 < 20 do
	task.wait(0.1)
end
local hub = Workspace:GetAttribute("HubSpawn") :: Vector3?
if not hub then
	warn("[StartShop] no HubSpawn — kiosk not placed")
	return
end

-- Place the kiosk a few studs from the spawn point, DELIBERATELY ON THE OPPOSITE SIDE FROM THE PLANE
-- WRECK (Job #072). The old fixed `+Z` offset was fine against the generated greybox hub, but once the
-- hub moved to the hand-built SpawnBase it dropped the kiosk inside the wreck: the crashed plane is
-- 88 x 94 studs, so any FIXED direction is a coin flip. Deriving the direction keeps it clear no matter
-- where SpawnLocation or the plane are moved later.
local OFFSET = 12
local dir = Vector3.new(0, 0, 1)
local sb = Workspace:FindFirstChild("SpawnBase")
local plane = sb and sb:FindFirstChild("Plane")
if plane and plane:IsA("Model") then
	local pcf = plane:GetBoundingBox()
	local away = hub - pcf.Position
	local flat = Vector3.new(away.X, 0, away.Z)
	if flat.Magnitude > 1 then
		dir = flat.Unit
	end
end
local spot = hub + dir * OFFSET
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = {}
params.IgnoreWater = true
local hit = Workspace:Raycast(spot + Vector3.new(0, 14, 0), Vector3.new(0, -60, 0), params)
local topY = hit and hit.Position.Y or (hub.Y - 3)

local kiosk = Instance.new("Part")
kiosk.Name = "RobuxKiosk"
kiosk.Anchored = true
kiosk.Size = Vector3.new(4, 5, 2)
kiosk.Color = Color3.fromRGB(40, 130, 90)
kiosk.Material = Enum.Material.SmoothPlastic
kiosk.CFrame = CFrame.new(spot.X, topY + kiosk.Size.Y / 2, spot.Z)
kiosk.Parent = Workspace

-- floating label
local bb = Instance.new("BillboardGui")
bb.Size = UDim2.new(0, 160, 0, 40)
bb.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
bb.AlwaysOnTop = true
bb.Parent = kiosk
local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.fromScale(1, 1)
lbl.BackgroundTransparency = 1
lbl.Font = Enum.Font.GothamBold
lbl.TextColor3 = Color3.fromRGB(120, 220, 150)
lbl.TextStrokeTransparency = 0.4
lbl.TextScaled = true
lbl.Text = "ROBUX SHOP"
lbl.Parent = bb

local prompt = Instance.new("ProximityPrompt")
prompt.Name = "RobuxShopPrompt"
prompt.ActionText = "Open"
prompt.ObjectText = "Robux Shop"
prompt.HoldDuration = 0.2
prompt.RequiresLineOfSight = false
prompt.MaxActivationDistance = 12
prompt.Parent = kiosk

prompt.Triggered:Connect(function(plr)
	openRemote:FireClient(plr, "start")
end)

print("[StartShop] Robux kiosk online at the crash-site hub")
