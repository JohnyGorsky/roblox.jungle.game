--!strict
-- GeneratorServer.server.luau — wires the world's generators (Job #115).
--
-- All the behaviour lives in `Generators.luau`; this is just the boot. It exists so that the module
-- stays a module (a later job can `require` it and spawn generators without inheriting a startup scan).
--
-- Two ways in, on purpose:
--   1. THE EDITOR-PLACED ONES, found BY NAME under Workspace — the same contract every other hand-placed
--      fitting in this game uses (`EscapeServer`'s `Escape`, `StagingServer`'s `SpawnBase`). The user
--      placed `EndBase.Bunker.Generator1/2/3`; nothing here knows those paths, so moving or renaming a
--      generator inside Workspace keeps it wired as long as it is still called Generator*.
--   2. THE TAG, for anything spawned later. Adding `Generator` to a Model is enough — no require, no
--      call. `Generators.spawn` does exactly this internally, so both paths converge and `attach` is
--      idempotent to make the overlap harmless.
--
-- ⚠️ SCANNED FROM WORKSPACE, NOT FROM SERVERSTORAGE. The AssetLibrary template is also called
-- `Generator`; wiring it would leave a humming, health-barred prop in storage and hand every future
-- clone a duplicate set of FX. See `Generators.attachAll`'s own warning.

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Generators = require(ServerScriptService:WaitForChild("World"):WaitForChild("Generators"))

local wired = Generators.attachAll(Workspace)

-- Anything tagged later (a spawner, a plugin, a future job) gets wired the moment it is tagged.
CollectionService:GetInstanceAddedSignal(Generators.TAG):Connect(function(inst: Instance)
	if inst:IsA("Model") then
		Generators.attach(inst)
	end
end)

local names = {}
for _, m in ipairs(Generators.all()) do
	table.insert(names, m.Name)
end
table.sort(names)
print(("[Generator] %d wired (%s) — %d HP each, %s"):format(
	wired,
	if #names > 0 then table.concat(names, ", ") else "none found",
	Generators.MAX_HP,
	"destructible by melee, handheld guns and the turret"))
