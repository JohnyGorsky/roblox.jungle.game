--!strict
-- ProfileConfig.luau — shared profile schema + migrations (Job 021).
-- Client-safe (no DataStore access here). IDENTICAL copy lives in sync/ and lobby/sync/ — one experience,
-- one DataStore. Keep the two byte-identical (they are copied, not hand-edited separately).

local RunService = game:GetService("RunService")

local ProfileConfig = {}

-- Job 085: separate EDITOR (Studio) saves from LIVE (published) saves. Until now both wrote to the
-- same store, so every playtest mutated the records real players would load.
--
-- The store name IS the save id: a new name is an empty store, so everyone loads as a brand-new
-- player, and switching the name back restores the previous save set (the old store is left intact).
-- To wipe live later, bump STORE_NAME_LIVE (_v1 -> _v2); dev data is never touched by that.
--
-- `RunService:IsStudio()` is true in any Studio playtest (solo, Team Test, Play Here) and false on a
-- live server, and answers the same on client and server — so the lobby and game places always agree.
-- Keeping the pick here rather than at the call site means `Profiles.luau` needs no change.
-- ⚠️ Job 089 renamed BOTH stores, because ProfileStore's on-disk shape is not the Job 021 format.
-- A key written by the old hand-rolled service ({gold, riverScore, __lock, ...} at the top level) is
-- not a ProfileStore profile, and pointing ProfileStore at one would trip its OnOverwrite guard.
-- Fresh names guarantee no key is ever read in the wrong format. Both old stores are left intact.
--   · DEV  — starts empty by decision (Job 089, Q2). Re-grant test progress with AdminServer; the
--            upside is that the brand-new-player path gets exercised on every fresh test.
--   · LIVE — the Job 085 live store was created empty and the experience is still Private, so there
--            was nothing to migrate. Renaming it costs nothing and removes the last legacy-format risk.
ProfileConfig.STORE_NAME_DEV = "PlayerProfiles_ps_v1" -- Studio testing (ProfileStore format)
ProfileConfig.STORE_NAME_LIVE = "PlayerProfiles_live_ps_v1" -- published game (ProfileStore format)
ProfileConfig.STORE_NAME = if RunService:IsStudio()
	then ProfileConfig.STORE_NAME_DEV
	else ProfileConfig.STORE_NAME_LIVE
ProfileConfig.KEY_PREFIX = "Player_"
ProfileConfig.DATA_VERSION = 1

-- ⛔ AUTOSAVE_INTERVAL / LOCK_STALE_SECONDS / LOAD_RETRIES were DELETED in Job 089. They configured the
-- hand-rolled session lock, and ProfileStore owns all three concerns now (300 s autosave, its own
-- conflict resolution, its own retry/timeout). Leaving them here would be three constants that look
-- like tuning knobs and control nothing. Tune ProfileStore via `ProfileStore.SetConstant` instead.

ProfileConfig.GOLD_ATTRIBUTE = "Gold" -- server mirrors gold to this player attribute (auto-replicates)

-- Job #117: which `runGrants` keys `Profiles._publish` mirrors to `RunGrant_<key>` player attributes.
-- ⚠️ LIVES HERE, NOT IN `MonetizationDefs`, so `Profiles.luau` does not have to require the monetization
-- catalog just to publish a number. Keep it in step with `MonetizationDefs.RunGrants` by hand — one added
-- row that is missing here simply never replicates, which shows up as a shop row that never updates.
--
-- 🔴 A MISSING KEY BREAKS THREE THINGS AT ONCE, AND NONE OF THEM ERRORS.
-- `RunGrant_<key>` never gets published, so (1) `RifleGrant`'s watcher never fires and the weapon arrives
-- only on the lucky half of a profile race, (2) both shops' NEXT RUN state reads 0 forever so the row
-- **stays buyable** and the same player can pay again and again, and (3) nothing appears in any log.
-- That is a take-the-money-and-deliver-nothing path, from one forgotten string.
ProfileConfig.RUN_GRANT_KEYS = { "m16", "bazooka" }

-- A fresh profile. Stats mirror Job 020 §7.1 (the fields we already know we'll persist).
function ProfileConfig.default(): any
	return {
		dataVersion = ProfileConfig.DATA_VERSION,
		gold = 0,
		riverScore = 0, -- lifetime rank accumulator (filled by #026)
		modules = {}, -- owned boat modules: { [moduleId] = true } (Job 025)
		skills = {}, -- skill levels: { [skillId] = level 1..10 } (Job 024)
		paint = "olive", -- chosen hull livery (Job 067) — BoatPaint.DEFAULT, free for everyone
		-- retention (Job 028)
		lastLoginDay = 0, -- integer UTC day number of last daily-reward grant
		loginStreak = 0,
		weekId = 0, -- integer UTC week number the weekly objectives belong to
		weekly = { finish = 0, travel = 0, zone = 0 }, -- weekly objective progress
		weeklyClaimed = {}, -- { [objId] = true }
		purchaseIds = {}, -- ARRAY of granted developer-product PurchaseIds, FIFO-capped (Job 027, reshaped 089)
		-- Job #117: UNSPENT per-run loadout charges — { [key] = count }, e.g. { m16 = 1 }.
		-- ⚠️ A COUNT, NOT A BOOLEAN, and that is a real-money decision rather than a style one: a boolean
		-- set twice silently swallows the second purchase. A count carries the extra charge into the next
		-- run instead, which is the only outcome that is honest to someone who paid twice.
		-- Persistent because the whole point is surviving a lobby → game teleport, and a player who buys a
		-- charge and then logs off for a week must still have it. See MonetizationDefs.RunGrants.
		runGrants = {},
		-- Job #098: one-shot onboarding hints already shown to this player — { [hintId] = true }.
		-- Persistent on purpose: these teach a mechanic ONCE, so a veteran on their 50th run is never
		-- taught to carry a crate again. Lives on the profile rather than in the session for that reason.
		seen = {},
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
	-- Job 067. Type-checked, not just nil-checked: this one is written from a client-driven RemoteFunction,
	-- so a bad value must not be able to persist. BoatPaint.sanitize() re-validates the id itself on use.
	if type(data.paint) ~= "string" then
		data.paint = def.paint
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
	-- Job #098. Additive like every check above: an older profile simply arrives without it.
	if type(data.seen) ~= "table" then
		data.seen = {}
	end
	-- Job #117. Additive too. ⚠️ It MUST be here as well as in `default()`: every already-saved profile
	-- predates this field, so a field with only a default reads `nil` for every existing player and the
	-- first `runGrants[key]` index throws.
	if type(data.runGrants) ~= "table" then
		data.runGrants = {}
	end
	-- ⚠️ Job 089 changed the SHAPE of this from a dict `{[purchaseId] = true}` to an ARRAY of ids, so
	-- ProfileStore's official receipt pattern (FIFO-capped at 100, `table.find`) can use it. A dict
	-- reaching `table.find` would silently never match and every receipt would grant twice — so a
	-- leftover dict is RESET rather than tolerated. Free to do now: both stores were renamed in the
	-- same job and start empty, so this branch should never fire in practice. It exists in case the
	-- store name is ever pointed back at a Job 021 store.
	local pid = data.purchaseIds
	-- ⚠️ `next()` returns TWO values (key, value), so the extra parentheses are load-bearing:
	-- `type(next(pid))` passes both to `type` and is an error.
	local firstKey = if type(pid) == "table" then (next(pid)) else nil
	if type(pid) ~= "table" or (firstKey ~= nil and type(firstKey) ~= "number") then
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
