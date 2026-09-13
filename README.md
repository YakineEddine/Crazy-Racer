# Crazy Racer — Agent Reference Docs

Reference set for an AI coding agent (OpenCode) building this game in **Godot 4.x**. Read `00_PROJECT_STRUCTURE.md` first — every other file assumes its paths/conventions. Then follow the build order below; each doc is self-contained enough to load individually per task.

## Build Order

1. **`00_PROJECT_STRUCTURE.md`** — folder tree, naming conventions, autoload order. Set this up before writing any gameplay code.
2. **`01_CORE_SYSTEMS_LOGIC.md`** — GameManager, LobbyManager, TeamManager, MatchmakingService, BoundaryManager, ChaosEventSystem, base vehicle controller, RPC/authority conventions. Build offline-testable first (single-player against the phase machine) before wiring networking.
3. **`02_VEHICLES_AND_ITEMS.md`** — the 5 vehicle classes, `KartStats` schema, item roster, item pickup/use pipeline.
4. **`03_MAPS_AND_CHAOS_EVENTS.md`** — `MapData` schema, per-map scene contract, all 4 launch maps, chaos event catalogue.
5. **`04_UI_UX_SPEC.md`** — every screen (menu, lobby, countdown, race HUD, results), layout and interaction rules.
6. **`05_ANIMATIONS_SPEC.md`** — vehicle and character animation clips, triggers, the Penguin-transform special case.
7. **`06_VFX_SPEC.md`** — particle effects per item/event/surface, performance rules.
8. **`07_ASSET_LIST.md`** — file format standards, full asset checklist, free public assets for prototyping.

## Cross-Cutting Rules (apply everywhere)

- **Server authority:** anything that affects fairness (item hits, chaos events, race results, respawns) is decided server-side and broadcast via `@rpc("authority")`. Clients send input/requests via `@rpc("any_peer")` and never self-resolve outcomes. See `01_CORE_SYSTEMS_LOGIC.md` §8.
- **Data-driven design:** vehicle stats, items, chaos events, and maps are all `Resource` (`.tres`) files, not hardcoded values in scripts. New content should be addable by adding a resource, not editing a switch statement.
- **Mobile-first:** one-thumb driving, thumb-sized touch targets, polycount/particle budgets throughout — every spec doc repeats the relevant limit where it applies.
- **Tone:** comedic, never violent/gory — explicitly called out in `06_VFX_SPEC.md` §2 and applies to any new content the agent generates.
- **Zero pay-to-win:** vehicle class is a free strategic choice; only cosmetics are monetized. Don't let any generated system gate stats behind currency.

## Known Open Questions (do not silently resolve — flag back to the user)

- Bot-fill for under-filled private rooms: yes/no.
- Exact drift→boost curve values per vehicle class.
- Final team-scoring formula for Duo/Squad (current default: sum of finishing positions — tunable).
- Final numeric balance pass across all 5 vehicle classes.
- Portrait vs. landscape as the primary mobile orientation.
