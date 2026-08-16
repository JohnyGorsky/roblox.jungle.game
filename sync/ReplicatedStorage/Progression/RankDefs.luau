--!strict
-- RankDefs.luau — River Score rank ladder (Job 026, design Job 020 §8). Shared client/server.
-- River Score is a lifetime, non-decaying accumulator; tiers are read off it. IDENTICAL copy in both trees.

local RunService = game:GetService("RunService")

export type Tier = { index: number, name: string, min: number, color: Color3 }

local RankDefs = {}

-- Job 085: the two global boards are split EDITOR vs LIVE for the same reason the profile store is
-- (see ProfileConfig) — otherwise every Studio playtest posts test scores onto the board real players
-- see. Same rule: the board name is the board; bump the _LIVE name to reset the live ladder.
RankDefs.BOARD_RIVERSCORE_DEV = "Board_RiverScore_v1"
RankDefs.BOARD_RIVERSCORE_LIVE = "Board_RiverScore_live_v1"
RankDefs.BOARD_DISTANCE_DEV = "Board_BestDistance_v1"
RankDefs.BOARD_DISTANCE_LIVE = "Board_BestDistance_live_v1"

RankDefs.BOARD_RIVERSCORE = if RunService:IsStudio()
	then RankDefs.BOARD_RIVERSCORE_DEV
	else RankDefs.BOARD_RIVERSCORE_LIVE
RankDefs.BOARD_DISTANCE = if RunService:IsStudio()
	then RankDefs.BOARD_DISTANCE_DEV
	else RankDefs.BOARD_DISTANCE_LIVE

-- ascending by min score; the highest tier whose min ≤ score wins
RankDefs.Tiers = {
	{ index = 1, name = "Castaway", min = 0, color = Color3.fromRGB(154, 160, 166) },
	{ index = 2, name = "Drifter", min = 500, color = Color3.fromRGB(181, 121, 58) },
	{ index = 3, name = "Rafter", min = 1500, color = Color3.fromRGB(205, 139, 78) },
	{ index = 4, name = "Riverhand", min = 4000, color = Color3.fromRGB(199, 205, 212) },
	{ index = 5, name = "Navigator", min = 9000, color = Color3.fromRGB(47, 182, 168) },
	{ index = 6, name = "Rapids Runner", min = 18000, color = Color3.fromRGB(52, 196, 224) },
	{ index = 7, name = "Whitewater", min = 35000, color = Color3.fromRGB(63, 123, 224) },
	{ index = 8, name = "Riverboat Captain", min = 65000, color = Color3.fromRGB(138, 92, 240) },
	{ index = 9, name = "Delta Master", min = 120000, color = Color3.fromRGB(199, 80, 208) },
	{ index = 10, name = "River Legend", min = 220000, color = Color3.fromRGB(245, 197, 66) },
} :: { Tier }

RankDefs.LEGEND_STAR_STEP = 100000 -- past River Legend, one ★ per this many extra points

-- highest tier whose min ≤ score
function RankDefs.tierFor(score: number): Tier
	local best = RankDefs.Tiers[1]
	for _, t in ipairs(RankDefs.Tiers) do
		if score >= t.min then
			best = t
		else
			break
		end
	end
	return best
end

-- The tier ABOVE the current one, or nil at River Legend (there is nothing higher). Job 065: the top-bar
-- rank progress needs the next tier's `min` to compute a fill.
function RankDefs.nextTierFor(score: number): Tier?
	local current = RankDefs.tierFor(score)
	return RankDefs.Tiers[current.index + 1]
end

-- Progress toward the next tier as 0..1, plus the labels the HUD shows.
-- At the top tier there is no next tier, so progress runs toward the NEXT PRESTIGE STAR instead
-- (LEGEND_STAR_STEP), which keeps the bar meaningful rather than pinned full forever.
function RankDefs.progressFor(score: number): (number, number, number)
	local current = RankDefs.tierFor(score)
	local nextTier = RankDefs.nextTierFor(score)
	if nextTier then
		local span = nextTier.min - current.min
		local into = score - current.min
		if span <= 0 then
			return 1, into, into
		end
		return math.clamp(into / span, 0, 1), into, span
	end
	-- River Legend: progress to the next star
	local past = score - current.min
	local into = past % RankDefs.LEGEND_STAR_STEP
	return math.clamp(into / RankDefs.LEGEND_STAR_STEP, 0, 1), into, RankDefs.LEGEND_STAR_STEP
end

-- Legend prestige stars (0 until past the top tier)
function RankDefs.legendStars(score: number): number
	local top = RankDefs.Tiers[#RankDefs.Tiers]
	if score < top.min then
		return 0
	end
	return math.floor((score - top.min) / RankDefs.LEGEND_STAR_STEP)
end

-- compact score label: 1234 → "1.2k", 65000 → "65.0k"
function RankDefs.shortScore(score: number): string
	if score < 1000 then
		return tostring(score)
	end
	return string.format("%.1fk", score / 1000)
end

return RankDefs
