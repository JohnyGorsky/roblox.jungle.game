--!strict
-- AdminServer.server.luau — allowlisted admin grants (Job 031). Supersedes the Studio-only DevGrant: works
-- live, grants to yourself OR a chosen player. EVERY action re-checks the allowlist server-side. Grants
-- persist via the profile. Actions are printed (simple audit).
--
-- ⚠️ THE HEADER USED TO SAY "IDENTICAL copy in both trees". IT WAS NOT TRUE, and Job #117 corrected it
-- rather than leaving a claim that invites someone to "restore" byte-identity by copying one over the
-- other. The GAME copy carries ~280 lines the lobby place cannot support — `tpFirstCamp` (Job #107),
-- `tpEndBase` (Job #114) and the Job #112 cheat toggles all need `Workspace.EndBase`, the boat, or the
-- run. What MUST stay in step is the SHARED GRANTS: gold, river score, salvage, modules, skills, and the
-- Job #117 `m16Charge`. Never copy either file over the other wholesale.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Profiles = require(ServerScriptService:WaitForChild("Progression"):WaitForChild("Profiles")) :: any
local AdminDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("AdminDefs")) :: any
local ModuleDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("ModuleDefs")) :: any
local SkillDefs = require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("SkillDefs")) :: any
-- Job #117. ⚠️ GAME TREE ONLY — `ServerStorage` is not mapped in `lobby/default.project.json`, so the
-- lobby copy of this file must never require it. Server-side `require` is cached, so this is the SAME
-- module instance `InventoryServer` and `ExcursionServer` use, not a second copy with its own state.
local InventoryService = require(ServerStorage:WaitForChild("Inventory"):WaitForChild("InventoryService"))
local ItemDefs = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("ItemDefs"))

local rf = Instance.new("RemoteFunction")
rf.Name = "Admin"
rf.Parent = ReplicatedStorage

