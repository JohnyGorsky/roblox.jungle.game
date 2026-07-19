--!strict
-- RankDefs.luau — River Score rank ladder (Job 026, design Job 020 §8). Shared client/server.
-- River Score is a lifetime, non-decaying accumulator; tiers are read off it. IDENTICAL copy in both trees.

export type Tier = { index: number, name: string, min: number, color: Color3 }

local RankDefs = {}

RankDefs.BOARD_RIVERSCORE = "Board_RiverScore_v1"
RankDefs.BOARD_DISTANCE = "Board_BestDistance_v1"

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
