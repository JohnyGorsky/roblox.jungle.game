# Job #103 — Final summary

**Project**: `roblox.jungle` · **Place**: GAME only (`sync/`) · **Status**: Complete, verified in Play

> *"when i revive i must be full health not just half (with robux), also i must be invincible for 10
> seconds. Now you respawn by robux and instantly killed."*

---

## 1. Why you were instantly killed — the mechanism, from the code

`revive()` puts the player back on the **exact spot they fell**, and nothing else is reset. Two things
compound:

- **Enemy bite cooldowns run free the whole time you are down.** `st.biteTimer += dt` accumulates every
  Heartbeat (`EnemyServer:410`, `ExcursionServer:1878`) and is only zeroed when a bite actually *fires*.
  While you are downed no bite fires at you, because both target selectors exclude `Downed`
  (`EnemyServer:137`, `ExcursionServer:1889`). So after 30 seconds on the floor every guard standing over
  you is **massively over cooldown**.
- **Clearing `Downed` re-inserts you into the target list at your old position, inside bite range.**

The result is that the first bite lands on the *frame* you stand up, with no reaction time. At the old
50 HP that is ~9 camp-guard bites, and with two chasers on ~1.5 s cooldowns it is roughly seven seconds
from standing up to being down again — which is exactly what "instantly killed" describes.

Full health alone would not have fixed this. It buys a couple more bites. What was missing is **a window
to move in**.

## 2. What changed

| Change | File |
|---|---|
| `REVIVE_HP = 50` deleted — a revive returns you to **`MAX_HP`**, both routes | `Combat/PlayerCombat` |
| `REVIVE_GRACE = 10` — `InvincibleUntil` stamped on the **`Workspace:GetServerTimeNow()`** clock | `Combat/PlayerCombat` |
| Gold `Highlight` on the protected character, built **server-side** so the whole crew sees it | `Combat/PlayerCombat` |
| Invincible players excluded **in the target selector** (`nearestPlayer`) | `Enemies/EnemyServer` |
| Camp-guard bite does no damage while the window is open | `Excursion/ExcursionServer` |
| `INVULNERABLE 10…1` chip, its own ScreenGui, gold accent + shield icon | `UI/DownedHud` |

The user's call (via wizard) was **both** revive routes — paid and teammate bandage — and **all** damage
blocked, with a **visible** indicator.

## 3. 🔴 The independent audit found three defects in my own implementation

An independent reviewer was given only the symptom, never my theory (GROUND-RULES §8). It confirmed my
two guarded sites are **100% of today's player-damage surface** — its own sweep found no third path,
and explicitly ruled out obstacles, boat destruction, friendly fire, drowning, fall damage, enemy death
splash and all 13 client remotes. It then found three things wrong with what I had written:

### A. `os.time()` made the indicator lie

`os.time()` returns **whole seconds**. A revive at true epoch *x*.7 stamped a deadline only **9.3 s**
away, while the glow (a float `Debris` lifetime) and the attribute clear (a float `task.delay`) both ran
the full 10.0. So for up to a second the gold glow was still showing and the attribute was still set
**while damage had already resumed**. A lying indicator is worse than no indicator.

Fixed by moving the whole thing to `Workspace:GetServerTimeNow()` — a float, replicated, readable on the
client — so the deadline, the glow, the clear and the HUD countdown all agree. Measured before: `grace=10s`
(integer, actually 9.x). After: **`grace=10.00s`**, and at first damage the glow was already gone.

### B. An invincible player was a shield for the entire crew

I had put the check at the *bite*, inside `applyBite`, and returned early. But `nearestPlayer` returns the
**nearest** valid target — so if that was the protected player, the bite was spent on them and a
vulnerable teammate three studs behind, **and the hull**, took nothing for ten seconds.

Fixed by filtering invincible players in the **selector** instead, so the bite falls through to whoever is
legitimately next. The bite-site guard was removed with it.

### C. Stamp-before-clear ordering

`InvincibleUntil` is now stamped **before** `Downed` is cleared. Nothing yields between them today, so it
was already atomic — but clearing `Downed` is what makes the character targetable, and anyone who later
inserts a `WaitForChild` or `task.wait` in between would reopen exactly the hole this job closes, as a
one-frame intermittent nobody could reproduce. Free to fix by construction.

## 4. Verified in Play

