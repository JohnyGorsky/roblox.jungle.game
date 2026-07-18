--!strict
-- DockServer.server.luau — refuel docks along the river (Job 010).
--
-- Streams the seeded docks (RiverData.docksBetween) near the boat: a greybox plank + fuel drum at the
-- bank with a "Refuel" ProximityPrompt. Pull the boat up and hold it → the tank tops up. Server-
-- authoritative (checks the boat is actually beside the dock). Docks well behind are culled.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))

local AHEAD = 1600 -- generate docks this far ahead
local BEHIND = 400 -- cull docks this far behind
local REFUEL_RANGE = 65 -- the boat must be within this of the dock to refuel
local TICK = 0.5

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end
local boat = Workspace:WaitForChild("Boat")
local hull = boat:WaitForChild("Hull") :: BasePart
local WATER_Y = RiverData.WATER_Y

local docksRoot = Instance.new("Folder")
docksRoot.Name = "Docks"
docksRoot.Parent = Workspace

local placed: { [number]: Model } = {}

local function dockIndex(z: number): number
	return math.floor((z - RiverData.Z_START) / RiverData.DOCK_SPACING + 0.5)
end

local function buildDock(dock: RiverData.Dock, index: number)
	if placed[index] then
		return
	end
	local pos = Vector3.new(dock.x, WATER_Y, dock.z)
	local tangent = RiverData.tangentAtZ(dock.z)

	local model = Instance.new("Model")
	model.Name = "Dock"

	local deck = Instance.new("Part")
	deck.Name = "Deck"
	deck.Anchored = true
	deck.Size = Vector3.new(14, 1, 24)
	deck.Color = Color3.fromRGB(120, 85, 55)
	deck.Material = Enum.Material.WoodPlanks
	deck.CFrame = CFrame.lookAt(pos + Vector3.new(0, 3.5, 0), pos + Vector3.new(0, 3.5, 0) + tangent) -- sits above the basin floor (Y15) so a landing-site basin can't bury it
	deck.Parent = model
	model.PrimaryPart = deck

	-- tie / untie: hold the boat at the dock (won't drift off), with a visible rope.
	-- (No refuel here — refuelling happens at the boat's fuel STATION using looted gasoline; see CargoServer.)
	local tieAtt = Instance.new("Attachment")
	tieAtt.Name = "TieSpot"
	tieAtt.Position = Vector3.new(0, 1.5, 0)
	tieAtt.Parent = deck
	local tie = Instance.new("ProximityPrompt")
	tie.Name = "TiePrompt"
	tie.ActionText = "Tie Boat"
	tie.ObjectText = "Dock"
	tie.HoldDuration = 0.6
	tie.RequiresLineOfSight = false
	tie.MaxActivationDistance = 18
	tie.Parent = tieAtt

	local rope: RopeConstraint? = nil
	local ropeAtts: { Attachment } = {}
	tie.Triggered:Connect(function()
		if boat:GetAttribute("Tied") then
			hull.Anchored = false
			boat:SetAttribute("Tied", false)
			tie.ActionText = "Tie Boat"
			if rope then
				rope:Destroy()
				rope = nil
			end
			for _, a in ropeAtts do
				a:Destroy()
			end
			ropeAtts = {}
		elseif (hull.Position - pos).Magnitude <= REFUEL_RANGE then
			hull.Anchored = true -- greybox hold
			boat:SetAttribute("Tied", true)
			tie.ActionText = "Untie Boat"
			local a0 = Instance.new("Attachment")
			a0.Parent = hull
			local a1 = Instance.new("Attachment")
			a1.Parent = deck -- parent FIRST, then set world position (else the deck transform double-applies)
			a1.WorldPosition = pos + Vector3.new(0, 2, 0)
			ropeAtts = { a0, a1 }
			local newRope = Instance.new("RopeConstraint")
			newRope.Attachment0 = a0
			newRope.Attachment1 = a1
			newRope.Length = (a0.WorldPosition - a1.WorldPosition).Magnitude
			newRope.Thickness = 0.15
			newRope.Visible = true
			newRope.Color = BrickColor.new("Brown")
			newRope.Parent = hull
			rope = newRope
		end
	end)

	model.Parent = docksRoot
	placed[index] = model
end

while true do
	local boatZ = hull.Position.Z
	for _, dock in RiverData.docksBetween(boatZ - BEHIND, boatZ + AHEAD) do
		buildDock(dock, dockIndex(dock.z))
	end
	for index, model in placed do
		if boatZ - (RiverData.Z_START + index * RiverData.DOCK_SPACING) > BEHIND then
			model:Destroy()
			placed[index] = nil
		end
	end
	task.wait(TICK)
end
