--!strict
-- Profiles.luau — session-locked profile service. SERVER ONLY.
-- Job 021 built this on a hand-rolled UpdateAsync session lock; Job 089 replaced those internals with
-- the community ProfileStore module. IDENTICAL copy in sync/ and lobby/sync/ (same experience/DataStore).
--
-- ⚠️ THIS MODULE IS A FACADE, AND THAT IS THE POINT. 13 progression scripts across both places require
-- it. The public API below has not changed since Job 021, so the entire ProfileStore migration touched
-- this file and not one of them. Keep it that way: if a caller needs something new, add a method here
-- rather than requiring ProfileStore anywhere else.
--
-- Public API (all take a Player):
--   Profiles.load(p)            -- call on PlayerAdded; starts the session (yields)
--   Profiles.save(p, release)   -- release=false: save now · release=true: final save + end session
--   Profiles.unload(p)          -- drop the in-memory cache entry
--   Profiles.isReady(p)         -- true once load finished (real or fallback)
--   Profiles.get(p)             -- the raw in-memory data table (or nil)
--   Profiles.getGold(p) / addGold(p, n) / trySpendGold(p, n)
--   Profiles.getRiverScore(p) / addRiverScore(p, n)
--   Profiles.getPaint(p) / setPaint(p, id)
--   Profiles.isPersisting(p)              -- ⭐ Job 089: will a write to this profile actually survive?
--   Profiles.recordPurchase(p, id, grant) -- ⭐ Job 089: grant a dev product once, durably (YIELDS)
--
-- ── What ProfileStore does that the hand-rolled version did not ─────────────────────────────────
-- The old lock lived inside the profile data as `__lock = {session, heartbeat}` and let a newer
-- session STEAL a lock whose heartbeat was older than 90 s. That is the exact race this game runs on
-- every single launch — the lobby → reserved-server teleport hands one player between two servers —
-- and a 90-second timer is a poor way to resolve it. ProfileStore resolves the conflict in a single
-- call and can be driven by MessagingService so the losing server yields promptly.
--
-- It also owns two things this module used to: AUTO-SAVING (every 300 s internally) and SHUTDOWN
-- (its own game:BindToClose saves and releases every active profile). `ProfileServer` therefore no
-- longer runs an autosave loop or a BindToClose — see the note in that file before re-adding either.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileStore = require(ServerScriptService:WaitForChild("Vendor"):WaitForChild("ProfileStore")) :: any
local ProfileConfig =
	require(ReplicatedStorage:WaitForChild("Progression"):WaitForChild("ProfileConfig")) :: any

local Profiles = {}

local store = ProfileStore.New(ProfileConfig.STORE_NAME, ProfileConfig.default())

type Entry = {
	profile: any?, -- the ProfileStore Profile; nil in fallback, and cleared when the session ends
	data: any, -- profile.Data, or an unsaved default table in fallback
	ready: boolean, -- load finished (real or fallback)
	fallback: boolean, -- nothing written from here will ever persist
}

local cache: { [Player]: Entry } = {}

local function keyOf(player: Player): string
	return ProfileConfig.KEY_PREFIX .. tostring(player.UserId)
end

-- ⚠️ THE MOST IMPORTANT FUNCTION IN THIS FILE — read before touching anything money-related.
--
-- "Did we get a Profile?" and "will a write to it survive?" are DIFFERENT QUESTIONS, and conflating
-- them is how a player pays Robux and receives nothing.
--
-- When `DataStoreState ~= "Access"` — Studio with API services switched off, or no internet —
-- ProfileStore silently swaps in an in-memory MOCK store (ProfileStore.luau:596) and
-- `StartSessionAsync` hands back a Profile that looks completely normal. `IsActive()` is true. Saves
-- "succeed". Nothing is written anywhere. So a `profile ~= nil` test is not enough, and neither is
-- `IsActive()`; the DataStoreState check is the one that catches it.
function Profiles.isPersisting(player: Player): boolean
	local e = cache[player]
	if not e or e.fallback or not e.profile then
		return false
	end
	if ProfileStore.DataStoreState ~= "Access" then
		return false -- mock store: it will accept the write and throw it away
	end
	return e.profile:IsActive() == true
