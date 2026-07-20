--!strict
-- LobbyStations.server.luau — walk-up upgrade kiosks (Job 032; REWIRED Job 064).
--
-- The lobby is EDITOR-PLACED (memory: lobby-editor-placed-not-scripted). This script NO LONGER builds
-- the dry-dock / boat / kiosk geometry — it FINDS each editor station (a Model with attribute
-- Station = "<type>", by convention under Workspace.LOBBY_GREYBOX.Stations) and attaches a
-- ProximityPrompt that opens the matching purchase panel via OpenPanel. The bottom-left buttons still
-- work too. Panel-opening logic (OpenPanel + ids) is unchanged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local openPanel = ReplicatedStorage:FindFirstChild("OpenPanel")
if not openPanel then
	local ev = Instance.new("RemoteEvent")
	ev.Name = "OpenPanel"
	ev.Parent = ReplicatedStorage
	openPanel = ev
end

-- editor Station attribute -> (OpenPanel id, prompt title)
local STATIONS = {
	{ station = "BoatUpgrades", id = "modules", title = "BOAT UPGRADES" },
	{ station = "SkillTrainer", id = "skills", title = "SKILL TRAINER" },
	{ station = "RobuxShop", id = "robux", title = "ROBUX SHOP" },
	{ station = "Bounties", id = "weekly", title = "BOUNTIES" },
}

local function findStation(kind: string): Instance?
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:GetAttribute("Station") == kind then
			return d
		end
	end
	return nil
end

local function promptHost(inst: Instance): BasePart?
	local a = inst:FindFirstChild("Anchor")
	if a and a:IsA("BasePart") then
		return a
	end
	if inst:IsA("Model") and inst.PrimaryPart then
		return inst.PrimaryPart
	end
	if inst:IsA("BasePart") then
		return inst :: BasePart
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function attach(def)
	-- wait briefly for the editor station to be present
	local station: Instance? = nil
	local t0 = os.clock()
	repeat
		station = findStation(def.station)
		if station then
			break
		end
		task.wait(0.2)
	until os.clock() - t0 > 15
	if not station then
		warn('[LobbyStations] no editor station Station="' .. def.station .. '" — kiosk prompt not attached')
		return
	end
	local host = promptHost(station)
	if not host then
		warn("[LobbyStations] station " .. def.station .. " has no BasePart to host the prompt")
		return
	end
	-- size the activation radius to cover the WHOLE building (+ walk-up margin), measured from the
	-- host part — so the prompt triggers anywhere around the house, not just at one exact spot.
	local reach = 34
	if station:IsA("Model") then
		local _, sz = station:GetBoundingBox()
		reach = math.max(math.max(sz.X, sz.Z) / 2 + 22, 34) -- generous: whole building + wide walk-up
	end
	local dup = host:FindFirstChild("KioskPrompt")
	if dup then
		dup:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "KioskPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = def.title
	prompt.HoldDuration = 0.2
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = reach
	prompt.Parent = host
	prompt.Triggered:Connect(function(player: Player)
		openPanel:FireClient(player, def.id)
	end)
	print("[LobbyStations] " .. def.title .. " -> " .. station:GetFullName())
end

for _, def in ipairs(STATIONS) do
	task.spawn(attach, def)
end
