# TODO 0064: NuggetsSpawned is never reset, unlike Salvage and the bunkers

**Project:** `roblox.jungle`
**Status:** open
**Created:** 2026-08-27 21:07:58

ExcursionServer's only writes to NuggetsSpawned are :614 and :618 — nothing resets it on RunStarted, while SalvageServer:44-49 and BunkerServer:35-42 both explicitly do. Harmless while a game server hosts exactly one run, but it is the odd one out among three files that deliberately handle a re-run. Surfaced by the Job #123 economy audit.