end

function Profiles._publish(player: Player)
	local entry = cache[player]
	if not entry then
		return
	end
	local gold = entry.data.gold or 0
	player:SetAttribute(ProfileConfig.GOLD_ATTRIBUTE, gold)
	player:SetAttribute("RiverScore", entry.data.riverScore or 0) -- rank source (Job 026)
	-- Chosen hull livery (Job 067). Published as an attribute so it replicates to every client for free —
	-- the boat builders and the lobby picker both read it here rather than round-tripping the profile.
	player:SetAttribute("BoatPaint", entry.data.paint or "olive")
	-- Job #117: unspent per-run loadout charges (MonetizationDefs.RunGrants), mirrored per key.
	-- An attribute for the same reason `BoatPaint` is one: both Robux shops need to know "has this player
	-- already bought a charge" with no round-trip, and the game place's grant needs to react the INSTANT a
	-- receipt lands mid-run rather than polling the profile.
	-- ⚠️ Publishes 0 rather than nil for a key with no charge, so a reader can compare a number without
	-- first proving the attribute exists.
	local grants = entry.data.runGrants
	for _, key in ipairs(ProfileConfig.RUN_GRANT_KEYS) do
		player:SetAttribute("RunGrant_" .. key, (type(grants) == "table" and grants[key]) or 0)
	end
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
	local entry: Entry = { profile = nil, data = ProfileConfig.default(), ready = false, fallback = false }
	cache[player] = entry

	-- Yields. `Cancel` is how ProfileStore is told to give up.
	--
	-- ⚠️ TWO conditions, and the second one is not optional. Supplying `Cancel` DISABLES ProfileStore's
	-- own START_SESSION_TIMEOUT (`ProfileStore.luau:1612` — the default timeout is only applied when
	-- `params.Cancel == nil`). So a `Cancel` that only tests "did they leave?" means that during a
	-- DataStore outage `StartSessionAsync` retries FOREVER for a player who is still sitting there:
	-- `load` never returns, `isReady` never goes true, and the fallback profile this function exists to
	-- provide is never reached. Our own deadline restores it.
	--
	-- LOAD_TIMEOUT is 60 s rather than something snappier on purpose: ProfileStore resolves a normal
	-- session conflict by stealing at SESSION_STEAL = 40 s, and the lobby -> game teleport IS a session
	-- conflict every single run. Giving up before 40 s would hand players an unsaved profile in the
	-- ordinary case. 60 s clears that and still bounds the wait.
	local LOAD_TIMEOUT = 60
	local startedAt = os.clock()
	local profile = store:StartSessionAsync(keyOf(player), {
		Cancel = function()
			return player.Parent ~= Players or (os.clock() - startedAt) >= LOAD_TIMEOUT
		end,
	})

	if cache[player] ~= entry then
		-- unloaded (or re-loaded) while we were yielding — this entry is stale, don't resurrect it
		if profile then
			profile:EndSession()
		end
		return nil
	end

	if profile ~= nil then
		if player.Parent ~= Players then
			profile:EndSession() -- left between the Cancel check and here
			cache[player] = nil
			return nil
		end

		profile:AddUserId(player.UserId) -- GDPR: associates the data with its owner for right-to-erasure

		-- Our own migrate(), NOT ProfileStore's Reconcile(). Reconcile only fills missing top-level keys;
		-- migrate() also deep-fills `stats` and TYPE-checks `paint` — which matters because `paint` is
		-- written from a client-driven RemoteFunction, so a bad value must never be able to persist.
		ProfileConfig.migrate(profile.Data)
		profile.Data.__lock = nil -- defensive: the Job 021 format kept its session lock inside the data

		-- The session was taken by another server, or ended under us. Match the pre-089 behaviour —
		-- warn, stop saving, let them keep playing on the in-memory table — rather than ProfileStore's
		-- convention of kicking. Decided with the user 2026-08-17 (Job 089, Q4).
		-- ⚠️ `fallback = true` is what stops MonetizationServer consuming a receipt from here on.
		profile.OnSessionEnd:Connect(function()
			local e = cache[player]
			if e and e.profile == profile then
				e.profile = nil
				e.fallback = true
				warn(("[Profiles] session ended for %s — playing on, saves halted"):format(player.Name))
			end
		end)

		entry.profile = profile
		entry.data = profile.Data
	else
		-- StartSessionAsync only returns nil when it was cancelled or timed out. Run on an in-memory
		-- profile that is NEVER saved: the player gets a playable session instead of a kick, and cannot
		-- corrupt their real save.
		entry.fallback = true
		warn(("[Profiles] no session for %s — in-memory fallback, will NOT save"):format(player.Name))
	end

	entry.ready = true
	Profiles._publish(player)
	return entry
