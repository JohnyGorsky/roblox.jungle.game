--!strict
-- Footsteps.local.luau — material-aware footsteps for the lobby (Job 065, §12 juice rule).
--
-- The airfield is sand and the dock/stalls are wood, and the two should not sound alike. This reads the
-- material the character is actually standing on and picks `running_on_sand` or `footsteps_wood`
-- accordingly (ids from Theme.sound).
--
-- Runs on the LOCAL character and plays from the HumanoidRootPart, so the sound is positional for
-- nearby players too rather than a flat 2D click in one player's ears.
--
-- Deliberately simple: one looping sound whose SoundId swaps with the material, gated on the humanoid
-- actually running. That avoids scheduling a sound per step (which drifts out of sync with the
-- animation and burns instances) and costs one Sound object per character.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Theme"))

local character = script.Parent :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local root = character:WaitForChild("HumanoidRootPart") :: BasePart

-- Which material sounds like wood. Everything else falls back to the sand/gravel step, which suits the
-- airfield, the paths and the grass ring far better than a hard wooden knock.
local WOOD_MATERIALS: { [Enum.Material]: boolean } = {
	[Enum.Material.Wood] = true,
	[Enum.Material.WoodPlanks] = true,
}

local MIN_SPEED = 4 -- below this the character is shuffling, not travelling

local sound = Instance.new("Sound")
sound.Name = "Footsteps"
sound.Looped = true
sound.Volume = 0.35
sound.RollOffMode = Enum.RollOffMode.InverseTapered
sound.RollOffMinDistance = 6
sound.RollOffMaxDistance = 40
sound.SoundId = Theme.sound.runSand
sound.Parent = root

local currentId = sound.SoundId

local function desiredId(): string
	return WOOD_MATERIALS[humanoid.FloorMaterial] and Theme.sound.footstepWood or Theme.sound.runSand
end

local function update()
	local moving = humanoid.MoveDirection.Magnitude > 0
		and root.AssemblyLinearVelocity.Magnitude > MIN_SPEED
		and humanoid.FloorMaterial ~= Enum.Material.Air

	if not moving then
		if sound.IsPlaying then
			sound:Stop()
		end
		return
	end

	local wanted = desiredId()
	if wanted ~= currentId then
		currentId = wanted
		sound.SoundId = wanted
		sound.TimePosition = 0
		sound:Play() -- restart on the new surface rather than splicing mid-clip
	elseif not sound.IsPlaying then
		sound:Play()
	end
end

humanoid.Running:Connect(update)
humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(update)

-- Running/FloorMaterial alone miss the case where the player stops without either firing, so a light
-- poll closes the gap. 6 Hz is plenty for a footstep loop and costs nothing.
task.spawn(function()
	while character.Parent and humanoid.Health > 0 do
		update()
		task.wait(1 / 6)
	end
	sound:Stop()
end)

humanoid.Died:Connect(function()
	sound:Stop()
end)
