--!strict
-- RampTest.server.luau — TEST ramps / jump-pads to prove the boat can jump (Job 019).
--
-- A heavy, buoyant, level-controlled boat can't physically CLIMB a solid ramp (it jams/stalls), so the
-- ramps are NON-COLLIDING trigger zones: drive over one at speed → we APPLY the launch directly (upward
-- LINEAR velocity + an ANGULAR nose-over flip) and open a LaunchUntil window so BoatServer stops fighting
-- the arc. Launch scales with the ramp's angle. Heavy logging so we can see exactly what fires.
-- DEV/TEST only — set DEV_RAMPS = false to remove.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEV_RAMPS = true -- ⟵ turn off to remove the test ramps

if not DEV_RAMPS then
	return
end

local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData"))
local WATER_Y = RiverData.WATER_Y

-- launch tuning (Roblox gravity ~196 → v studs/s clears ~v²/392 studs; launch hard)
local LAUNCH_BASE = 40 -- upward launch off any ramp (studs/s)
local LAUNCH_PER_DEG = 1.6 -- extra upward per degree of ramp angle
local LAUNCH_MAX = 95 -- cap (studs/s) — ~95 ≈ a ~23-stud peak
local FLIP_RATE = 0.5 -- gentle angular nose-UP off the ramp (rad/s); NOT a somersault
local MIN_SPEED = 6 -- need this forward speed to trigger a launch
local ARC_TIME = 0.6 -- seconds BoatServer keeps leveling off; then it re-levels to catch the landing
local DEBOUNCE = 2.5 -- seconds before the same ramp can launch again

if not Workspace:GetAttribute("RiverReady") then
	Workspace:GetAttributeChangedSignal("RiverReady"):Wait()
end

local root = Instance.new("Folder")
root.Name = "TestRamps"
root.Parent = Workspace

type Ramp = { part: WedgePart, z: number, angle: number, width: number, run: number }
local ramps: { Ramp } = {}

local function buildRamp(z: number, angleDeg: number, color: Color3)
	local cx = RiverData.centerlineX(z)
	local WIDTH = 34
	local HEIGHT = 8
	local RUN = HEIGHT / math.tan(math.rad(angleDeg))
	local ramp = Instance.new("WedgePart")
	ramp.Name = ("Ramp_%ddeg"):format(angleDeg)
	ramp.Anchored = true
	ramp.CanCollide = false -- NON-COLLIDING: drive through it (no jam); it's a launch trigger + visual
	ramp.Size = Vector3.new(WIDTH, HEIGHT, RUN)
	ramp.Color = color
	ramp.Transparency = 0.25
	ramp.Material = Enum.Material.Neon
	ramp.CFrame = CFrame.new(cx, WATER_Y - 2 + HEIGHT / 2, z)
	ramp.Parent = root

	local sign = Instance.new("Part")
	sign.Anchored = true
	sign.CanCollide = false
	sign.Transparency = 1
	sign.Size = Vector3.one
	sign.CFrame = CFrame.new(cx, WATER_Y + HEIGHT + 3, z)
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
	lbl.Text = angleDeg .. "° JUMP"
	lbl.Parent = bb

	table.insert(ramps, { part = ramp, z = z, angle = angleDeg, width = WIDTH, run = RUN })
end

buildRamp(RiverData.Z_START + 170, 10, Color3.fromRGB(90, 180, 90))
buildRamp(RiverData.Z_START + 300, 20, Color3.fromRGB(210, 190, 70))
buildRamp(RiverData.Z_START + 440, 35, Color3.fromRGB(210, 110, 70))

print("[RampTest] non-colliding jump-pads at 10°/20°/35° online (drive over them)")

-- ── launch loop: when the boat drives over a ramp footprint at speed, apply the launch ──────────────
local boat = Workspace:WaitForChild("Boat", 30)
local hull = boat and boat:WaitForChild("Hull", 10) :: BasePart?
if not hull then
	warn("[RampTest] no boat hull — launch loop not started")
	return
end

local lastLaunch: { [Ramp]: number } = {}

RunService.Heartbeat:Connect(function()
	if not hull or not hull.Parent then
		return
	end
	local p = hull.Position
	local look = hull.CFrame.LookVector
	local vel = hull.AssemblyLinearVelocity
	local fwd = vel:Dot(look)
	for _, r in ipairs(ramps) do
		local cx = RiverData.centerlineX(r.z)
		local inFootprint = math.abs(p.X - cx) <= r.width / 2 + 3
			and math.abs(p.Z - r.z) <= r.run / 2 + 4
			and p.Y < WATER_Y + r.run -- not way above it
		local ready = (os.clock() - (lastLaunch[r] or -100)) > DEBOUNCE
		if inFootprint and ready and fwd > MIN_SPEED then
			lastLaunch[r] = os.clock()
			local launchUp = math.min(LAUNCH_BASE + r.angle * LAUNCH_PER_DEG, LAUNCH_MAX)
			-- LINEAR: keep the boat's horizontal velocity, set a strong upward launch
			hull.AssemblyLinearVelocity = Vector3.new(vel.X, launchUp, vel.Z)
			-- ANGULAR: a gentle nose-UP off the ramp (negative right axis), NOT a somersault
			hull.AssemblyAngularVelocity = -hull.CFrame.RightVector * FLIP_RATE
			-- tell BoatServer to stop fighting the arc for a moment
			boat:SetAttribute("LaunchUntil", os.clock() + ARC_TIME)
			print(("[RampTest] LAUNCH %d° pad: fwdSpeed=%.1f → launchUp=%.1f, flip=%.1f rad/s")
				:format(r.angle, fwd, launchUp, FLIP_RATE))
		end
	end
end)
