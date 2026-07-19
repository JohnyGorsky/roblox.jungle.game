--!strict
-- ProfileConfig.luau — shared profile schema + migrations (Job 021).
-- Client-safe (no DataStore access here). IDENTICAL copy lives in sync/ and lobby/sync/ — one experience,
-- one DataStore. Keep the two byte-identical (they are copied, not hand-edited separately).

local ProfileConfig = {}

ProfileConfig.STORE_NAME = "PlayerProfiles_v1"
ProfileConfig.KEY_PREFIX = "Player_"
ProfileConfig.DATA_VERSION = 1

ProfileConfig.AUTOSAVE_INTERVAL = 60 -- seconds between heartbeat saves
ProfileConfig.LOCK_STALE_SECONDS = 90 -- steal a session lock older than this
ProfileConfig.LOAD_RETRIES = 5

ProfileConfig.GOLD_ATTRIBUTE = "Gold" -- server mirrors gold to this player attribute (auto-replicates)

-- A fresh profile. Stats mirror Job 020 §7.1 (the fields we already know we'll persist).
function ProfileConfig.default(): any
	return {
		dataVersion = ProfileConfig.DATA_VERSION,
		gold = 0,
		riverScore = 0, -- lifetime rank accumulator (filled by #026)
		modules = {}, -- owned boat modules: { [moduleId] = true } (Job 025)
		skills = {}, -- skill levels: { [skillId] = level 1..10 } (Job 024)
		-- retention (Job 028)
		lastLoginDay = 0, -- integer UTC day number of last daily-reward grant
		loginStreak = 0,
		weekId = 0, -- integer UTC week number the weekly objectives belong to
		weekly = { finish = 0, travel = 0, zone = 0 }, -- weekly objective progress
		weeklyClaimed = {}, -- { [objId] = true }
		purchaseIds = {}, -- granted developer-product PurchaseIds (idempotency) (Job 027)
		stats = {
			totalRuns = 0,
			runsFinished = 0,
			totalDistance = 0,
			bestDistance = 0,
			farthestZone = 0,
			enemiesKilled = 0,
			campsRaided = 0,
			revivesPerformed = 0,
			nightsSurvived = 0,
			totalGoldEarned = 0,
		},
	}
end

-- Bring a loaded value up to the current schema (forward-compatible: fill any missing field).
-- Returns a table (never nil). Preserves an existing `__lock` if present.
function ProfileConfig.migrate(data: any): any
	if type(data) ~= "table" then
		return ProfileConfig.default()
	end
	local def = ProfileConfig.default()
	if data.gold == nil then
		data.gold = def.gold
	end
	if data.riverScore == nil then
		data.riverScore = def.riverScore
	end
	if data.modules == nil then
		data.modules = {}
	end
	if data.skills == nil then
		data.skills = {}
	end
	if data.lastLoginDay == nil then
		data.lastLoginDay = 0
	end
	if data.loginStreak == nil then
		data.loginStreak = 0
	end
	if data.weekId == nil then
		data.weekId = 0
	end
	if type(data.weekly) ~= "table" then
		data.weekly = { finish = 0, travel = 0, zone = 0 }
	end
	if data.weeklyClaimed == nil then
		data.weeklyClaimed = {}
	end
	if data.purchaseIds == nil then
		data.purchaseIds = {}
	end
	data.stats = data.stats or {}
	for k, v in pairs(def.stats) do
		if data.stats[k] == nil then
			data.stats[k] = v
		end
	end
	data.dataVersion = ProfileConfig.DATA_VERSION
	return data
end

return ProfileConfig