Studio, **Last River COOP Game**. Triggered through `ServerScriptService.GrantProduct` → `grantSelfRevive`
— the exact hook a Robux receipt fires — sampling at 0.25 s so the transition is pinned:

```
downed:  HP=0 Downed=true
REVIVED: grant=true HP=100 Downed=false grace=10.00s glow=true
FIRST DAMAGE at t=11.33s  HP 100.0000 -> 94.4704  (glow=false, attr=nil)
end: HP=77.88  firstDamage=11.33s
```

Read out:

- **Full health** — 100, not 50.
- **The window holds** — zero damage for its full length with a Bandit adjacent and attacking. *This test
  can fail*: a missed damage path would have shown as an HP drop inside the window.
- **The enemy really was attacking** — the bite that lands as soon as the window closes is the proof the
  ten seconds of stillness was the grace working and not an idle guard.
- **The indicator no longer over-runs protection** — at first damage, `glow=false` and `attr=nil`. That is
  defect A verified fixed.
- **Damage is exactly right** — 5.5296 per bite, the Job #102 figure, cross-checking that job too.
- First damage at 11.33 s rather than 10.0 s is expected and consistent: a *blocked* camp-guard swing
  still resets `st.biteTimer`, so the next bite is one 1.4 s cooldown after the window closes.

### ⚠️ What was NOT verified, stated plainly

- **The two-player body-block case (defect B) was not reproduced.** The fix is in `nearestPlayer`, which
  serves river creatures; my test used a camp guard, which targets individually and never goes through it.
  Proving B needs a Team Test with two clients — a revived player and a vulnerable teammate three studs
  behind. Analyzer-clean and verified by reading only.
- **The receipt chain above `GrantProduct` was not exercised.** I invoked the hook directly.
  `Profiles.recordPurchase` returns false *without calling the grant* when `Profiles.isPersisting()` is
  false, and that is false whenever `ProfileStore.DataStoreState ~= "Access"` — so **in Studio with API
  services off, the paid revive can never fire, and testing it there looks identical to the bug**.
- **The teammate bandage route** is the same `revive()` closure, differing only in an argument that no
  longer affects health. Verified by reading, not run.

## 5. Correction to something I told the user

I warned that the Combat Medic skill's shipped description was now wrong, because its `+2.5 HP per level`
on revive is dead against a full bar. **That warning was wrong.** `SkillDefs:23` reads
`unit = "% revive speed"`, `blurb = "Revive teammates faster."` — it describes only the shorter revive
hold, which still works. The copy is fine as it stands. The HP bonus is genuinely gone, and that is worth
knowing if the skill is ever re-tuned, but nothing shipped needs changing.

## 6. Left undone, logged as findings

- **`findings/0012`** — player `HP` has a real chokepoint (`PlayerCombat`'s `HP` attribute-changed
  handler) that this job does not use. It sees every write from every script, and a decrease-veto there
  would make the window hold when someone adds damage path #3 in six months. Contrary to a note I wrote
  during this job, it would **not** fight the heal loops — `RoleServer` and `CampfireHeal` only ever
  *increase* `HP`. Also records the trap that `InvincibleUntil` is a **number** that can linger past
  expiry, so a truthiness test on it is wrong.
- **`findings/0013`** — going down while carrying cargo never clears `Busy`, so a revived hauler comes
  back still unable to use the gun or the axe.
- **`findings/0014`** — a paid revive bought in the last second is refused (correctly not charged) but the
  player is permanently dead for the run, and `DownedHud`'s `PANIC_SECONDS = 10` actively encourages that
  purchase.

## 7. What the grace does *not* solve

Nothing resets enemy state. At second 10 the player is still in the same spot, still surrounded, with
alerted guards whose `biteTimer` was reset by each absorbed swing. The window buys time to move — which is
what was asked for. If the report comes back as *"still dies right after"*, the next levers are resetting
`st.biteTimer` on revive, clearing `st.alertUntil`, or moving the revived player — **not** lengthening the
window.

## Sync

| Path | Synced |
|---|---|
| `sync/ServerScriptService/Combat/PlayerCombat.server.luau` | ✅ auto |
| `sync/ServerScriptService/Enemies/EnemyServer.server.luau` | ✅ auto |
| `sync/ServerScriptService/Excursion/ExcursionServer.server.luau` | ✅ auto |
| `sync/StarterPlayer/StarterPlayerScripts/UI/DownedHud.local.luau` | ✅ auto |
