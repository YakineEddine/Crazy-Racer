# 00 — Project Structure

Godot 4.x project. GDScript primary. This file is the authoritative folder/naming reference — every other doc assumes these paths.

## 1. Folder Tree

```
res://
├── autoload/                        # Autoload singletons (Project Settings > Autoload)
│   ├── game_manager.gd
│   ├── lobby_manager.gd
│   ├── team_manager.gd
│   ├── matchmaking_service.gd
│   ├── chaos_event_system.gd
│   └── boundary_manager.gd
│
├── assets/
│   ├── vehicles/{kart,car,truck,motorcycle,bicycle}/{models,textures,vfx}/
│   ├── characters/{human,crocodile,penguin,chicken}/
│   ├── items_props/{reverse_gun,shrink_ray,chicken_storm,banana_boost,rocket,item_box}/
│   ├── environment/chaos_events/{meteor,collapsing_bridge,gravity_flip,ice_patch}/
│   ├── environment/boundary_dressing/{map1,map2,map3,map4}/
│   ├── maps/{map1_neon_circuit_city,map2_swamp_gator_gp,map3_frozen_waddle_way,map4_barnyard_bedlam}/
│   ├── ui/{lobby,race_hud,results_podium,icons}/
│   ├── audio/{voice_barks,sfx,music,ambience}/
│   └── resources/                    # .tres data files
│
├── scenes/
│   ├── vehicles/                     # kart.tscn, car.tscn, truck.tscn, motorcycle.tscn, bicycle.tscn
│   ├── characters/
│   ├── items/
│   ├── ui/
│   └── maps/
│
├── scripts/
│   ├── vehicles/
│   ├── items/
│   ├── chaos_events/
│   ├── networking/
│   └── data/                         # Resource class_name scripts (KartStats.gd, etc.)
│
└── shaders/
```

## 2. Naming Conventions

- Files/folders: `snake_case`.
- Classes: `class_name PascalCase`.
- Scenes: match their root node's script class name in snake_case, e.g. `kart_controller.gd` → `kart.tscn`.
- Signals: past-tense verbs, e.g. `checkpoint_crossed`, `chaos_event_triggered`, `race_finished`.
- Resource data files: `<id>_stats.tres`, e.g. `kart_stats.tres`, `truck_stats.tres`.

## 3. Autoload Load Order

Register in this order in Project Settings > Autoload (dependencies flow top to bottom):

1. `GameManager` — match phase, global timers, current format
2. `MatchmakingService` — depends on GameManager for format
3. `LobbyManager` — depends on MatchmakingService
4. `TeamManager` — depends on LobbyManager
5. `BoundaryManager` — depends on GameManager (match phase gate)
6. `ChaosEventSystem` — depends on GameManager + BoundaryManager

## 4. Scene Instancing Pattern

- Each map is one `.tscn` in `scenes/maps/`.
- Vehicles, characters, and items are separate reusable scenes instanced at runtime — never hardcoded into a map scene.
- UI screens are separate scenes swapped via a single `CanvasLayer` root managed by `GameManager` (see `05_UI_UX_SPEC.md`).

## 5. Related Docs

- `01_CORE_SYSTEMS_LOGIC.md` — autoload internals, networking, signals
- `02_VEHICLES_AND_ITEMS.md` — vehicle classes, item logic
- `03_MAPS_AND_CHAOS_EVENTS.md` — map structure, boundary system, chaos events
- `04_UI_UX_SPEC.md`
- `05_ANIMATIONS_SPEC.md`
- `06_VFX_SPEC.md`
- `07_ASSET_LIST.md`