end

-- release=false → save now (ProfileStore also auto-saves every 300 s on its own).
-- release=true  → final save + end the session, so another server can take it immediately.
-- ⚠️ NEITHER YIELDS. ProfileStore task.spawns the actual write in both cases, so this returning `true`
-- means "the write was queued", NOT "the write landed". Anything that must not be lost — receipts —
-- has to confirm durability separately; see `isPurchaseSaved`.
function Profiles.save(player: Player, release: boolean): boolean
	local entry = cache[player]
	if not entry then
		return false
	end
	local profile = entry.profile
	if not profile then
		return false -- fallback profile, or the session already ended
	end
	if release then
		profile:EndSession()
		entry.profile = nil
		entry.fallback = true -- nothing may be written after the session is handed over
		return true
	end
	if profile:IsActive() ~= true then
		return false
	end
	profile:Save()
	return true
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

-- ⚠️ REAL MONEY PATH. Grant a developer product exactly once and DO NOT RETURN until the grant is
-- confirmed on disk. Returns true only when it is safe to consume the receipt.
--
-- This is ProfileStore's official `PurchaseIdCheckAsync` pattern, kept in the facade so nothing else
-- has to know about `LastSavedData`, `OnAfterSave` or `IsActive`.
--
-- WHY IT YIELDS. `PurchaseGranted` is a one-way door — Roblox never delivers that receipt again. The
-- pre-089 code returned it as soon as the id was in the in-memory table, which was defensible only
-- because the old `save()` yielded until the write landed. ProfileStore's `Save()` task.spawns the
-- write instead, so the same code would confirm a purchase that had not been stored, and a crash in
-- between would take the player's Gold with it. `MarketplaceService.ProcessReceipt` tolerates yielding
-- inside the callback (documented by ProfileStore, from observed Roblox behaviour), so we wait for the
-- save rather than guess.
--
-- `grant` runs at most once per PurchaseId. Return `false` from it to mean "couldn't apply this right
-- now" (e.g. a self-revive when the player isn't downed) — the receipt is then left unconsumed and
-- Roblox re-delivers it later. Returning nil counts as success.
local PURCHASE_ID_CACHE_SIZE = 100 -- FIFO cap; profiles have a 4 MB ceiling and receipts are forever

