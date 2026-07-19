--!strict
-- Profiles.luau — session-locked DataStore profile service (Job 021). SERVER ONLY.
-- A simplified ProfileStore: one DataStore value per player holding {gold, riverScore, stats, __lock}.
-- All access via UpdateAsync (atomic; the transform never yields). Session lock prevents dupes/rollbacks
-- across the lobby<->game teleport. IDENTICAL copy in sync/ and lobby/sync/ (same experience/DataStore).
--
-- Public API (all take a Player):
--   Profiles.load(p)            -- call on PlayerAdded; loads or creates + acquires the lock
--   Profiles.save(p, release)   -- heartbeat (release=false) or final save+unlock (release=true)
--   Profiles.unload(p)          -- drop the in-memory cache entry
--   Profiles.isReady(p)         -- true once load finished (real or fallback)
--   Profiles.get(p)             -- the raw in-memory data table (or nil)
--   Profiles.getGold(p) / addGold(p, n) / trySpendGold(p, n)

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileConfig =
	require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("ProfileConfig")) :: any

local Profiles = {}

local store: DataStore = DataStoreService:GetDataStore(ProfileConfig.STORE_NAME)

type Entry = {
	data: any,
	session: string,
	owned: boolean, -- we hold the session lock and may save
	ready: boolean, -- load finished (real or fallback)
	fallback: boolean, -- load failed; in-memory only, never saved
}

local cache: { [Player]: Entry } = {}

local function keyOf(player: Player): string
	return ProfileConfig.KEY_PREFIX .. tostring(player.UserId)
end

-- One UpdateAsync transaction. mode = "load" | "beat" | "release".
-- Returns (ok, data, err). err ∈ {"locked","lost", nil}.
local function transact(player: Player, mode: string): (boolean, any, string?)
	local entry = cache[player]
	local session = (entry and entry.session) or ""
	local key = keyOf(player)
	local outData: any = nil
	local outErr: string? = nil

	local ok = pcall(function()
		store:UpdateAsync(key, function(old)
			local data = ProfileConfig.migrate(old) -- old may be nil -> a fresh default
			local lock = data.__lock

			if mode == "load" then
				if lock and lock.session ~= session then
					local age = os.time() - (lock.heartbeat or 0)
					if age < ProfileConfig.LOCK_STALE_SECONDS then
						outErr = "locked" -- another live session owns it; cancel and retry
						return nil
					end
					-- stale lock -> steal it
				end
				data.__lock = { session = session, heartbeat = os.time() }
				outData = data
				return data
			elseif mode == "beat" or mode == "release" then
				-- write our authoritative in-memory data; never clobber a live owner that stole the lock
				if lock and lock.session ~= session then
					local age = os.time() - (lock.heartbeat or 0)
					if age < ProfileConfig.LOCK_STALE_SECONDS then
						outErr = "lost"
						return nil
					end
				end
				local mem = (entry and entry.data) or data
				if mode == "release" then
					mem.__lock = nil
				else
					mem.__lock = { session = session, heartbeat = os.time() }
				end
				outData = mem
				return mem
			end
			return nil
		end)
	end)

	return ok, outData, outErr
end

function Profiles._publish(player: Player)
	local entry = cache[player]
	if not entry then
		return
	end
	local gold = entry.data.gold or 0
	player:SetAttribute(ProfileConfig.GOLD_ATTRIBUTE, gold)
	player:SetAttribute("RiverScore", entry.data.riverScore or 0) -- rank source (Job 026)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local g = ls:FindFirstChild("Gold")
		if g and g:IsA("IntValue") then
			g.Value = gold
		end
	end
end

function Profiles.load(player: Player): Entry?
	if cache[player] then
		return cache[player] -- already loading/loaded (guards double PlayerAdded/catch-up)
	end
	local session = HttpService:GenerateGUID(false)
	cache[player] =
		{ data = ProfileConfig.default(), session = session, owned = false, ready = false, fallback = false }

	local loaded, data: any, lastErr: string? = false, nil, nil
	for attempt = 1, ProfileConfig.LOAD_RETRIES do
		if not player.Parent then
			cache[player] = nil
			return nil -- left before load finished
		end
		local ok, d, err = transact(player, "load")
		if err then
			lastErr = err
		elseif not ok then
			lastErr = "datastore-error"
		else
			lastErr = nil
		end
		if ok and d then
			loaded, data = true, d
			break
		elseif err == "locked" then
			task.wait(0.5 * (2 ^ attempt)) -- wait for the other session to release
		else
			task.wait(1) -- transient DataStore failure
		end
	end

	local entry = cache[player]
	if not entry then
		return nil
	end
	if loaded and data then
		entry.data = data
		entry.owned = true
		entry.ready = true
	else
		-- Studio without API access, or a stuck lock: run on an in-memory profile that is NEVER saved.
		entry.fallback = true
		entry.ready = true
		warn(
			("[Profiles] load failed for %s (%s) — in-memory fallback, will NOT save"):format(
				player.Name,
				tostring(lastErr)
			)
		)
	end
	Profiles._publish(player)
	return entry
end

function Profiles.save(player: Player, release: boolean): boolean
	local entry = cache[player]
	if not entry or not entry.owned or entry.fallback then
		return false
	end
	local ok, _, err = transact(player, release and "release" or "beat")
	if not ok then
		warn(("[Profiles] save error for %s"):format(player.Name))
	elseif err == "lost" then
		warn(("[Profiles] lost session lock for %s — halting saves"):format(player.Name))
		entry.owned = false
	elseif release then
		entry.owned = false
	end
	return ok
end

function Profiles.unload(player: Player)
	cache[player] = nil
end

function Profiles.isReady(player: Player): boolean
	local e = cache[player]
	return e ~= nil and e.ready
end

function Profiles.get(player: Player): any
	local e = cache[player]
	return e and e.data or nil
end

function Profiles.getGold(player: Player): number
	local e = cache[player]
	return (e and e.data.gold) or 0
end

-- Add (or with a negative amount, subtract-with-floor) gold. Returns the new balance.
function Profiles.addGold(player: Player, amount: number): number
	local e = cache[player]
	if not e then
		return 0
	end
	e.data.gold = math.max(0, (e.data.gold or 0) + amount)
	if amount > 0 then
		e.data.stats.totalGoldEarned = (e.data.stats.totalGoldEarned or 0) + amount
	end
	Profiles._publish(player)
	return e.data.gold
end

function Profiles.getRiverScore(player: Player): number
	local e = cache[player]
	return (e and e.data.riverScore) or 0
end

-- Add to the lifetime River Score (rank). Never decreases. Returns the new total.
function Profiles.addRiverScore(player: Player, amount: number): number
	local e = cache[player]
	if not e then
		return 0
	end
	e.data.riverScore = math.max(0, (e.data.riverScore or 0) + math.max(0, amount))
	Profiles._publish(player)
	return e.data.riverScore
end

-- Spend gold only if affordable. Returns true on success.
function Profiles.trySpendGold(player: Player, amount: number): boolean
	local e = cache[player]
	if not e or (e.data.gold or 0) < amount then
		return false
	end
	e.data.gold -= amount
	Profiles._publish(player)
	return true
end

return Profiles
