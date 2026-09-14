# AI Agent Instructions — Crazy Racer

Entry point for any AI agent working on this repo. Read this, `STYLE_GUIDE.md`, and `GAMEPLAY_RULES.md` before editing anything. These rules are based on a literal audit of the current codebase (Godot 4.7, GL Compatibility renderer) — they describe what actually exists, not aspirations.

The numbered spec docs previously in this repo (`00_PROJECT_STRUCTURE.md` through `07_ASSET_LIST.md`, `Crazy-Racer_GDD_Godot.md`) describe a different, unbuilt version of this game (5 vehicles not 8, glTF not FBX, GridMap tracks not procedural, full networked multiplayer, mobile-first). They are not present anymore and must not be treated as a reference — this file, `STYLE_GUIDE.md`, and `GAMEPLAY_RULES.md` are the only source of truth for intended design.

## -1. 🚨 Known critical bug — RESOLVED (ne pas re-casser)

**C'était :** conduite inversée (gauche → droite, haut → arrière), confirmé en play-test.
**C'est réparé et vérifié en jeu (Godot 4.7) :** haut = avant visuel (`-Z`), bas = marche arrière, gauche/droite corrects, via les actions nommées `steer_left`, `steer_right`, `throttle`, `brake` (voir `GAMEPLAY_RULES.md` §3).
**Ne re-inverse aucun signe.** Rappel du piège (convention vérifiée, pas supposée) : le forward physique `VehicleBody3D` est `+Z` (`MODEL_FRONT`, `engine_force` positive → `+Z`, `steering` positif → `+X`), tandis que le devant visuel/piste/caméra du projet est `-Z` — `vehicle_controller.gd` inverse donc aux deux endroits marqués en commentaire. Le flip directionnel intentionnel de l'item reverse (`reverse_timer`) est préservé en amont.
Les anciennes étapes de diagnostic ci-dessous restent valables comme méthode si un doute revient — mais en partant des actions nommées, plus de `ui_*` :
1. In `scripts/vehicles/vehicle_controller.gd`, locate every place `throttle`, `brake`, `steer_left`, `steer_right`, and `KEY_SPACE`/`drift` are read (around the input-handling block).
2. Trace how each maps to `engine_force`/`brake` and to `VehicleWheel3D.steering` on `WheelFL`/`WheelFR`.
3. Confirm Godot's actual convention for this project's vehicle orientation (which local axis is "forward" for the `VehicleBody3D`, and which sign of `steering` turns the front wheels left vs. right) by testing in the running game, not by assumption.
4. Fix only the sign/axis that's actually wrong — don't restructure the whole input block.
5. Re-verify all four input paths behave correctly afterward: keyboard arrows, WASD (Godot default binding for `ui_*`), gamepad, and the existing touch joystick (`touch_joystick.gd` / `touch_steer` / `touch_throttle`) — since they all feed the same variables, a fix in one place should correct all of them, but confirm each one.
6. Confirm reverse still behaves sensibly (the code intentionally flips steering direction while reversing — preserve that, don't remove it while fixing the forward-facing bug).

## 0. Architecture facts the agent must respect

- **7 autoloads**, in this order: `GameManager`, `MatchmakingService`, `LobbyManager`, `TeamManager`, `BoundaryManager`, `ChaosEventSystem`, `Audio` (`Audio` is physically at `scripts/audio/audio_manager.gd`, not under `autoload/`). Do not create a second autoload that duplicates responsibility already owned by one of these — extend the existing one.
- **All 8 vehicles (Kart, Car, Truck, Motorcycle, Bicycle, Sport, Taxi, SUV) share one script**: `scripts/vehicles/vehicle_controller.gd` (`VehicleController extends VehicleBody3D`). Per-vehicle differences come from `KartStats` resources (`assets/resources/*_stats.tres`) plus scene-level collision/mesh sizes — **not** separate scripts per vehicle. Never fork `vehicle_controller.gd` into per-entity copies; add data fields to `KartStats` instead.
- **`stats.mass` overwrites scene `mass` at runtime** (`vehicle_controller.gd` `_ready`) — the `.tres` is the source of truth. Scene masses are now synced to match (sport 900, suv 1700, taxi 1000 — fixed); keep both in sync if touching vehicle mass.
- **Single UI theme**: `assets/ui/theme.tres`, bound globally via `project.godot [gui] theme/custom`. It currently only defines `Button` normal/hover/pressed styles and a `default_font_size=22` — everything else (colors, per-widget font sizes) is set in code via `add_theme_*_override` calls scattered across the 6 UI scripts. Don't add a second `Theme` resource.
- **No pause state exists.** `GameManager.MatchPhase` is `MENU, LOBBY, COUNTDOWN, RACING, RESULTS` only.
- **Settings persistence is minimal.** Only TT (time trial) records and GP win count are saved to `user://crazy_racer.cfg`. Audio on/off, controls, and graphics quality are NOT persisted — they reset every launch. Any new persisted setting must go through this same `ConfigFile` in `game_manager.gd`, not a new save system.
- **Item effects are hardcoded.** The dead `effect_script_path` field was deleted from `ItemData` and the 5 item `.tres` (it pointed at a nonexistent `scripts/items/effects/` folder); the unreachable fallback branch in `ItemSystem._apply_to` went with it. The `match` block is the pipeline — to add an effect, add a branch there.
- **Counts match the shipped game.** 8 vehicles / 14 item IDs (5 on-disk `.tres` + 9 defined inline in `item_system.gd` as `EXTRA_DEFS`) / 4 maps — `project.godot`'s description says so. The old `00-07_*.md` specs + GDD were deleted (they described an unbuilt version: 5 vehicles, glTF, GridMap, full multiplayer); don't resurrect them as reference.

## 1. Consistency is the priority
- Reuse `KartStats`, `CharacterData`, `ItemData`, `MapData`, `ChaosEventData` — these are the project's data-schema classes (`scripts/data/*.gd`). New vehicles/characters/items/maps/events should be new `.tres` resources of these existing classes, not new ad hoc systems.
- Match the existing GDScript style: `snake_case` functions/vars, `PascalCase` classes, heavy use of `const` dictionaries for lookup tables (e.g. `UI_SCENES`, `MAP_SCENES`, `EXTRA_DEFS`) — follow that pattern for new lookup data instead of long `if/elif` chains.
- All in-game text in the audited code is in French ("COURSE", "GRAND PRIX", "CONTRE-LA-MONTRE", "Code 4 chiffres"). Keep new UI text in French unless the task says otherwise.

## 2. Scope discipline
- Don't touch `matchmaking_service.gd`, `team_manager.gd`, or the multiplayer/RPC logic in `game_manager.gd` / `boundary_manager.gd` unless the task is specifically about multiplayer — these are flagged in the audit as simplified/prototype (non-unique room codes, non-deterministic team shuffling, `peer_id==1` assumptions) and are easy to break.
- Don't rename `KartStats`/`ItemData`/`CharacterData`/`MapData`/`ChaosEventData` fields — they're referenced by string/property access across many scripts and `.tres` files.

## 3. Physics & gameplay feel
- Target feel: **arcade party racer** (Mario Kart–like), not simulation — confirmed by design: drift-charge boosting, items, chaos events, rubber-banding.
- All 8 vehicles currently share identical wheel suspension values (`suspension_stiffness=50.0`, `damping_compression/relaxation=4.0`, `friction_slip=2.5`) despite mass ranging 350–1900 and per-vehicle `KartStats` existing. If asked to improve physics feel/differentiation, this is the first place to look.
- `KartStats.drift_boost_curve` and `collision_shape_scale` are defined per-vehicle in every `.tres` but **never read** by `vehicle_controller.gd` (confirmed dead fields). Don't add new dead `@export` fields — if you add a per-vehicle tunable, wire it into the controller in the same change.
- Never change `max_steer`, drift charge rate (`+0.45/s`), or boost thresholds (`0.35/0.6s`, `0.7/1.2s`, `0.99/1.9s`) without documenting old/new values, since these define the whole handling feel.

## 4. UI/UX
- No custom font file exists in the project (0 `.ttf`/`.otf`). `theme.tres` has an empty, unused `FontVariation font_main`. Any font work should either wire a real font into that slot or remove the dead sub-resource.
- `Button/styles/pressed` currently equals `Button/styles/hover` (same sub-resource) — there is no distinct pressed state, and no `disabled` or `focus` style at all (confirmed: `disabled` buttons exist in code — `lobby_screen._start_btn`, `race_hud._item_btn` — with no visual treatment).
- Every UI script (`main_menu.gd`, `lobby_screen.gd`, `countdown_overlay.gd`, `race_hud.gd`, `results_screen.gd`) currently hardcodes its own `Color(...)` values inline rather than pulling from a shared palette — there are 150+ literal `Color(...)` calls across the codebase. Prefer consolidating repeated ones (e.g. the gold `(1,0.88,0.3)` used for titles/records in 4+ places) into named constants.

## 5. Settings & controls
- Only two custom input actions exist: `drift` (Space / Joypad button 7) and `item_use` (E / Joypad button 2). Steering/throttle use Godot's **built-in** `ui_up/down/left/right` — these are not redefined in `project.godot`, so there's no in-game way to see or remap them.
- Touch input already exists (`touch_joystick.gd`, `touch_steer`/`touch_throttle`/`touch_drift` vars) — any new control scheme work must keep keyboard, gamepad, and touch in sync, matching this existing pattern.
- Any new persisted setting (audio volume, control remap, graphics quality) goes into `GameManager`'s existing `ConfigFile` at `user://crazy_racer.cfg`, alongside the current `tt/<map_id>` and `carriere/gp_wins` keys.

## 6. Before finishing any task
- Confirm the project still opens/runs without new missing-resource warnings (watch for the FBX/wheel-hiding logic in `model_factory.gd` and the FBX mounting in `vehicle_mesh_builder.gd`'s `REAL_MODELS`, which is name-string-matched and easy to silently break).
- If you changed a `KartStats`, `ItemData`, `MapData`, or `ChaosEventData` field, grep for every script that reads it (the audit's §4 lists them) to confirm nothing was left stale.
- Update `STYLE_GUIDE.md` / `GAMEPLAY_RULES.md` if the change affects what they document.
