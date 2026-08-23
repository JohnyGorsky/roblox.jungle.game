--!strict
-- AdminServer.server.luau — allowlisted admin grants (Job 031). Supersedes the Studio-only DevGrant: works
-- live, grants to yourself OR a chosen player. EVERY action re-checks the allowlist server-side. Grants
-- persist via the profile. Actions are printed (simple audit). IDENTICAL copy in both trees.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
local AdminDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("AdminDefs")) :: any
local ModuleDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("ModuleDefs")) :: any
local SkillDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("SkillDefs")) :: any

local rf = Instance.new("RemoteFunction")
rf.Name = "Admin"
rf.Parent = ReplicatedStorage

rf.OnServerInvoke = function(plr: Player, action: string?, arg: any)
	if not AdminDefs.isAdmin(plr.UserId) then
		return { error = "denied" }
	end
	if action == "players" then
		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			list[#list + 1] = { name = p.DisplayName, userId = p.UserId }
		end
		return { players = list }
	elseif action == "give" then
		if typeof(arg) ~= "table" then
			return { error = "bad-arg" }
		end
		local target = Players:GetPlayerByUserId(arg.targetUserId)
		if not target or not Profiles.isReady(target) then
			return { error = "no-target" }
		end
		local kind = arg.kind
		local amount = tonumber(arg.amount) or 0
		if kind == "gold" then
			Profiles.addGold(target, amount)
		elseif kind == "score" then
			Profiles.addRiverScore(target, amount)
		elseif kind == "salvage" then
			target:SetAttribute("Salvage", ((target:GetAttribute("Salvage") :: number?) or 0) + amount)
		elseif kind == "allModules" then
			local prof = Profiles.get(target)
			if prof then
				for _, id in ipairs(ModuleDefs.Order) do
					prof.modules[id] = true
				end
			end
		elseif kind == "maxSkills" then
			local prof = Profiles.get(target)
			if prof then
				for _, id in ipairs(SkillDefs.Order) do
					prof.skills[id] = SkillDefs.MAX_LEVEL
				end
			end
		else
			return { error = "bad-kind" }
		end
		print(("[Admin] %s → %s: %s %s"):format(plr.Name, target.Name, tostring(kind), tostring(amount)))
		return { ok = true }
	elseif action == "tpFirstCamp" then
		-- ── self-teleport to the first landing's camp (game-only). Job 053, REWORKED Job #107 ────────
		--
		-- 🔴 THE CAMP MUST BE BUILT *AND* RENDERED WHEN YOU LAND, AND NEITHER IS FREE.
		--
		-- The old version was one `ForceFirstCamp:Invoke()` and a CFrame write, and from the spawn base
		-- it did nothing at all. Three separate reasons, all measured live:
		--
		--   1. THE CAMP CANNOT BUILD. `RiverBootstrap` keeps AHEAD_CHUNKS (7 ≈ 1800 studs) generated
		--      ahead of THE BOAT. Moored at z ≈ -270 that reaches z ≈ 1530; the first landing is at
		--      z = 1600 and `terrainReadyAt` samples 150 further still. `ForceFirstCamp` correctly
		--      REFUSES to build on terrain that does not exist and returns nil — the console says
		--      "river terrain never reached the first landing".
		--   2. EVEN IF BUILT, THE GROUND IS CULLED. That same window removes chunks outside
		--      [boat - BEHIND, boat + AHEAD], so a camp far from the boat has no terrain under it.
		--   3. THE CLIENT HAS NOT STREAMED IT. StreamingEnabled is on; arriving before the region
		--      streams means standing in an empty world for a second or more.
		--
		-- So the jump MOVES THE BOAT to the landing first — that is what drags the generation window
		-- along — then waits for the build, then pre-streams, then moves the player. Order matters.
		local ExcursionStorage = ServerStorage
		local forceCamp = ExcursionStorage:FindFirstChild("ForceFirstCamp")
		if not forceCamp then
			return { error = "no-forcecamp" } -- lobby tree, or ExcursionServer not up yet
		end

		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return { error = "no-char" }
		end

		local Workspace = game:GetService("Workspace")
		local RiverData = require(ReplicatedStorage:WaitForChild("River"):WaitForChild("RiverData")) :: any

		-- (a) find the first landing, so we know where to put the boat
		local first: any = nil
		for _, dock in RiverData.docksBetween(RiverData.Z_START, RiverData.Z_START + RiverData.END_DISTANCE) do
			if dock.landing then
				first = dock
				break
			end
		end
		if not first then
			return { error = "no-landing" }
		end

		-- (b) release the moor, or the boat sails itself home. Before the run starts a Heartbeat loop in
		-- StagingServer steers the hull back to its berth at up to 16 studs/s, which would drag the
		-- generation window back with it and un-generate the camp we are about to build.
		local startedRun = false
		if Workspace:GetAttribute("RunStarted") ~= true then
			local forceStart = ExcursionStorage:FindFirstChild("ForceStartRun")
			if forceStart then
				startedRun = (forceStart :: BindableFunction):Invoke() == true
			end
		end

		-- (c) move the boat into the channel at the landing. `RiverBootstrap` reads `Boat.Hull`, so the
		-- window follows from here. Velocity is zeroed: this is a physics assembly, and carrying the
		-- old momentum into a teleport is how you get a boat that keeps drifting after it arrives.
		local boat = Workspace:FindFirstChild("Boat")
		if boat and boat:IsA("Model") then
			local x = RiverData.centerlineX(first.z)
			local keep = boat:GetPivot().Y -- the hull's floating height, whatever buoyancy settled on
			boat:PivotTo(CFrame.new(x, keep, first.z))
			for _, d in ipairs(boat:GetDescendants()) do
				if d:IsA("BasePart") then
					d.AssemblyLinearVelocity = Vector3.zero
					d.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end

		-- (d) now the terrain can reach it — build, retrying while the generator catches up.
		-- `ForceFirstCamp` already polls internally for up to 30 s and refuses until terrain exists.
		local pos = (forceCamp :: BindableFunction):Invoke()
		if typeof(pos) ~= "Vector3" then
			return { error = "camp-not-built", startedRun = startedRun }
		end

		-- (e) RENDER IT before we arrive. Without this the admin lands in a region the client has not
		-- received yet. Best-effort: a failure here means a slower arrival, not a broken one.
		local streamed = pcall(function()
			plr:RequestStreamAroundAsync(pos :: Vector3, 10)
		end)

		root.CFrame = CFrame.new((pos :: Vector3) + Vector3.new(0, 3, 0))
		print(("[Admin] %s → first camp at %d,%d (run started: %s, pre-streamed: %s)"):format(
			plr.Name, math.floor((pos :: Vector3).X), math.floor((pos :: Vector3).Z),
			tostring(startedRun), tostring(streamed)))
		return { ok = true, startedRun = startedRun, streamed = streamed }
	end
	return { error = "bad-action" }
end

print("[Admin] panel server online (allowlisted)")
