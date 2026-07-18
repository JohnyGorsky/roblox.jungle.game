--!strict
-- RiverBootstrap.server.luau — owns the live river (Job 005).
--
-- On server start: clear old terrain, seed the river, generate the opening stretch, then signal
-- "RiverReady" so the boat spawns onto real water. Thereafter it STREAMS: generate chunks ahead of
-- the boat, cull chunks behind (mobile memory budget), and place the finish line at END_DISTANCE.
-- Publishes BoatDistance / RiverEndDistance attributes for a future HUD.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local RiverGenerator = require(ServerScriptService:WaitForChild("River"):WaitForChild("RiverGenerator"))

-- ── config ─────────────────────────────────────────────────────────────────
local AHEAD_CHUNKS = 7   -- chunks kept generated ahead of the boat (~1800 studs)
local BEHIND_CHUNKS = 2  -- chunks kept behind before culling
local TICK = 0.15        -- streaming update period (s)
-- ───────────────────────────────────────────────────────────────────────────

local CHUNK_LEN = RiverGenerator.CHUNK_LEN
local MAX_CHUNK = math.floor(RiverData.END_DISTANCE / CHUNK_LEN)

-- seed: a Workspace attribute if set (daily/shared seed later), else a stable dev default
local seed = Workspace:GetAttribute("RiverSeed") :: number?
RiverData.setSeed(if seed then seed else 2026)

local generated: { [number]: boolean } = {}

-- greybox obstacle/ramp markers (real props come later), streamed with their chunk
local hooksRoot = Instance.new("Folder")
hooksRoot.Name = "RiverHooks"
hooksRoot.Parent = Workspace

local function placeHooks(index: number)
	if hooksRoot:FindFirstChild("Chunk_" .. index) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Chunk_" .. index
	local zMin = RiverData.Z_START + index * CHUNK_LEN
	for _, h in ipairs(RiverData.hooksBetween(zMin, zMin + CHUNK_LEN - 1)) do
		local isRamp = h.kind == "ramp"
		local p = Instance.new("Part")
		p.Name = "Hook_" .. h.kind
		p.Anchored = true
		p.CanCollide = false
		p.Material = Enum.Material.Neon
		p.Transparency = 0.4
		p.Size = if isRamp then Vector3.new(30, 6, 22) else Vector3.new(12, 12, 12)
		p.Position = Vector3.new(h.x, RiverData.WATER_Y + (if isRamp then 1 else 4), h.z)
		p.Color = if isRamp then Color3.fromRGB(90, 220, 120) else Color3.fromRGB(225, 80, 70)
		p:SetAttribute("HookKind", h.kind)
		p.Parent = folder
	end
	folder.Parent = hooksRoot
end

local function clearHooks(index: number)
	local folder = hooksRoot:FindFirstChild("Chunk_" .. index)
	if folder then
		folder:Destroy()
	end
end

local function ensureChunk(index: number)
	if index < 0 or index > MAX_CHUNK or generated[index] then
		return
	end
	RiverGenerator.generateChunk(index)
	placeHooks(index)
	generated[index] = true
end

local function cullChunk(index: number)
	if generated[index] then
		RiverGenerator.clearChunk(index)
		clearHooks(index)
		generated[index] = nil
	end
end

-- finish line: a bright marker spanning the channel at END_DISTANCE (greybox — real end set-piece at P9)
local endPlaced = false
local function placeEnd()
	if endPlaced or RiverData.ENDLESS then
		return
	end
	endPlaced = true
	local z = RiverData.distanceToWorldZ(RiverData.END_DISTANCE)
	local pos = RiverData.positionAt(z)
	local bar = Instance.new("Part")
	bar.Name = "FinishLine"
	bar.Anchored = true
	bar.CanCollide = false
	bar.Size = Vector3.new(RiverData.widthAt(z) + 40, 24, 4)
	bar.Position = pos + Vector3.new(0, 10, 0)
	bar.Color = Color3.fromRGB(255, 215, 0)
	bar.Material = Enum.Material.Neon
	bar.Transparency = 0.3
	bar.CFrame = CFrame.lookAt(bar.Position, bar.Position + RiverData.tangentAtZ(z))
	bar.Parent = Workspace
end

-- ── boot: clear, generate the opening stretch, signal ready ─────────────────
Workspace.Terrain:Clear()
Workspace:SetAttribute("RiverEndDistance", RiverData.END_DISTANCE)
Workspace:SetAttribute("BoatDistance", 0)
for i = 0, AHEAD_CHUNKS do
	ensureChunk(i)
end
Workspace:SetAttribute("RiverReady", true)

-- ── stream with the boat ────────────────────────────────────────────────────
while true do
	local boat = Workspace:FindFirstChild("Boat")
	local hull = boat and boat:FindFirstChild("Hull") :: BasePart?
	if hull then
		local dist = RiverData.worldToDistance(hull.Position.Z)
		Workspace:SetAttribute("BoatDistance", math.max(0, math.floor(dist)))
		local cur = math.floor(dist / CHUNK_LEN)

		-- generate the nearest missing chunk ahead (one per tick to spread the cost)
		for i = cur, cur + AHEAD_CHUNKS do
			if i >= 0 and i <= MAX_CHUNK and not generated[i] then
				ensureChunk(i)
				break
			end
		end

		-- cull anything outside the live window
		for index in pairs(generated) do
			if index < cur - BEHIND_CHUNKS or index > cur + AHEAD_CHUNKS then
				cullChunk(index)
			end
		end

		-- finish line once its chunk is in view
		if cur >= MAX_CHUNK - AHEAD_CHUNKS then
			placeEnd()
		end
	end
	task.wait(TICK)
end
