# Combat encounter detection + `battle_starts` stinger

**Source:** Job #073 (ambient port) — deliberately left out of scope there. **Depends:** nothing new.

`battle_starts` (`rbxassetid://79506043370965`) has been **uploaded and owned since Job #064** and is read
by nothing. Both the shared registry `audio.md` and `LobbySoundscape`'s own header record it as belonging
to the GAME place. Job #073 wired its two siblings (`morning_starts` / `night_starts`, on the day/night
`Phase` flip) and left this one alone **on purpose**.

## Why it wasn't wired in #073

There is **no moment to fire it on.** `EnemyServer` is a continuous trickle spawner: `spawnInterval()`
escalates with distance and with the current phase, sea and land spawners run as independent loops, and
there is no wave, encounter, aggro-start, or "combat began" concept anywhere in the game.

Wiring a combat stinger therefore means **inventing encounter detection inside the combat system** — a
gameplay-behaviour change, not an ambient one. Job #073 was an ambient port; smuggling that in would have
been scope creep into a system the job never otherwise touched.

## Scope

- A real notion of *encounter*: e.g. an `InCombat` Workspace attribute that goes true when an
  `Enemy`-tagged foe is within some radius of the boat **and** closing, and false again after N quiet
  seconds. Server-authoritative, one place, published as an attribute so audio, HUD and music can all
  read it rather than each re-deriving it.
- Fire `battle_starts` on the false→true edge, with a cooldown so a running fight doesn't re-trigger it
  every time one crocodile dies and another spawns. This is the part that makes or breaks it — a stinger
  that fires every 20 seconds becomes noise.
- Optionally duck the ambient beds while `InCombat` (the buses already exist: `GameAmbient` /
  `GameMusic` / `GameSFX` `SoundGroup`s, created by `GameSoundscape`).

## Why it matters

Beyond the audio: an `InCombat` signal is the kind of thing several systems want (HUD threat indicator,
"can't repair while under attack", music ducking, analytics on how much of a run is spent fighting). The
stinger is the cheapest possible consumer of it and a good excuse to build it properly once.

→ Promote to a job.
