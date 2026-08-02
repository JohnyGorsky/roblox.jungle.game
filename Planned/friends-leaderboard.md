# Friends leaderboard

**Raised:** 2026-08-02, Job #069 (from the Job #068 lobby audit, gap C2 / `todo/0033`).
Promoted out of `todo/` because it is a **feature**, not a gap — the loose todo made it look like a
small fix, and it isn't.

## Why

`GAME.md` → *Progression & replay* promises **"Global + friends boards"**. Only the global board
exists: `RankServer` fills the editor board `Leaderboard_TopRuns` from an `OrderedDataStore` Top 10 by
River Score. There is no friends board anywhere.

Friends boards are strong retention — comparing against people you know beats comparing against a
global top 10 you will never enter. That is the case *for* building it.

## The constraints that make this job-sized (learned during the audit — don't rediscover them)

1. **`OrderedDataStore` cannot filter by friendship.** There is no "top N among these user IDs" query.
   You must read each friend's score individually and sort them yourself.
2. **The friend list is paginated and rate-limited.** `Players:GetFriendsAsync` returns a
   `FriendPages`; a player with 200 friends is 200 entries to page, then up to 200 `GetAsync` calls.
   That is far past a sane per-player budget, so it **needs a hard cap** (~50) and **caching**.
3. **It cannot live on the shared physical board.** Two players standing at the same prop need
   *different* content, so a `SurfaceGui` on a shared object can't work. It has to be a **personal UI
   panel** — or a board that renders only for whoever is nearest, which reads oddly with an audience.
4. **Scores must be readable per user.** Check whether the current `OrderedDataStore`
   (`RankDefs.BOARD_RIVERSCORE`) supports a direct per-user `GetAsync`, or whether a parallel
   plain-DataStore mirror is needed. This decides most of the work.

## Scope sketch

- A **Friends tab** in the lobby UI, built from `Theme`/`Components` (not a new physical prop).
- Server-side: capped, cached friend-score fetch behind a `RemoteFunction`, with a cooldown per player.
- Sort, render, show the local player's own position inline.

## Open questions

- Cap at 50 friends, or top-N-by-recent-play?
- Cache lifetime — per session, or a few minutes?
- Show friends who have never played (score 0 / "hasn't played yet") or hide them?

## Related

- The **Weekly** board is also unbuilt — it currently shows a *"coming soon"* placeholder and needs a
  weekly `OrderedDataStore` + rollover (see `ASSETS.md` §1.6). If both get built, do them together:
  they share the "read a different board and render it" plumbing.
- `todo/0033` is closed in favour of this file.
