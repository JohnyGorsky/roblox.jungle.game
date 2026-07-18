--!strict
-- MeleeServer.server.luau — the default Sword: short-range swing hit (Job 015).
--
-- The client just requests a swing (no hit claim). The SERVER validates the swinger holds a Sword, isn't
-- busy/downed, then hits the nearest enemy within a short range IN FRONT of them. Same enemy convention
-- as the guns: walk up to an "Enemy"/"CampGuard"-tagged Model, damage its HP attribute. Server-authoritative.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))

local remote = Instance.new("RemoteEvent")
remote.Name = "SwordSwing"
remote.Parent = ReplicatedStorage

local lastSwing: { [Player]: number } = {}

remote.OnServerEvent:Connect(function(player: Player)
	local def = ItemDefs.get(player:GetAttribute("ActiveItem") :: string?)
	if not def or def.kind ~= "Melee" then
		return -- not holding the sword
	end
	if player:GetAttribute("Busy") == true then
		return -- hands full (carrying)
	end

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not root or not hum or char:GetAttribute("Downed") then
		return
	end
	-- can't swing while driving the boat or manning the mounted gun (same rule as the handheld)
	if hum.SeatPart and (hum.SeatPart.Name == "DriverSeat" or hum.SeatPart.Name == "GunSeat") then
		return
	end

	local interval = def.swingInterval or 0.6
	local now = time()
	local last = lastSwing[player]
	if last and now - last < interval then
		return
	end
	lastSwing[player] = now

	local range = def.meleeRange or 9
	local origin = root.Position
	local look = root.CFrame.LookVector

	-- nearest enemy within range that's in front of the swinger
	local best: Model? = nil
	local bestD = range
	local function consider(model: Instance)
		if not model:IsA("Model") or not model.Parent then
			return
		end
		if ((model:GetAttribute("HP") :: number?) or 0) <= 0 then
			return
		end
		local pp = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		if not pp then
			return
		end
		local delta = pp.Position - origin
		local d = delta.Magnitude
		if d > bestD then
			return
		end
		if d > 0.1 and look:Dot(delta.Unit) < 0.3 then
			return -- behind / off to the side → sword only hits in front
		end
		best, bestD = model, d
	end
	for _, m in CollectionService:GetTagged("Enemy") do
		consider(m)
	end
	for _, m in CollectionService:GetTagged("CampGuard") do
		consider(m)
	end

	if best then
		local before = (best:GetAttribute("HP") :: number?) or 0
		local after = math.max(0, before - (def.damage or 15))
		best:SetAttribute("HP", after)
		print(string.format("[Sword] HIT %s  HP %d -> %d%s", best.Name, before, after, if after <= 0 then "  (KILLED)" else ""))
	end
end)

Players.PlayerRemoving:Connect(function(p)
	lastSwing[p] = nil
end)
