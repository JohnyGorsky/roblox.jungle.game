--!strict
-- RewardFeed.luau — "you just received X" (Job #109). SERVER ONLY; one small remote to one player.
--
-- ── Why this exists ───────────────────────────────────────────────────────────────────────────────
-- Reported: *"when i take loot no messages nothing. We must way - received x scrap or loot. Same when
-- killing enemies. We must have one generic message when you receive scrap or loot, now you just
-- guess."*
--
-- Exactly right, and it had been true since the beginning. Looting a crate, searching a hut stash,
-- grabbing a nugget and killing a bandit all just moved a number in the top-right corner. The Salvage
-- chip does update — but a counter going from 214 to 254 while you are looking at the thing you looted
-- is not feedback, it is a diff you have to notice and subtract.
--
-- ── Why it is an EXPLICIT call and not a watcher on the Salvage attribute ─────────────────────────
-- Watching `player:GetAttributeChangedSignal("Salvage")` on the client would have been fewer lines and
-- would have caught every source automatically, including ones added later. It is the wrong design here
-- for one concrete reason: **`SalvageServer`'s distance drip pays 1 Salvage per 60 studs travelled**,
-- continuously, for the whole 18,000-stud run. An attribute watcher turns that into a toast every few
-- seconds forever, and the feature that was supposed to stop you guessing becomes the thing you learn to
-- ignore. Deltas would also have to guess a LABEL — "+40" cannot say *Gasoline*.
--
-- So the call sites opt IN. The drip simply never calls this, which is not an omission to be fixed.
--
-- ⚠️ ONE PLAYER, NOT THE CREW. `CrewToast` already exists for shared news ("X deposited 1 Gasoline")
-- and fires to everyone. This is private feedback about your own hands — routing it through the crew
-- feed would tell five other people about your 6 salvage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardFeed = {}

local remote = ReplicatedStorage:FindFirstChild("RewardFeed") :: RemoteEvent?
if not remote then
	local made = Instance.new("RemoteEvent")
	made.Name = "RewardFeed"
	made.Parent = ReplicatedStorage
	remote = made
end
local event = remote :: RemoteEvent

export type Kind = "salvage" | "gold" | "resource" | "weapon" | "ammo"

--- Tell one player they just received something.
---   `kind`   picks the icon and tint on the client.
---   `label`  what it is, in player words ("Salvage", "Gasoline", "Pistol Ammo").
---   `amount` optional; omitted for a one-off like a weapon, where "+1 Pistol" reads worse than "Pistol".
function RewardFeed.notify(player: Player, kind: Kind, label: string, amount: number?)
	if not player.Parent then
		return -- they left between the pickup and this call
	end
	event:FireClient(player, { kind = kind, label = label, amount = amount })
end

return RewardFeed
