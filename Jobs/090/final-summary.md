# Final Summary — Job #090

**Project**: `roblox.jungle`
**Completed**: 2026-08-17
**Status**: ✅ **COMPLETE (2026-08-17)** — analyzer clean and playtest-confirmed by the user: guards stand on the ground, and shooting one pulls its camp.

Two items from the 2026-08-17 playtest. One file changed: `Excursion/ExcursionServer.server.luau`
(game tree only — the lobby has no Excursion).

---

## Item 1 — Camp guards were standing 3 studs underground

**Measured live in Play, Server datamodel**, one Wolf `CampGuard`:

```
body bottomY   = 15.00
terrain under  = 18.00      -> feet 3.00 studs UNDERGROUND
visual bottomY = 15.00      (== body bottom, so the visual seating is correct)
```

The Wolf's visual is 5.49 studs tall, so it stood buried past the shoulders — *"Bandit is half ground…
same with wolf"*.

### Root cause

Guards were seated at bare `CLEAR_Y` (= `WATER_Y + 3` = **15**) while the carved basin floor really
measures **~18** after RES=4 voxel snapping.

This exact failure already has a solution in this file: `groundAt()` measures the floor instead of
assuming it, and **its own comments state the 3-stud number**. Every camp *prop* has gone through it
since Job #077. Guards were the one thing that never did.

### ⚠️ Not a Job #088 regression

#088 aligned the **visual to the hitbox**, and that is verified still correct here — visual bottom and
body bottom match to the hundredth. #088 fixed visual-vs-hitbox; **nothing had ever seated the hitbox
itself to the terrain.** Two different bugs with the same symptom, which is why the first fix looked
like it should have covered this.

### Fixed in three places, and all three were required

| Site | Was | Now |
| --- | --- | --- |
| `spawnGuard` build | `anchorPos.Y` (= `campPos.Y`, `CLEAR_Y`-based) | `groundAt(x, z)` |
| `spawnGuard` anchor | `CLEAR_Y + size.Y/2` | measured `footY + size.Y/2` |
| `tickGuard` movement | `CLEAR_Y + size.Y/2`, **every frame** | `st.anchor.Y` |

The third is the one that would have hidden the fix: `tickGuard` rewrites Y on every step, so seating a
guard only at spawn would be undone the moment it moved. The seated height is stored once in
`guardState.anchor` and read from there — no per-guard, per-frame raycast.

`groundAt` runs after `settleTerrain()` in `buildCampAt` (:895 before :982), so the camp's terrain
writes have landed before anything raycasts them.

---

## Item 2 — Enemies could be shot from outside any reach they had

### The exploit, from the defs rather than by feel

| | studs |
| --- | --- |
| Gun range (`GunServer.GUN_RANGE`) | **350** |
| Handheld range (`WeaponServer` default) | **220** |
| Guard sight (`def.aggroRadius`) | **95** |
| Guard maximum reach (`GUARD_LEASH`) | **55** |

A player standing ~110 studs out was untouchable **by construction** and could empty magazines into a
camp at zero risk. The weapon outranged the enemy's greatest possible reach by 4–6×.

### The fix — damage escalates, sight does not (user's decision)

Deliberately **not** a bump to `aggroRadius`. Raising sight alone means guards sprint to the end of a
55-stud rope and stand there being shot; raising both permanently means they abandon camp on sight and
trail the player back to the boat.

Instead **taking damage** pulls the camp:

- any hit, from any range, alerts **every guard of that camp** for `GUARD_ALERT_SECONDS` (**15 s**,
  refreshed on each further hit);
- while alerted a guard **ignores `aggroRadius` entirely** — it has been shot, it does not need to see
  you — and hunts the nearest player at any range;
- its leash opens from 55 to `GUARD_LEASH_ALERT` (**250**), enough to cross a handheld's 220 and most of
  a gun's 350;
- when the alert lapses, the ordinary 55-stud clamp walks it home. **A camp never permanently abandons
  its post**, and an unprovoked camp still behaves exactly as before.

### Two implementation choices worth knowing

**Hooked to the HP attribute, not to the weapons.** Three separate call sites damage enemies —
`GunServer`, `WeaponServer`, `MeleeServer` — and a fourth added later would silently miss a
weapon-side hook. Watching `GetAttributeChangedSignal("HP")` catches all of them, now and later.
`lastHP` gates it to *decreases*, so the village strength multiplier written at spawn (and any future
heal) can't trigger a false alert.

**The camp key is the camp's POSITION, not its parent Instance.** Every landing site calls
`buildCampAt` twice — a NEAR camp and a DEEP camp — and passes both the **same** `model` as parent.
Keying the alert on the parent would have pulled both camps at once: up to 12 guards from 180 studs
apart, when the decision was that a shot pulls *the camp*, not the whole shore.

---

## Verification

- [x] `tools/luau-analyze.sh` — GAME clean (lobby untouched; no `Excursion` there)
- [x] **Playtest — confirmed by the user, 2026-08-17.** Guards stand on the ground (Bandit and Wolf,
      near and deep camp), and shooting one from range pulls its whole camp.

## Still open

**`todo 0054` stays open.** This fixed the camp half. Riverbank land enemies have the same shape —
`aggroRadius` 95 against `LAND_LEASH` 65 in `EnemyServer` — and were left alone because the decision
taken was camp-specific and a lone bank ambusher has no camp to pull. Worth its own call: on a moving
boat the trade-offs are different.
