--!strict
-- ⚠️⚠️ DEV ONLY (todo 0051) — DELETE THIS FILE BEFORE PUBLISH ⚠️⚠️
--
-- DevSpawnAtBoat.server.luau — drops you next to the moored boat on spawn, so boat work (Job #087)
-- doesn't cost a walk from the spawn base every single Play. Paired with `DEV_SKIP_INTRO` in
-- `Intro/PlaneServer.server.luau`; search the codebase for "todo 0051" to find every touched line.
--
-- ⚠️ Studio-only AND flag-gated, deliberately. `RunService:IsStudio()` is false on a published server,
-- so a live game cannot take this path even if the flag is left on. Same belt-and-braces pattern as
-- Defender's `USE_MOCK_IN_STUDIO`.

local ENABLED = true -- ⟵ set false to spawn normally without deleting the file

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if not (ENABLED and RunService:IsStudio()) then
	return
end

-- How far to the side of the mooring point to stand. The boat is 14 wide, so this clears the hull
-- and leaves you on the dock rather than inside the gunwale.
local SIDE_OFFSET = 12
local UP_OFFSET = 4

local spawnBase = Workspace:WaitForChild("SpawnBase", 20)
local dock = spawnBase and spawnBase:FindFirstChild("Dock")
local boatPlace = dock and dock:FindFirstChild("BoatPlace")
if not (boatPlace and boatPlace:IsA("BasePart")) then
	warn("[DevSpawnAtBoat] no SpawnBase.Dock.BoatPlace — spawning normally (todo 0051)")
	return
end

local place = boatPlace :: BasePart

local function placeCharacter(char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not (root and root:IsA("BasePart")) then
		return
	end
	-- Beside the mooring point rather than on it, so we never spawn inside the hull itself.
	local target = place.CFrame * CFrame.new(SIDE_OFFSET, UP_OFFSET, 0)
	-- A couple of frames of grace: the character is still being assembled and CharacterAdded fires
	-- before the humanoid has settled, so an immediate PivotTo can be undone by the spawn placement.
	task.defer(function()
		task.wait(0.2)
		if char.Parent then
			char:PivotTo(CFrame.lookAt(target.Position, place.Position))
		end
	end)
end

local function hook(plr: Player)
	plr.CharacterAdded:Connect(placeCharacter)
	if plr.Character then
		placeCharacter(plr.Character)
	end
end

Players.PlayerAdded:Connect(hook)
for _, plr in ipairs(Players:GetPlayers()) do
	hook(plr)
end

warn("[DevSpawnAtBoat] ⚠️ DEV spawn-at-boat is ON (todo 0051). Studio only; delete before publish.")
