--!strict
-- AdminDefs.luau — admin allowlist (Job 031). Shared: the client uses it to decide whether to SHOW the
-- admin button; the SERVER re-checks it on every action (never trust the client). IDENTICAL in both trees.
-- Add teammates by UserId here.

local AdminDefs = {}

AdminDefs.ALLOWLIST = {
	[5025640608] = true, -- johnygorsky10 (owner)
}

function AdminDefs.isAdmin(userId: number): boolean
	return AdminDefs.ALLOWLIST[userId] == true
end

return AdminDefs
