# TODO 0044: night_starts won't play — TWO uploads blocked, replace the SOURCE audio

**Project:** `roblox.jungle`
**Status:** resolved (2026-08-02) — RESOLVED 2026-08-02. Took three assets. night_starts 99602574849976 and its re-upload 95532390211599 (same source mp3) were both blocked by audio moderation - IsLoaded false, 'Asset is not approved for the requester' - while sibling morning_starts re-uploaded cleanly on the first try. That asymmetry showed the problem was the AUDIO FILE (copyright check), not the pipeline or per-experience permissions, so the fix was different source audio rather than a third upload of the same file. night_starts_2 = 75443344927115 loads, 11.0s, and is now wired in the SFX table of sync/ServerScriptService/World/GameSoundscape.server.luau plus the shared registry audio.md. morning_starts is 88638394432005 (9.0s). All three dead ids are recorded in a comment in GameSoundscape so nobody resurrects them from git history.
**Created:** 2026-08-02 21:58:38
**Updated:** 2026-08-02 — second upload also blocked

## Final state — ✅ both stingers play

| Sound | live id | loads? |
|---|---|---|
| `morning_starts` | `88638394432005` | ✅ 9.0 s |
| `night_starts_2` | `75443344927115` | ✅ 11.0 s — **different source audio**, third asset |

Dead ids — do **not** resurrect them from git history or an old registry copy:
`morning_starts` `98066971477923`, `night_starts` `99602574849976`, `night_starts` `95532390211599`.
They are listed in a comment in `GameSoundscape` for exactly that reason.

The diagnosis below is kept because the reasoning generalises: **when an upload won't play, check whether
a sibling upload from the same session works.** If it does, the problem is the file — stop re-uploading and
change the audio.

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
