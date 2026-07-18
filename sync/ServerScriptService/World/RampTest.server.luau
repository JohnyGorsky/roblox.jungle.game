--!strict
-- RampTest.server.luau — TEST ramps to prove the boat can jump (Job 019).
--
-- Spawns a few greybox angled ramps in the channel ahead of the start so we can drive into them and see if
-- the boat launches. Ramps rise DOWNSTREAM (boat climbs the low upstream edge → launches off the high
-- downstream edge). DEV/TEST only — set DEV_RAMPS = false to remove. If jumping feels good, ramps become a
-- real obstacle feature later.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DEV_RAMPS = true -- ⟵ turn off to remove the test ramps

if not DEV_RAMPS then
	return
end

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local WATER_Y = RiverData.WATER_Y

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end

local root = Instance.new("Folder")
root.Name = "TestRamps"
root.Parent = Workspace

-- one ramp: a tilted slab rising downstream (+Z high). Low (upstream) edge sits under water so the boat
-- can climb onto it; high (downstream) edge is the launch lip.
local function buildRamp(z: number, angleDeg: number, color: Color3)
	local cx = RiverData.centerlineX(z)
	local WIDTH = 34
	local HEIGHT = 8 -- lip height above the thin edge (the launch height)
	local RUN = HEIGHT / math.tan(math.rad(angleDeg)) -- run for the requested angle
	-- WedgePart = a real ramp: zero-thickness leading EDGE the boat rides up (a thick tilted block is a
	-- wall the boat rams). Default wedge: full height at -Z, thin edge at +Z, slope faces +Z/up.
	-- The boat travels +Z (downstream), so rotate 180° about Y → thin edge faces UPSTREAM (-Z) where the
	-- boat enters, rising to the full-height lip downstream (+Z).
	local ramp = Instance.new("WedgePart")
	ramp.Name = ("Ramp_%ddeg"):format(angleDeg)
	ramp.Anchored = true
	ramp.Size = Vector3.new(WIDTH, HEIGHT, RUN)
	ramp.Color = color
	ramp.Material = Enum.Material.Metal
	-- base sits ~2 below the waterline so the thin leading edge is under the hull → hull rides up the slope
	local baseY = WATER_Y - 2
	ramp.CFrame = CFrame.new(cx, baseY + HEIGHT / 2, z) * CFrame.Angles(0, math.rad(180), 0)
	ramp.Parent = root

	-- a small label so you can tell which angle is which
	local sign = Instance.new("Part")
	sign.Anchored = true
	sign.CanCollide = false
	sign.Transparency = 1
	sign.Size = Vector3.one
	sign.CFrame = CFrame.new(cx, baseY + HEIGHT + 3, z)
	sign.Parent = ramp
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(6, 3)
	bb.AlwaysOnTop = true
	bb.Parent = sign
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 0.3
	lbl.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	lbl.Text = angleDeg .. "°"
	lbl.Parent = bb
end

buildRamp(RiverData.Z_START + 170, 10, Color3.fromRGB(90, 180, 90))
buildRamp(RiverData.Z_START + 300, 20, Color3.fromRGB(210, 190, 70))
buildRamp(RiverData.Z_START + 440, 35, Color3.fromRGB(210, 110, 70))

print("[RampTest] spawned test ramps at 10° / 20° / 35° (DEV_RAMPS)")