function Profiles.recordPurchase(player: Player, purchaseId: any, grant: () -> boolean?): boolean
	if not Profiles.isPersisting(player) then
		return false -- fallback profile or mock store: the grant would evaporate
	end
	local entry = cache[player]
	local profile = (entry :: any).profile
	local id = tostring(purchaseId)

	local granted = entry.data.purchaseIds
	if type(granted) ~= "table" then
		granted = {}
		entry.data.purchaseIds = granted
	end

	local function isSaved(): boolean
		local saved = profile.LastSavedData
		local list = if type(saved) == "table" then saved.purchaseIds else nil
		return type(list) == "table" and table.find(list, id) ~= nil
	end

	if table.find(granted, id) == nil then
		local ok, result = pcall(grant)
		if not ok then
			warn(("[Profiles] purchase %s failed to grant for %s: %s"):format(id, player.Name, tostring(result)))
			return false
		end
		if result == false then
			return false -- the grant declined; leave the receipt for a later, better moment
		end
		-- Oldest ids drop off the end. Roblox stops re-delivering long-settled receipts, so a bounded
		-- cache is the accepted trade against a table that would otherwise grow for the profile's life.
		while #granted >= PURCHASE_ID_CACHE_SIZE do
			table.remove(granted, 1)
		end
		table.insert(granted, id)
	end

	if isSaved() then
		return true
	end

	while profile:IsActive() == true do
		local lastSaved = profile.LastSavedData
		profile:Save()
		if profile.LastSavedData == lastSaved then
			profile.OnAfterSave:Wait() -- no save had landed since we looked; wait for the next one
		end
		if isSaved() then
			return true
		end
		if profile:IsActive() == true then
			task.wait(10) -- a save failed or raced; back off rather than hammer the DataStore
		end
	end

	return false -- session ended before the grant was stored; the receipt stays unconsumed
end

-- ── per-run loadout charges (Job #117) ────────────────────────────────────────────────────────────
-- One charge = one run's worth of a Robux-bought weapon. `MonetizationServer` grants them,
-- `Inventory/RifleGrant` (GAME place only) spends them.
--
-- 🔴 `addRunGrant` MUST BE CALLED FROM INSIDE THE `grant` CLOSURE PASSED TO `recordPurchase`, never after
-- it returns. That closure is the ONLY place a write is covered by `recordPurchase`'s
-- yield-until-`LastSavedData`; anything written after it returns is an ordinary unflushed write, and
-- `Profiles.save` does not yield (see its own header). The lobby → game handover is a ProfileStore SESSION
-- STEAL on every single run (see `load`'s SESSION_STEAL note), and an unflushed charge crossing that steal
-- is simply gone — the player paid Robux and receives nothing. This is a real-money path; treat the
-- placement of the call as part of the contract, not as style.
function Profiles.addRunGrant(player: Player, key: string, amount: number): number
	local e = cache[player]
	if not e then
		return 0
	end
	if type(e.data.runGrants) ~= "table" then
		e.data.runGrants = {}
	end
	local next_ = math.max(0, ((e.data.runGrants[key] :: number?) or 0) + amount)
	e.data.runGrants[key] = next_
	Profiles._publish(player)
	return next_
end

-- Spend one charge. Returns true ONLY if there was one to spend, so the caller can gate the grant on it
-- rather than checking and then spending in two steps.
--
-- ⚠️ Deliberately NOT wrapped in a save-and-wait, and that asymmetry is correct: losing a CONSUME to a
-- crash leaves the player still holding the charge, which is the harmless direction. Losing a GRANT loses
-- their money, which is why only `addRunGrant` carries the warning above.
function Profiles.takeRunGrant(player: Player, key: string): boolean
	local e = cache[player]
	if not e or type(e.data.runGrants) ~= "table" then
		return false
	end
	local have = (e.data.runGrants[key] :: number?) or 0
	if have <= 0 then
		return false
	end
	e.data.runGrants[key] = have - 1
	Profiles._publish(player)
	return true
end

function Profiles.getRunGrant(player: Player, key: string): number
	local e = cache[player]
	if not e or type(e.data.runGrants) ~= "table" then
		return 0
	end
	return (e.data.runGrants[key] :: number?) or 0
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

-- Chosen hull livery (Job 067). The CALLER is responsible for validating the id and for checking the Boat
-- Paint Pack is owned — this only persists and publishes. Returns false if the profile isn't loaded yet.
function Profiles.setPaint(player: Player, paintId: string): boolean
	local e = cache[player]
	if not e then
		return false
	end
	e.data.paint = paintId
	Profiles._publish(player)
	return true
end

function Profiles.getPaint(player: Player): string
	local e = cache[player]
	return (e and e.data.paint) or "olive"
end

return Profiles
