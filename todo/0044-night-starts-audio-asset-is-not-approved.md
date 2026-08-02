# TODO 0044: night_starts won't play — TWO uploads blocked, replace the SOURCE audio

**Project:** `roblox.jungle`
**Status:** open — **re-upload already tried once and failed; do not just try again**
**Created:** 2026-08-02 21:58:38
**Updated:** 2026-08-02 — second upload also blocked

## Current state

`GameSoundscape` and the registry now point at the **re-uploaded** ids:

| Sound | current id | loads? |
|---|---|---|
| `morning_starts` | `88638394432005` | ✅ yes, 9.0 s — day stinger works |
| `night_starts` | `95532390211599` | ❌ **no** — `IsLoaded` stays false |

Dead ids, do **not** resurrect them from git history or an old registry copy:
`morning_starts` `98066971477923`, `night_starts` `99602574849976`.

## What was measured

Both uploads of `night_starts` fail **identically**:

- runtime: `Failed to load sound …: Asset is not approved for the requester`
- `Sound.IsLoaded` stays `false`, `TimeLength` 0, retested up to 10 s and again ~2.5 min after upload
- `GetProductInfo` **succeeds** both times — name `night_starts`, `AssetTypeId 3` (Audio), creator
  `johnygorsky10`. So the asset exists, is the right type, and is owned.
- In the Creator Hub asset list the working `morning_starts` shows a normal waveform icon while
  `night_starts` shows a **blank grey icon**.

## Why "re-upload it again" is the wrong next step

This is **not** a per-experience permission problem: `morning_starts`, `battle_starts`, `boat_hit`,
`gun_shot`, `cicadas`, both ambience beds, `wind-breeze` and `water-splashes` all load fine in the same
GAME place. And it is not a bad-luck single upload either — **the same source file has now been rejected
twice**, while its sibling re-uploaded cleanly on the first try.

Two uploads of one file failing the same way points at **the file itself**, almost certainly Roblox's
copyright/content check on the audio. A third upload of the same mp3 should be expected to fail too.

## Action

1. Check `create.roblox.com` → Creator Dashboard → Development Items → Audio → `night_starts` for the
   actual moderation verdict/reason.
2. **Replace the source audio** — `assets/Objects/Ambient/night_starts.mp3` needs to be a different piece
   of audio (Pixabay or similar, per GROUND-RULES §4), not the same file re-encoded.
3. Put the new id in **two** places: the `SFX` table at the top of
   `sync/ServerScriptService/World/GameSoundscape.server.luau`, and
   `roblox.workspace/Assets/registry/audio.md`.

## Until then

The night stinger is simply silent — nothing else is affected. `GameSoundscape.stinger()` warns loudly if a
stinger never loads and destroys the `Sound` after 20 s, because `Ended` never fires for an unloadable
asset and `Ended:Once(destroy)` alone would leak one instance on every single day/night flip.