-- ── cheat toggles (Job #112) ─────────────────────────────────────────────────────────────────────
-- Three dev switches so a run can be driven end to end without dying or refuelling. All three are
-- STATE, not one-shot grants, so they read back as well as write — the panel labels itself ON/OFF.
--
-- Where each one is enforced matters more than where it is stored:
--   · godPlayer   → stamps `InvincibleUntil`, the attribute BOTH damage paths already check
--                   (`EnemyServer` target selection, `ExcursionServer.tickGuard`). Inventing a second
--                   flag would mean editing every damage path to honour it — PlayerCombat's own comment
--                   warns about exactly that. The loop also tops HP/Health back up, which covers the
--                   things `InvincibleUntil` does not: falling, drowning, and anything writing Health.
--   · godBoat     → `Boat.AdminGodBoat`, enforced inside BoatServer's own HP-changed handler.
--   · infiniteFuel→ `Boat.AdminInfiniteFuel`, enforced in BoatServer's drain.
local function theBoat(): Instance?
	return Workspace:FindFirstChild("Boat")
end

local godStamp: { [Model]: number } = {}
local godRunning: { [Player]: boolean } = {}

local function runGodLoop(target: Player)
	if godRunning[target] then
		return
	end
	godRunning[target] = true
	task.spawn(function()
		while target.Parent and target:GetAttribute("AdminGod") == true do
			local char = target.Character
			if char then
				-- Re-stamped every tick rather than set once to a huge number, so turning the toggle OFF
				-- takes effect within a couple of seconds even if the clear below is somehow missed.
				local deadline = Workspace:GetServerTimeNow() + 8
				char:SetAttribute("InvincibleUntil", deadline)
				godStamp[char] = deadline
				char:SetAttribute("AdminGod", true) -- DownedHud reads this to suppress its countdown chip
				local maxHP = (char:GetAttribute("MaxHP") :: number?) or 100
				if ((char:GetAttribute("HP") :: number?) or maxHP) < maxHP then
					char:SetAttribute("HP", maxHP)
				end
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum and hum:IsA("Humanoid") and hum.Health < hum.MaxHealth then
					hum.Health = hum.MaxHealth
				end
			end
			task.wait(0.25)
		end
		godRunning[target] = nil
		local char = target.Character
		if char then
			char:SetAttribute("AdminGod", nil)
			-- Only clear a deadline WE stamped — the same guard PlayerCombat and EscapeServer use, so
			-- switching god mode off does not cancel a revive grace that is legitimately running.
			if godStamp[char] and char:GetAttribute("InvincibleUntil") == godStamp[char] then
				char:SetAttribute("InvincibleUntil", nil)
			end
			godStamp[char] = nil
		end
	end)
end

local function cheatState(target: Player?): { [string]: boolean }
	local b = theBoat()
	return {
		godPlayer = target ~= nil and target:GetAttribute("AdminGod") == true,
		godBoat = b ~= nil and b:GetAttribute("AdminGodBoat") == true,
		infiniteFuel = b ~= nil and b:GetAttribute("AdminInfiniteFuel") == true,
	}
end

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
		elseif kind == "m16" then
			-- Job #117: the immediate grant — the gun in your hands now, for testing the BURST.
			-- Sibling of `m16Charge` below, which tests the PURCHASE path instead. Deliberately bypasses
			-- `Granted_m16` (the shop's "already had it this run" flag) so it can be pressed repeatedly to
			-- top the rounds back up mid-test.
			if not InventoryService.grant(target, "M16") then
				return { error = "loadout-full" }
			end
			local def = ItemDefs.get("M16")
			if def and def.ammoAttr then
				local want = if amount > 0 then amount else (def.ammoOnLoot or 30)
				if ((target:GetAttribute(def.ammoAttr) :: number?) or 0) < want then
					target:SetAttribute(def.ammoAttr, want)
				end
			end
		elseif kind == "bazooka" then
			-- Job #118: the immediate grant — the launcher in your hands now, for testing the FLIGHT, the
			-- ring, the blast and the 5 s reload. Same shape as `m16` above and the same deliberate
			-- bypass of `Granted_bazooka`, so it can be pressed repeatedly to top the rockets back up.
			if not InventoryService.grant(target, "Bazooka") then
				return { error = "loadout-full" }
			end
			local def = ItemDefs.get("Bazooka")
			if def and def.ammoAttr then
				local want = if amount > 0 then amount else (def.ammoOnLoot or 6)
				if ((target:GetAttribute(def.ammoAttr) :: number?) or 0) < want then
					target:SetAttribute(def.ammoAttr, want)
				end
			end
		elseif kind == "bazookaCharge" then
			-- Job #118: bank a per-run Bazooka charge, exactly as an 80 R$ receipt would. Present in BOTH
			-- trees for the reason `m16Charge` documents below — banking it in the lobby and then
			-- launching is the half of the feature that no Studio purchase can ever exercise.
			Profiles.addRunGrant(target, "bazooka", math.max(1, amount))
		elseif kind == "m16Charge" then
			-- Job #117: bank a per-run M16 charge, exactly as a 30 R$ receipt would.
			--
			-- ⚠️ THIS EXISTS BECAUSE THE PURCHASE PATH CANNOT BE TESTED. `Profiles.recordPurchase` refuses
			-- unless `Profiles.isPersisting` is true, and `MarketplaceService` prompts never complete in
			-- Studio at all — so without this button the whole lobby → run half of the feature (buy a
			-- charge here, receive the gun over there) would ship having never once been exercised.
			-- SHARED, therefore, and present in both trees: banking it in the LOBBY and then launching is
			-- precisely the path that needs proving.
			Profiles.addRunGrant(target, "m16", math.max(1, amount))
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
	elseif action == "tpEndBase" then
		-- ── self-teleport to the END ZONE's bunker spawn (game-only). Job #114 ───────────────────────
		--
		-- Sibling of `tpFirstCamp` above and deliberately a fraction of its length, because the thing
		-- that makes that jump hard does not apply here: WHO OWNS THE GROUND. A camp is built on river
		-- terrain that only exists inside the boat's generation window, so that jump has to move the boat
		-- downstream first. The end zone is hand-built editor content past `RiverData.END_ZONE_Z_START`
		-- (18 000) — its terrain, its bunker and its runway are in the place file, never generated and
		-- never culled. So: no boat move, no build, no retry loop.
		--
		-- Three things DO still have to happen, and all three have been got wrong before:
		--   1. THE RUN MUST BE RUNNING or the pad you came to test is inert — `EscapeServer`'s occupancy
		--      loop only counts crew while `RunStarted` is set and `RunEnded` is not.
		--   2. LEAVE THE SEAT FIRST. Before the run starts an admin is usually in the driver's seat, and
		--      a seated character is WELDED to the boat: the CFrame write below moves nothing and the
		--      button reads as broken.
		--   3. PRE-STREAM. StreamingEnabled is on and this is ~18 000 studs from anywhere the client has
		--      loaded, so ask for the region before arriving in it.
		local endBase = Workspace:FindFirstChild("EndBase")
		if not endBase then
			return { error = "no-endbase" } -- lobby tree: there is no end zone there
		end
		-- BY NAME, recursively — the same contract every other editor-placed fitting in this game uses
		-- (`EscapeServer` finds its own `Escape` marker exactly this way), so re-parenting the marker
		-- inside `EndBase` while dressing the scene does not break the jump.
		local marker = endBase:FindFirstChild("SpawnPoint2", true)
		if not (marker and marker:IsA("BasePart")) then
			return { error = "no-spawnpoint" }
		end
		local markerPart = marker :: BasePart

		local char = plr.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return { error = "no-char" }
		end

		local startedRun = false
		if Workspace:GetAttribute("RunStarted") ~= true then
			local forceStart = ServerStorage:FindFirstChild("ForceStartRun")
			if forceStart then
				-- Also releases the moor, so StagingServer stops steering the empty hull back to its berth.
				startedRun = (forceStart :: BindableFunction):Invoke() == true
			end
		end

		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum:IsA("Humanoid") and hum.SeatPart then
			hum.Sit = false
			task.wait(0.1) -- let the SeatWeld actually go before we move the root
		end

		-- Seat the arrival on what is UNDER the marker rather than at the marker's own Y: it is an
		-- invisible 4x1x2 nub, and the same mistake in `EscapeServer` (trusting the marker's height) is
		-- what buried that pad in the runway slab. Measured 2026-08-25: marker y 18.5, Terrain y 18.0.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local filter: { Instance } = { markerPart }
		if char then
			filter[#filter + 1] = char -- our own body, or the cast lands on us
		end
		params.FilterDescendantsInstances = filter
		params.IgnoreWater = true
		local landing = markerPart.Position
		local hit = Workspace:Raycast(landing + Vector3.new(0, 60, 0), Vector3.new(0, -400, 0), params)
		if hit then
			landing = Vector3.new(landing.X, hit.Position.Y, landing.Z)
		end
		local dest = landing + Vector3.new(0, 4, 0)

		-- Best-effort: a failure here means a slower arrival, not a broken one.
		local streamed = pcall(function()
			plr:RequestStreamAroundAsync(dest, 10)
		end)

		root.CFrame = CFrame.new(dest)
		print(("[Admin] %s → end zone at %d,%d,%d (run started: %s, pre-streamed: %s)"):format(
			plr.Name, math.floor(dest.X), math.floor(dest.Y), math.floor(dest.Z),
			tostring(startedRun), tostring(streamed)))
		return { ok = true, startedRun = startedRun, streamed = streamed }
	elseif action == "cheats" then
		-- read-back so the panel can label its toggles the moment it opens
		local target = typeof(arg) == "table" and Players:GetPlayerByUserId(arg.targetUserId) or plr
		return { ok = true, state = cheatState(target or plr) }
	elseif action == "cheat" then
		if typeof(arg) ~= "table" then
			return { error = "bad-arg" }
		end
		local kind = arg.kind
		local on = arg.on == true
		local target = Players:GetPlayerByUserId(arg.targetUserId) or plr
		if kind == "godPlayer" then
			target:SetAttribute("AdminGod", on or nil)
			if on then
				runGodLoop(target)
			end
		elseif kind == "godBoat" or kind == "infiniteFuel" then
			local b = theBoat()
			if not b then
				return { error = "no-boat" }
			end
			b:SetAttribute(kind == "godBoat" and "AdminGodBoat" or "AdminInfiniteFuel", on or nil)
			if on and kind == "infiniteFuel" then
				b:SetAttribute("Fuel", (b:GetAttribute("MaxFuel") :: number?) or 100)
			end
			if on and kind == "godBoat" then
				b:SetAttribute("HP", (b:GetAttribute("MaxHP") :: number?) or 100)
			end
		else
			return { error = "bad-kind" }
		end
		print(("[Admin] %s → cheat %s = %s (target %s)"):format(plr.Name, tostring(kind), tostring(on), target.Name))
		return { ok = true, state = cheatState(target) }
	end
	return { error = "bad-action" }
end

print("[Admin] panel server online (allowlisted)")
