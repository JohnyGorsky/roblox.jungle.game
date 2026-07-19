--!strict
-- RetentionDefs.luau — daily login + weekly objective defs (Job 028, design Job 020 §9). Shared. Both trees.

local RetentionDefs = {}

-- daily login: 7-day escalating Gold cycle; +MILESTONE_30 at every 30th consecutive day
RetentionDefs.DAILY = { 10, 15, 20, 30, 40, 50, 100 }
RetentionDefs.MILESTONE_30 = 250
RetentionDefs.GRACE_DAYS = 2 -- a gap of ≤ this many UTC days keeps the streak (forgives one miss)

export type WeeklyObj = { id: string, name: string, target: number, gold: number, score: number }

RetentionDefs.WEEKLY = {
	{ id = "finish", name = "Finish 3 runs", target = 3, gold = 80, score = 500 },
	{ id = "travel", name = "Travel 30,000 studs", target = 30000, gold = 60, score = 300 },
	{ id = "zone", name = "Reach Zone 4 in a run", target = 4, gold = 50, score = 250 },
} :: { WeeklyObj }

-- integer UTC day / week numbers → trivial, year-safe gap + rollover math
function RetentionDefs.dayNumber(): number
	return math.floor(os.time() / 86400)
end
function RetentionDefs.weekNumber(): number
	return math.floor(os.time() / 604800)
end

-- the Gold for a given streak length (1-based), cycling the 7-day table + 30-day milestone
function RetentionDefs.dailyReward(streak: number): (number, number)
	local idx = ((streak - 1) % 7) + 1
	local gold = RetentionDefs.DAILY[idx]
	if streak % 30 == 0 then
		gold += RetentionDefs.MILESTONE_30
	end
	return gold, idx
end

return RetentionDefs
