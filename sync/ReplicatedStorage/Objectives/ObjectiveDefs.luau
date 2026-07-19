--!strict
-- ObjectiveDefs.luau — per-run objective catalog (Job 061). Shared: ObjectiveServer tracks/awards, ObjectiveHud
-- displays. Completing one rewards the whole crew: Salvage (in-run) + River Score (rank) [+ Gold for finishing].
-- Fixed set for the POC (could be seeded/randomised per run later).

local ObjectiveDefs = {}

export type Objective = {
	id: string,
	label: string,
	target: number, -- 1 = binary; >1 = a count (HUD shows n/target)
	salvage: number,
	score: number,
	gold: number,
}

ObjectiveDefs.List = {
	{ id = "reachRapids", label = "Reach The Rapids", target = 1, salvage = 120, score = 60, gold = 0 },
	{ id = "nightOwl", label = "Survive a night on the water", target = 1, salvage = 150, score = 80, gold = 0 },
	{ id = "hunter", label = "Take down 15 threats", target = 15, salvage = 120, score = 60, gold = 0 },
	{ id = "finisher", label = "Complete the run", target = 1, salvage = 0, score = 150, gold = 5 },
} :: { Objective }

return ObjectiveDefs
