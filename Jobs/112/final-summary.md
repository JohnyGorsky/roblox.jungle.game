# Job #112 — Final summary

**Project**: `roblox.jungle` · **Status**: COMPLETE — implemented & verified in Play

Three toggles at the bottom of the admin panel:

- **GOD MODE — CHARACTER** — follows the target selector. Stamps `InvincibleUntil` (the attribute both
  damage paths already check) and tops up `HP` + `Humanoid.Health`, so falls and drowning are covered too.
- **GOD MODE — BOAT** — the hull cannot be destroyed; HP is restored inside BoatServer's own change
  handler, so even an instant 100→0 hit cannot end the run.
- **INFINITE FUEL** — the tank refills to max every frame, including while tied at the dock.

They are toggles, not grants: the panel reads real server state on open, so the labels are `· ON` / `· OFF`
and can never lie about a request the server refused.

## Files

`~` `AdminServer.server.luau` · `~` `BoatServer.server.luau` · `~` `AdminClient.local.luau` ·
`~` `DownedHud.local.luau`

## Verified

Negative control before every cheat. Boat destroyed at HP 0 with the cheat off, survived HP 0 with it on.
Fuel drained 0.75/5 s off, 0.00/5 s on, 0.75/5 s off again. Character HP/Health restored on, left alone
off. All toggled through the real allowlist-gated remote. `luau-analyze` clean on all four files.

## Notes / limits

- God mode stops you *going down*; it does not stand a player back up if they are already downed —
  `Downed` is PlayerCombat's state machine and forcing it from outside would desync it. Revive normally.
- A fall past `FallenPartsDestroyHeight` destroys the character outright; no HP top-up can catch that.
- The cheats are session state on the Player/Boat — they do not persist to the profile, and the boat
  flags are lost if the boat is ever rebuilt.
