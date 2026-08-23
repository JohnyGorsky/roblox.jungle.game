# Job #112 — Implementation plan

**Project**: `roblox.jungle` · **Status**: implemented & verified in Play

## Goal

Three admin-panel **toggles** so a run can be driven end to end — all the way to the new extraction pad
at z 18300 — without dying or refuelling.

## Where each cheat is enforced (the only interesting decision)

Storage is trivial; *enforcement point* is what makes these correct.

| Cheat | Flag | Enforced in | Why there |
|---|---|---|---|
| Character god | `Player/Character.AdminGod` → stamps `InvincibleUntil` | `AdminServer` loop @ 0.25 s | `InvincibleUntil` is the attribute **both** damage paths already check (`EnemyServer` target selection, `ExcursionServer.tickGuard`). A new flag would mean editing every damage path to honour it — PlayerCombat's own comment warns about exactly this. The loop also tops up `HP` and `Humanoid.Health`, covering what `InvincibleUntil` does not: falling, drowning, anything writing Health directly. |
| Boat god | `Boat.AdminGodBoat` | **Inside BoatServer's `HP` changed handler** | The destroy check runs on the *same write*. A polling loop in AdminServer would lose to a single hit big enough to take HP straight to 0 — the run would end before the restore landed. Guarding in the handler catches every writer without any of them knowing. |
| Infinite fuel | `Boat.AdminInfiniteFuel` | **Top of BoatServer's Heartbeat** | Above every early return, including `Tied`. Three returns sit between the top and the fuel burn, so gating the refill on "under way" means flipping the switch at the dock appears to do nothing. |

Both boat cheats **top the value back up** rather than skipping the damage/drain, so the HUD gauges read
truthfully instead of freezing at whatever they were when you toggled on.

## Off is really off

The god loop only clears an `InvincibleUntil` deadline **it** stamped — the same guard PlayerCombat and
EscapeServer use — so switching god mode off cannot cancel a revive grace that is legitimately running.

## UI

A third action shape in `AdminClient`: `toggle`, alongside the existing targeted `kind` grant and self
`action`. Toggles differ in that they **read back** — `refreshCheats()` pulls real state from the server
on every panel open, so a button can never claim a cheat is on when the server refused it (`no-boat`
before the boat spawns) or when it was left on from a previous opening.

`godPlayer` follows the panel's target selector; the boat cheats are global (there is one boat).

## Files

`~` `sync/ServerScriptService/Progression/AdminServer.server.luau` — `cheat` / `cheats` actions + god loop
`~` `sync/ServerScriptService/Boat/BoatServer.server.luau` — the two enforcement points
`~` `sync/StarterPlayer/StarterPlayerScripts/UI/AdminClient.local.luau` — toggle buttons + read-back
`~` `sync/StarterPlayer/StarterPlayerScripts/UI/DownedHud.local.luau` — suppress the INVULNERABLE chip

## Verification (Play, GAME place)

Every cheat tested with a **negative control first**, so the check could fail:

| | control (off) | cheat on | off again |
|---|---|---|---|
| Character | HP 12 stays 12 | HP 5 → 100, Health 7 → 100 | HP 5 stays 5 |
| Boat | HP 0 → `BoatDestroyed = true` | HP 0 → restored 100, `BoatDestroyed` nil | — |
| Fuel | drains 0.75 / 5 s | refills to 100, drains 0.00 / 5 s | drains 0.75 / 5 s |

Toggled through the real allowlist-gated `Admin` RemoteFunction, not by poking attributes. Panel labels
verified to repaint `· ON` from server state after a reopen. `luau-analyze` clean.

## Two test-method errors worth recording

1. `execute_luau` on the **Client** datamodel writes a client-local attribute copy that never reaches the
   server — an entire fuel test measured nothing and looked like a product bug. Attribute writes for
   server-side verification must run in the **Server** datamodel.
2. Setting `Player.AdminGod` directly does **not** start the god loop (only the `cheat` action does), so a
   test that pokes the attribute reads as a broken feature.
