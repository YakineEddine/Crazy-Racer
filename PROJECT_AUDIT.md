# PROJECT_AUDIT — Crazy Racer (Godot)

> Generated 2026-09-14 from literal file/code inspection (Godot 4.7 project). No summaries, no guesses. Paths are `res://`-relative unless noted. Absolute workspace: `C:\Users\USER\Desktop\Crazy Racer`.

---

## 1. Project structure

### 1.1 Full tree (excluding `.git/`, `.godot/` import cache, `*.import` files)

```text
C:\Users\USER\Desktop\Crazy Racer\
├─ .gitignore
├─ AI_AGENT_INSTRUCTIONS.md
├─ GAMEPLAY_RULES.md
├─ LIREMOI-JOUER.md
├─ PROJECT_AUDIT.md
├─ README.md
├─ STYLE_GUIDE.md
├─ icon.svg
├─ project.godot
├─ assets\
│  ├─ fonts\
│  │  ├─ OFL.txt
│  │  └─ TitanOne-Regular.ttf
│  ├─ models\
│  │  ├─ cars\ (Cop.fbx, NormalCar1.fbx, NormalCar2.fbx, SportsCar.fbx, SportsCar2.fbx, SUV.fbx, Taxi.fbx)
│  │  ├─ dino\ (Apatosaurus.fbx, Parasaurolophus.fbx, Stegosaurus.fbx, Trex.fbx, Triceratops.fbx, Velociraptor.fbx)
│  │  └─ farm\ (Cow.fbx, Horse.fbx, Llama.fbx, Pig.fbx, Pug.fbx, Sheep.fbx, Zebra.fbx)
│  ├─ resources\ (banana_boost.tres, bicycle_stats.tres, car_stats.tres, character_chicken.tres, character_cow.tres, character_crocodile.tres, character_horse.tres, character_human.tres, character_llama.tres, character_penguin.tres, character_pig.tres, character_pug.tres, character_sheep.tres, character_zebra.tres, chicken_storm.tres, event_collapse.tres, event_dino.tres, event_gravity.tres, event_meteor.tres, kart_stats.tres, map1_data.tres, map2_data.tres, map3_data.tres, map4_data.tres, motorcycle_stats.tres, reverse_gun.tres, rocket.tres, shrink_ray.tres, sport_stats.tres, suv_stats.tres, taxi_stats.tres, truck_stats.tres)
│  └─ ui\ (theme.tres)
├─ autoload\ (boundary_manager.gd, chaos_event_system.gd, game_manager.gd, lobby_manager.gd, matchmaking_service.gd, team_manager.gd + one .gd.uid sidecar each)
├─ scenes\
│  ├─ main.tscn
│  ├─ items\ (item_box.tscn)
│  ├─ maps\ (map1_neon_circuit_city.tscn, map2_swamp_gator_gp.tscn, map3_frozen_waddle_way.tscn, map4_barnyard_bedlam.tscn)
│  ├─ ui\ (countdown_overlay.tscn, lobby_screen.tscn, main_menu.tscn, pause_menu.tscn, race_hud.tscn, results_screen.tscn)
│  └─ vehicles\ (bicycle.tscn, car.tscn, kart.tscn, motorcycle.tscn, sport.tscn, suv.tscn, taxi.tscn, truck.tscn)
├─ scripts\
│  ├─ main.gd (+ .uid)
│  ├─ audio\ (audio_manager.gd + .uid)
│  ├─ data\ (chaos_event_data.gd, character_data.gd, item_data.gd, kart_stats.gd, map_data.gd + .uid each)
│  ├─ items\ (coin.gd, item_box.gd, item_system.gd, projectile.gd + .uid each)
│  ├─ maps\ (map_builder.gd + .uid)
│  ├─ ui\ (countdown_overlay.gd, lobby_screen.gd, main_menu.gd, pause_menu.gd, race_hud.gd, results_screen.gd, touch_joystick.gd + .uid each)
│  ├─ utils\ (model_factory.gd + .uid)
│  ├─ vehicles\ (driver_builder.gd, vehicle_controller.gd, vehicle_mesh_builder.gd + .uid each)
│  └─ vfx\ (vfx_factory.gd + .uid)
└─ shaders\ (gravity_flip.gdshader + .gdshader.uid)
```

### 1.2 File counts by extension (verified via recursive filesystem listing, `.git/`/`.godot/`/`*.import` excluded)

| Ext | Count | Ext | Count |
|---|---|---|---|
| `.gd` | 30 | `.tscn` | 20 |
| `.tres` | 33 | `.fbx` | 20 |
| `.uid` | 31 | `.md` | 6 |
| `.ttf` | 1 | `.txt` | 1 |
| `.svg` | 1 | `.gdshader` | 1 |
| `.gitignore` | 1 | `.cs` / `.png` / `.jpg` / `.webp` / `.otf` / `.wav` / `.ogg` / `.mp3` | 0 each |

### 1.3 Purpose of each top-level folder

- `autoload/` — 6 Godot autoload singletons (`GameManager`, `MatchmakingService`, `LobbyManager`, `TeamManager`, `BoundaryManager`, `ChaosEventSystem`); game state, rooms, rules. (`Audio` autoload lives under `scripts/audio/`.)
- `assets/` — static content: `models/` (20 Quaternius FBX), `resources/` (32 gameplay `Resource` `.tres`), `fonts/` (Titan One TTF + OFL license), `ui/` (sole `Theme`).
- `scenes/` — all 20 `PackedScene`s: boot root, 8 vehicles, 4 maps, 6 UI screens, 1 item box.
- `scripts/` — all 24 non-autoload gameplay scripts, grouped by subsystem (`audio`, `data`, `items`, `maps`, `ui`, `utils`, `vehicles`, `vfx`) + boot `main.gd`.
- `shaders/` — 1 canvas-item shader (gravity-flip HUD overlay).
- Root `.md` files — agent/player docs (`AI_AGENT_INSTRUCTIONS.md`, `GAMEPLAY_RULES.md`, `STYLE_GUIDE.md`, `LIREMOI-JOUER.md`, `README.md`) + this audit. The old `00–07_*.md` specs + GDD are deleted.
- `icon.svg` — project icon. `project.godot` — engine config. `.gitignore` — ignores `.godot/`, `*.tmp`, `*.log`, builds, OS files.

---

## 2. Engine & project config

Source: `project.godot` (`config_version=5`), verified verbatim.

### 2.1 Godot version and renderer

- `config/features=PackedStringArray("4.7", "GL Compatibility")` → **Godot 4.7, Compatibility (GL) renderer**.
- `[rendering] renderer/rendering_method="gl_compatibility"` and `renderer/rendering_method.mobile="gl_compatibility"`. **Not** Forward+ or Mobile.
- `textures/vram_compression/import_etc2_astc=true`; `anti_aliasing/quality/msaa_3d=2`.
- `[animation] compatibility/default_parent_skeleton_in_mesh_instance_3d=true`.
- `[application]`: `config/name="Crazy Racer"`; `config/description="Party kart racer chaotique — 8 vehicules, 14 objets, 4 maps, chaos events."`; `run/main_scene="res://scenes/main.tscn"`; `config/icon="res://icon.svg"`.

### 2.2 Display / window settings

```ini
[display]
window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

No other `[display]` keys. No orientation, DPI, or multi-window keys in file.

### 2.3 GUI theme binding

```ini
[gui]
theme/custom="res://assets/ui/theme.tres"
```

### 2.4 Autoloads / singletons (file order in `[autoload]`)

1. `GameManager="*res://autoload/game_manager.gd"`
2. `MatchmakingService="*res://autoload/matchmaking_service.gd"`
3. `LobbyManager="*res://autoload/lobby_manager.gd"`
4. `TeamManager="*res://autoload/team_manager.gd"`
5. `BoundaryManager="*res://autoload/boundary_manager.gd"`
6. `ChaosEventSystem="*res://autoload/chaos_event_system.gd"`
7. `Audio="*res://scripts/audio/audio_manager.gd"`

### 2.5 Physics settings

File contains literally only:

```ini
[physics]
3d/physics_engine="GodotPhysics3D"
```

Absent from file: physics ticks/FPS (`physics/common/physics_ticks_per_second`), `physics/3d/default_gravity`, damping defaults, `layer_names/3d_physics/layer_*` (engine defaults apply: 60 Hz, 9.8 gravity, unnamed layers). Runtime code sets `ProjectSettings "physics/3d/default_gravity"` to `-9.8`/`9.8` during gravity-inversion chaos and per-vehicle `gravity_scale ∓1.0` (`autoload/chaos_event_system.gd:129-133`). Collision layers/masks used in scenes/code (not in `project.godot`): vehicle bodies default 1/1; vehicle `Detector` Areas `0/7`; item boxes `2/1`; boost pads and coins `1/0` (`monitoring=false`, `monitorable=true`); shells and dino-hit Areas `0/1`; banana trails defaults.

### 2.6 Input map — every action (all `deadzone=0.2`)

Keycodes: Space=32, E=69 (unicode 101), Left=4194319, Right=4194321, Up=4194320, Down=4194322, Escape=4194305, A/D/W/S by physical 65/68/87/83. Joypad: 2=X/Square (item), 6=Start (pause), 7=L3 (drift), 11/12/13/14=D-pad Up/Down/Left/Right; Motion axis 0=X (left −1.0 / right +1.0), axis 1=Y (up −1.0 / down +1.0).

| Action | Events |
|---|---|
| `drift` | Key Space (keycode 32 + physical 32, unicode 32); JoyButton 7 |
| `item_use` | Key E (keycode 69, physical 0, unicode 101); JoyButton 2 |
| `steer_left` | Key Left (4194319+4194319); Key physical A (65, keycode 0); JoyButton 13; JoyMotion axis 0 −1.0 |
| `steer_right` | Key Right (4194321+4194321); Key physical D (68); JoyButton 14; JoyMotion axis 0 +1.0 |
| `throttle` | Key Up (4194320+4194320); Key physical W (87); JoyButton 11; JoyMotion axis 1 −1.0 |
| `brake` | Key Down (4194322+4194322); Key physical S (83); JoyButton 12; JoyMotion axis 1 +1.0 |
| `pause` | Key Escape (keycode 4194305, physical 0 — byte-identical convention to built-in `ui_cancel`); JoyButton 6 |

No other `[input]` actions. Built-in `ui_*` actions are still referenced nowhere in gameplay code (all driving input uses the 7 named actions; verified by grep).

---

## 3. Scenes

20 `.tscn` files, all `format=3`. UI scenes (6) are all the identical minimal pattern — single root `UI (Control)` full-rect (`layout_mode=3, anchors_preset=15, anchor_right=1.0, anchor_bottom=1.0, grow_horizontal=2, grow_vertical=2`) + one script, no sub-resources/children/connections; all widgets are built in code. Map scenes (4) are all single root `Node3D` + `map_builder.gd` + `map_id` override only.

### 3.1 `scenes/main.tscn` (`load_steps=4`)

- Ext: `1` Script `res://scripts/main.gd`; `2` Script `res://scripts/items/item_system.gd`. No sub-resources, no connections.
- Tree: `Main (Node3D, script=ExtResource 1)` → `MapHolder (Node3D)`, `ItemSystem (Node, script=ExtResource 2)`, `UILayer (CanvasLayer)`.

### 3.2 `scenes/items/item_box.tscn` (`load_steps=6`)

- Ext: `1` Script `res://scripts/items/item_box.gd`.
- Sub: `BoxShape3D box_col size Vector3(2.0,2.0,2.0)`; `BoxMesh box_mesh size Vector3(1.2,1.2,1.2)`; `StandardMaterial3D box_mat albedo Color(0.3,0.7,1,1), emission_enabled, emission Color(0.3,0.7,1,1), emission_energy_multiplier=1.5`.
- Tree: `ItemBox (Area3D, layer 2, mask 1, script)` → `Collision (CollisionShape3D, shape=box_col)`; `Mesh (MeshInstance3D, origin (0,1,0), mesh=box_mesh, override=box_mat)`. No connections.

### 3.3 Map scenes (`load_steps=2` each)

- `map1_neon_circuit_city.tscn`: `NeonCircuitCity (Node3D, script=map_builder.gd, map_id="map1_neon")`.
- `map2_swamp_gator_gp.tscn`: `SwampGatorGP (Node3D, map_id="map2_swamp")`.
- `map3_frozen_waddle_way.tscn`: `FrozenWaddleWay (Node3D, map_id="map3_ice")`.
- `map4_barnyard_bedlam.tscn`: `BarnyardBedlam (Node3D, map_id="map4_farm")`.

### 3.4 UI scenes (`load_steps=2` each; root + script only)

- `main_menu.tscn` → `scripts/ui/main_menu.gd`; `lobby_screen.tscn` → `lobby_screen.gd`; `countdown_overlay.tscn` → `countdown_overlay.gd`; `race_hud.tscn` → `race_hud.gd`; `results_screen.tscn` → `results_screen.gd`; `pause_menu.tscn` → `pause_menu.gd`.

### 3.5 Vehicle scenes (8×, `load_steps=9` each, identical layout)

Common to all: root `VehicleBody3D` (`script=vehicle_controller.gd`, `stats=<class>_stats.tres`, `peer_id=1`, `character_id="human"`) + 17 children: `CollisionShape3D` (origin (0,0.4,0)), `Body (MeshInstance3D)` (origin (0,0.55,0)), `WheelFL/FR` (`VehicleWheel3D`, traction+steering), `WheelRL/RR` (traction only) — all wheels `radius 0.35, rest 0.3, travel 0.2, stiffness 50.0, damping 4.0/4.0, friction_slip 2.5` (scene fallback; runtime overwrites stiffness/damping/friction from stats) — plus `WheelMeshFL/FR/RL/RR (MeshInstance3D, BoxMesh 0.35³-ish 0.35×0.35×0.3)`, `Detector (Area3D, layer 0, mask 7, monitoring, not monitorable)` → `DetectorShape (SphereShape3D r=2.0)`, `DriftTrailAnchorL/R (Marker3D, (∓0.8,0.2,−1.2))`, `BoostTrailAnchor ((0,0.6,−1.5))`, `ItemHoldAnchor ((0,1.4,0))`, `MultiplayerSynchronizer`. Connections on all 8: `Detector area_entered → _on_detect_area`, `area_exited → _on_detect_exit`. Sub-resources per file: `col_kart (BoxShape3D)`, `mesh_kart (BoxMesh)`, `detect_kart (SphereShape3D r=2.0)`, `mesh_wheel (BoxMesh 0.35,0.35,0.3)`.

Per-file differences:

| File | Root / mass | Stats | `col_kart` / `mesh_kart` | Wheel X / Y |
|---|---|---|---|---|
| `kart.tscn` | Kart 800.0 | `kart_stats.tres` | (1.6,1.0,2.8) / (1.6,0.6,2.6) | ±0.85 / 0.0 |
| `car.tscn` | Car 1100.0 | `car_stats.tres` | (1.8,1.0,3.2) / (1.8,0.55,3.0) | ±0.85 / 0.0 |
| `truck.tscn` | Truck 1900.0 | `truck_stats.tres` | (2.4,1.4,3.8) / (2.2,1.0,3.6) | ±1.05 / 0.2 |
| `motorcycle.tscn` | Motorcycle 550.0 | `motorcycle_stats.tres` | (1.0,1.0,2.4) / (0.9,0.5,2.2) | ±0.45 / 0.0 |
| `bicycle.tscn` | Bicycle 350.0 | `bicycle_stats.tres` | (0.9,1.0,2.0) / (0.7,0.5,2.0) | ±0.4 / 0.0 |
| `sport.tscn` | Sport 900.0 | `sport_stats.tres` | (1.8,1.0,3.2) / (1.8,0.55,3.0) | ±0.85 / 0.0 |
| `taxi.tscn` | Taxi 1000.0 | `taxi_stats.tres` | (1.8,1.0,3.2) / (1.8,0.55,3.0) | ±0.85 / 0.0 |
| `suv.tscn` | SUV 1700.0 | `suv_stats.tres` | (2.4,1.4,3.8) / (2.2,1.0,3.6) | ±1.05 / 0.2 |

Scene-mass vs stats-mass: all 8 now match (sport 900, taxi 1000, SUV 1700 were synced from stale 1100/1100/1900 to their `.tres`); runtime still uses stats (`vehicle_controller._ready:65 mass = stats.mass`, verified in-engine).

---

## 4. Scripts

30 `.gd` files, 0 `.cs` files. `class_name` on 10 files (VfxFactory, ModelFactory, ShellProjectile, CoinPickup, ItemSystem, ChaosEventData, CharacterData, MapData, KartStats, ItemData, MapBuilder, DriverBuilder, VehicleController, VehicleMeshBuilder — 14; autoloads + UI + main/item_box/touch/audio have none). `@export` on 7 files only (data schemas ×5, item_box, vehicle_controller).

### 4.1 `autoload/game_manager.gd` — extends Node, autoload `GameManager`, no scene

Central state machine (`MENU, LOBBY, COUNTDOWN, RACING, RESULTS, PAUSED` = 0–5, `game_manager.gd:5`); server-authoritative phase changes + RPC; quick-play/GP/TT entry; map load; grid spawn + chase cams; race timer; GP points; TT records; `settings` persistence; pause/resume; smoothed chase cams. Exports: NONE.
Magic numbers: `GP_TABLE [15,12,10,9,8,7,6,5,4,3,2,1]` (:30); `SAVE_PATH "user://crazy_racer.cfg"` (:31); `CAM_OFFSET (0,3.2,6.5)`, `CAM_PITCH_DEG -14.0`, `CAM_POS_SMOOTH 6.0`, `CAM_YAW_SMOOTH 5.0` (:40–43); UI fade `modulate:a→1.0, 0.25s`; countdown `3.5s`; race timeout `600.0s`; volume clamp `0..1`; fallback grid `(0,2,−idx*6.0)`; `cam.fov=70.0`.

### 4.2 `autoload/matchmaking_service.gd` — Node, autoload `MatchmakingService`

Local-prototype per-format queue; forms lobby at quota into LobbyManager. Exports: NONE.
Magic: quotas 1v1→2, duo→4, squad→8, ffa→4, default 2; skill stub returns `0.0`.

### 4.3 `autoload/lobby_manager.gd` — Node, autoload `LobbyManager`

Rooms (4-digit codes `randi_range(0,9)`×4, length check 4), players dict, ready/vehicle/character setters, format slot validation (1v1 n==2; duo n≥2 even ≤16; squad n≥4 %4==0 ≤16; ffa 1–16), bot fill (targets 4, 1v1→2, ffa→6; bot ids `-(100+i)`), `FORMAT_SLOTS`, `max_players=16`. Exports: NONE.

### 4.4 `autoload/team_manager.gd` — Node, autoload `TeamManager`

Team assign (shuffle; 1v1/ffa solo, duo pairs `i+=2`, squad quads `for k in 4`/`i+=4`), finish register, score = Σ positions (missing = 99), ranking sort (default 9999.0). Exports: NONE.

### 4.5 `autoload/boundary_manager.gd` — Node, autoload `BoundaryManager`

Bounds/checkpoints/laps authority keyed by peer_id; absolute box `|x|>78, |z|>58, y<−2 or >30`; `off_track_delay=2.5`; respawn lift `+Vector3(0,1.5,0)`; checkpoint total `maxi(n,2)`; soft-zone default factor `0.5`. Exports: NONE.

### 4.6 `autoload/chaos_event_system.gd` — Node, autoload `ChaosEventSystem`

Loads 4 event resources; max 1 simultaneous; per-map weighted pick; gravity `∓9.8` + `gravity_scale ∓1.0`; expires after `duration`. `min_interval=25.0`, `max_interval=45.0`, first-event `randf_range(12.0,18.0)`. Exports: NONE.

### 4.7 `scripts/main.gd` — Node3D, root of `main.tscn`

Boot: registers UILayer/MapHolder with GameManager, forces MENU via LOBBY→MENU. Exports: NONE. No literals.

### 4.8 `scripts/utils/model_factory.gd` — `class_name ModelFactory extends RefCounted`, static-only

Defensive FBX instantiate, substring anim match w/ first-clip fallback, wheel-node hiding by name, uniform scale. Exports: NONE. No tuning literals.

### 4.9 `scripts/items/projectile.gd` — `class_name ShellProjectile extends Area3D`, runtime-only (`ShellProjectile.new()`)

Green straight / red homing shells; own sphere mesh+collider; lifetime/owner/altitude expiry. Exports: NONE.
Magic: `speed=30.0`, `life=6.0`; mesh r=0.45 h=0.9, emission ×1.5; collider r=0.6; fallback fwd (0,0,1) if <0.1; spawn offset fwd×2.5+(0,1,0); homing lerp `3.0*delta`, deadzone 0.5; kill if y<−2 or >40.

### 4.10 `scripts/items/item_system.gd` — `class_name ItemSystem extends Node`, on `ItemSystem` in `main.tscn`

14-item pipeline: 5 `ItemData` resources + 9 `EXTRA_DEFS`; weighted roll; server-validated uses; cooldowns; nearest-ahead (behind bias dot<−0.2 → ×0.6); shells/lightning/buffs/banana trails + client rebroadcast. Exports: NONE.
Magic: weights banana 1.1, triple 0.5, mushroom 1.1, triple 0.5, green 1.0, red 0.8, shield 0.7, star 0.35/6.0s, lightning 0.3/3.0s; synth cooldown 1.0; banana_boost 1.2s + 6s trail (box 2.0×0.5×4.0, mesh 2.0×0.2×4.0, `Color(1,0.9,0.2,0.6)`, offset (0,0.2,4.0)); mushroom 1.1s; star 6.0s; rocket 7.0s; shell colors green `(0.2,0.9,0.2)` / red `(0.9,0.15,0.15)`; unreachable `_:` branch = `pass`.

### 4.11 `scripts/items/item_box.gd` — Area3D, root of `item_box.tscn`

Spin/bob pickup (TT-suppressed, server-validated), hide+respawn + RPC notify. Exports: `@export var respawn_delay: float = 5.0`. Magic: spin 2.0 rad/s, bob `1.0+sin(t*3.0)*0.15`.

### 4.12 `scripts/items/coin.gd` — `class_name CoinPickup extends Area3D`, runtime-only (`CoinPickup.create()`)

Gold coin + trigger; `add_coin()` (cap enforced by vehicle); respawn. Exports: NONE (`respawn_delay=8.0` plain var).
Magic: trigger r=1.4; mesh r=0.55 h=0.12 at (0,1,0); `Color(1.0,0.84,0.1)`, metallic 0.7, roughness 0.25, emission `Color(1.0,0.8,0.2)` ×0.6; spin 2.5, bob `1.0+sin*0.12`.

### 4.13 `scripts/data/chaos_event_data.gd` — `class_name ChaosEventData extends Resource`

Schema for chaos events. Exports: `id="gravity_inversion"`, `display_name="Inversion Gravite"`, `description=""`, `duration=10.0`, `banner_color=Color(0.6,0.3,1.0)`, `base_weight=1.0`.

### 4.14 `scripts/data/character_data.gd` — `class_name CharacterData extends Resource`

Driver schema. Exports: `character_id="human"`, `display_name="Pilote"`, `body_color=Color(1.0,0.8,0.6)`, `accent_color=Color(0.2,0.5,1.0)`, `voice_pitch=1.0`.

### 4.15 `scripts/data/map_data.gd` — `class_name MapData extends Resource`

Map metadata. Exports (10): `map_id="map1_neon"`, `display_name="Neon Circuit City"`, `checkpoint_count=4`, `shortcut_description=""`, `weighted_events={}`, `scene_path="res://scenes/maps/map1_neon_circuit_city.tscn"`, `theme_color_ground=Color(0.08,0.08,0.16)`, `theme_color_track=Color(0.15,0.15,0.28)`, `theme_color_wall=Color(1.0,0.18,0.53)`, `laps_to_win=3`.

### 4.16 `scripts/data/kart_stats.gd` — `class_name KartStats extends Resource`

Vehicle tuning schema (16 exports): `display_name="Kart"`, `top_speed=22.0`, `acceleration=14.0`, `turning_radius=0.6`, `mass=1.0`, `drift_boost_curve: Curve` (null default), `collision_shape_scale=Vector3(1.0,1.0,1.6)`, `is_plow_class=false`, `knockback_multiplier=1.0`, `ignores_size_hazards=false`, `body_color=Color(0.2,0.7,1.0)`, `boost_power=12.0`, `suspension_stiffness=50.0`, `damping_compression=4.0`, `damping_relaxation=4.0`, `wheel_friction_slip=10.5`.

### 4.17 `scripts/data/item_data.gd` — `class_name ItemData extends Resource`

Item schema (8 exports): `id="banana_boost"`, `display_name="Banana Super Boost"`, `description=""`, `pickup_rarity=1.0`, `effect_duration=4.0`, `cooldown=1.0`, `icon_color=Color(1.0,0.9,0.2)`, `is_self_target=false`. (Former `effect_script_path` field deleted; no code refs remain.)

### 4.18 `scripts/maps/map_builder.gd` — `class_name MapBuilder extends Node3D`, root of all 4 map scenes

Procedural oval builder: sky/ground/ring-road/dashes/gantry, 4–5 checkpoints + 16 spawns, 8 item boxes (no TT), 2 boost pads, coin rows, 4 chaos zones, collapsible shortcut + blocker, drivable volume + soft zones, per-theme dressing, dino/meteor actors, empty GridMap stub. Exports: `@export var map_id: String = "map1_neon"`.
Magic (principal): GridMap cell (10,1,10); ground box (300,1,300) at y−0.6; straights (120,0.2,12) z=∓40 / sides (12,0.2,68) x=∓60 / corners (14,0.2,14), y=0.05; road test straights |x|≤67 z∈[33.5,46.5], sides |z|≤46.5 x∈[53.5,66.5], shortcut |z|≤4.5 |x|≤51; dashes (2.2,0.04,0.35) x −56..60 step 8, y 0.17; gantry pillars (±7.5,3,−40) 0.8×6×0.8, beam (16,1.2,1) y 6.2; pads (25,0,−40)/(−25,0,40), box (4,2,4), mesh (4,0.15,4), `Color(0.2,0.9,1.0)` emission 2.0; coins x −40..40 step 8 + shortcut row step 10; walls h=4.0 outer (140,4,1) z=±49 + (1,4,100) x=±69, inner (108,4,1) z=±31 + (1,4,64) x=±51; checkpoints box (w,4,6) w=12 (6.0 sides), arch y 3.2, pillars y 1.6, start `Color(1,0.88,0.2)` else `Color(0.3,1,0.5)`; spawns 16 at (−14+col×4, 0.6, −36+row×4) rot y 90°; shortcut zone (100,3,8), bridge (100,0.2,6), blocker (6,4,8) y 1.5, collapse y −1.2, ice friction 0.15; drivable (170,60,130) at y 20; soft (10,3,10) ×0.5; sky/ambient/fog/sun/moon per-theme literals; dressing counts (26 towers, 40 trees, 22 spikes, aurora (180,14,6) at (0,42,−60)); windmill 0.8 rad/s; dinos scales 0.35/0.42/0.30, lanes ±40, traverse ∓85→±85 in 9.0s, hit r=2.4, tick 3.0s; meteors telegraph r=1.5/0.8s, rock r=1.2 fall +12→+0.8 in 0.5s, hit r<4.0 power 10.0, cleanup 8.0s, tick 1.2s.

### 4.19 `scripts/ui/touch_joystick.gd` — Control, runtime-only (`set_script` by race_hud)

One-thumb steer −1..1 (`value=d.x/radius`), writes `touch_steer`, custom-drawn base/knob. Exports: NONE. Magic: `radius=90.0`, `knob_radius=34.0`, min size (200,200); base `Color(1,1,1,0.15)`, ring `Color(1,1,1,0.5)` w=3.0; knob `Color(1,0.18,0.53,0.8)` + white w=2.0.

### 4.20 `scripts/audio/audio_manager.gd` — Node, autoload `Audio`

Procedural SFX (slides/tones/melodies/noise) + engine/skid/music loops; round-robin voices; voice-pitched vocals; engine by speed; persisted volume/music. Exports: NONE.
Magic: `RATE=22050`; 8 players −8.0 dB; engine tone (110 Hz, 0.5s) −17.0 dB; skid noise (0.4s) −60.0 dB; music −20.0 dB; recipes pickup 500→1050/0.12s, roulette 1250/0.04s, coin [988/0.07, 1319/0.22], boost 200→1250/0.45s, pad 300→950/0.3s, hit 140/0.25s square, shell 850→280/0.2s, beep 880/0.12s, go 1318/0.45s, shield 900→1800/0.15s, star [660,830,990,1320], lightning 0.6s, chicken [700,500,820]; voice pitch rand 0.97–1.03, clamp 0.5–2.0; `VOICE_SFX=["chicken","hit","star"]`, `CHAR_RES="res://assets/resources/character_%s.tres"`; engine pitch `(0.7+clamp(speed/top,0,1.2))×voice` clamp 0.5–2.0, top default 22.0; skid −16.0 vs −60.0 lerp ×6.0; bus mute ≤0.001 else `linear_to_db(clamp(v,0.001,1.0))`; music chiptune step 0.25s, roots [130.8,98.0,110.0,87.3].

### 4.21 `scripts/ui/results_screen.gd` — Control, root of `results_screen.tscn`

Single (podium+standings+team+XP/confetti) / GP manche/champion / TT branches + rematch/menu + celebration calls. Exports: NONE.
Magic: margins 30/30/16/16, sep 8; title 40 gold; podium (200,130/150); scroll (0,150); buttons (210,56); TT 34/24/30/22; GP 22/20/26; XP target 100+10×n, rate 240×delta+1, coins XP/2; confetti 160/2.5s/preprocess 1.0/rect(640,10)/dir(0,1)/spread 25/gravity (0,220)/vel 60–160/scale 3–6/`Color(1,0.85,0.25)` at y 0.05.

### 4.22 `scripts/ui/race_hud.gd` — Control, root of `race_hud.tscn`

Position/lap/time/coin, top-8 standings (0.5s), minimap, chaos banner, gravity overlay, drift bar, item button + roulette (90 ms scroll), joystick + DRIFT + AUTO + pause (120×44 at (−60,84), CENTER_TOP) buttons, hit flash, team line; `pause` action → toggle. Exports: NONE.
Magic: fonts 30/20/17/24/28/16, outlines 6/5; minimap (220,160) at (−236,12); standings (−236,180) min (220,200); banner (520,64) at (−260,12), 2.5s, slide −70→12/0.3s; joystick (200,200) at (24,−224); DRIFT (120,56) at (240,−120); AUTO (140,56) at (240,−190); boost bar (300,12) at (−150,−30); item (150,150) at (−174,−174) font 20; flash alpha 0.45 decay ×0.8 0.6s; score lap×100+cp; minimap map x (p.x+70)/140, z (p.z+50)/100, dots 6.0/4.0.

### 4.23 `scripts/ui/pause_menu.gd` — Control, root of `pause_menu.tscn`, `PROCESS_MODE_ALWAYS`

Pause: resume, settings (music toggle, volume 0–100 slider live-apply/save-on-release, high/low quality), quit-to-menu, Esc/Start hint + resume handler. Exports: NONE.
Magic: bg `Color(0.06,0.06,0.14,0.92)`; margins 30/30/16/16; sep 10; fonts 40/24/18/14; buttons (260,56)/(260,48)/(220,48); slider 0–100 step 1.0 min (300,40); label min (150,40); volume `v/100.0`; hint `Color(0.7,0.7,0.8)`.

### 4.24 `scripts/ui/main_menu.gd` — Control, root of `main_menu.tscn`

Format/map toggles, Course/GP/TT, private room (create + 4-char join), TT records/GP wins, hints, persisted music toggle. Exports: NONE.
Magic: gradient `(0.1,0.06,0.24)→(0.02,0.02,0.08)`; title 54 gold, sub 18, modes 22, records 16, hint 14; buttons (90,50)/(170,60)/(190,60)/(240,60)/(190,48)/(150,48)/(120,48)/(200,40); `max_length=4`.

### 4.25 `scripts/ui/lobby_screen.gd` — Control, root of `lobby_screen.tscn`

Code/format header, 16-slot list (ready dots green `Color(0.3,1,0.4)` vs gray `Color(0.5,0.5,0.55)`, dot (18,18)), vehicle/character carousels, stat bars normalized by 26.0/19.0/1.0, quit/ready/start (`disabled = not can_start()`). Exports: NONE.
Magic: bg `Color(0.07,0.08,0.18)`; margins 24/24/16/16; code font 36; scroll min (0,220); carousel (56,56)/(170,56); bars (120,12); bottom buttons (90,48)/(140,56)/(160,56)/(220,56).

### 4.26 `scripts/ui/countdown_overlay.gd` — Control, root of `countdown_overlay.tscn`

3.5s 3-2-1-GO overlay, locks controls, rocket-start hint, beeps, scale pop. Exports: NONE.
Magic: `_t=3.5`; 3 red `Color(1,0.4,0.4)` / 2 orange `Color(1,0.7,0.2)` / 1 gold `Color(1,0.88,0.3)` / GO green `Color(0.3,1,0.4)`; font 160 outline 12; dim `Color(0,0,0,0.35)`; hint (−260,−90) font 20; pop 1.4→1.0/0.3s.

### 4.27 `scripts/vehicles/driver_builder.gd` — `class_name DriverBuilder extends RefCounted`, static-only

Farm-FBX or procedural helmet driver; rocket→penguin, shrink→pig rebuilds. Exports: NONE.
Magic: FARM scales cow 0.20, pig 0.22, sheep 0.23, horse 0.16, llama 0.18, pug 0.38, zebra 0.155 at (0,−0.15,0.1) rot PI; torso r0.26 h0.7, arms r0.08 h0.45, helmet r0.24, visor (0.3,0.12,0.1); body/accent colors per character.

### 4.28 `scripts/vehicles/vehicle_controller.gd` — `class_name VehicleController extends VehicleBody3D`, root of all 8 vehicle scenes

Arcade kart + items/status/bots: stats-driven engine/steering/suspension/hitbox, rocket-start, curve-shaped 3-tier drift boosts, offroad/coin/star/rubber-band factors, draft, touch+bot inputs, roulette/charges, defenses, 6 effect types, skids/lean/squash/celebration, zone detection, server speed clamp. Exports (verbatim): `@export var stats: KartStats`; `@export var peer_id: int = 1`; `@export var character_id: String = "human"`; `@export var racer_name: String = "Joueur"`.
Magic: center_of_mass (0,−0.4,0); shield sphere r1.7 h3.4 at (0,0.8,0) alpha 0.3; driver (0,0.21,0.35); skid `Color(0.05,0.05,0.06,0.55)`; brakes locked 5.0 / rolling 2.0 / reverse 8.0; rocket-start 1.0s; touch threshold 0.05; reverse throttle −0.6; drift needs |steer|>0.25 + speed>8.0; charge +0.45/s; spark 0.25s; skid 0.06s, child cap 400; `max_steer=0.55×turning×handling` (penguin 0.55, shrink ×0.8), lerp 12.0×delta, applied negated (`-steer`, `-target_force` → −Z visual front); `target_force=accel×60×throttle` (+`boost×60`), shrink ×0.55; clamp max+8.0; coins +1.5%/coin cap 10; offroad 0.8/0.62; star ×1.22; shrink ×0.6; boost tiers ≥0.99→1.9s / ≥0.7→1.2s / ≥0.35→0.6s each ×(0.85+0.30×curve); roulette 0.9s; pad cd 1.0s → 1.1s; banana slip 2.0s; lightning shrink 3.0s (scale 0.6); shrink scale 0.55; knockback default 8.0 / shell 12.0 / meteor 10.0, impulse ×knock×mass×0.01, lift y 0.3; coin loss 3; wobble TAU/0.5s if mult>1.3 else 0.3×mult 0.08→0.2s; bots use chance 0.4/s, [−local.x/8, 0.85 (0.5 if |x|>10), drift if |steer|>0.6], fallback [0,0.8,false]; rubber 1+clamp(diff×0.02,0,0.12)−(0.05 if leader); draft speed≥12, 1.5–7.0 m, dot>0.75, tick 0.25s, ≥1.0→0.8s; lean 0.22/0.06 (×2 moto/vélo) lerp 0.15; squash (1.15,0.8,1.15) 0.09+0.18s; surprise +0.6 m 0.12+0.18s; celebration y 1.4/0.95 per 0.25s; humiliation ±0.4 per 0.3s; star sparkles 4.0/s; wheel spin /0.35; skid quad (0.35,0.9) y 0.16 →0.6 over 0.8s after 2.0s.

### 4.29 `scripts/vehicles/vehicle_mesh_builder.gd` — `class_name VehicleMeshBuilder extends RefCounted`, static-only

Procedural class bodies (chassis/seat/steering/spoiler or truck/moto/bike variants), tire+rim wheels on scene anchors, FBX shells for Sport/Taxi/SUV, Label3D nametag. Exports: NONE.
Magic: chassis L2.4/W1.5/y0.55 (car 2.9/1.7, truck 3.4/2.1/0.75, moto 2.1/0.8, bike 1.9/0.6); exhausts r0.09 h0.5; headlights r0.12 emission 1.5; taillight 1.2; torus 0.2/0.16; tires r0.35 w0.32 (truck 0.45/0.45), narrow 0.12/0.18, rim 0.55×; FBX targets 2.9/2.9/3.4 vs 3.93/4.22/4.21, offset (0,−1.05,0), driver y −0.9/−0.7; nametag font 96, pixel 0.01, outline 16 at (0,2.4,0).

### 4.30 `.cs` files — none (0 in repo).

### 4.31 Marker grep (case-insensitive `TODO|FIXME|XXX|HACK|placeholder|stub|incomplete`, all `*.gd`)

Zero hits for TODO/FIXME/XXX/HACK/incomplete. Genuine hits: `matchmaking_service.gd:21` skill/ping stub comment; `map_builder.gd:65` GridMap compliance stub; `main_menu.gd:108` `placeholder_text="Code 4 chiffres"` (functional LineEdit property). Noise: case-insensitive `TRUC` matches inside "truck" (lobby/game_manager/mesh/lobby_screen/controller/kart_stats).

---

## 5. Vehicles / entities

One script (`VehicleController`) drives all 8; all roots are **`VehicleBody3D`** (no Rigid/CharacterBody, no per-entity scripts). Front wheels (`WheelFL/FR`, +Z) steer + drive; rears drive only. Differences come from `KartStats` + scene collision/mesh sizes.

| Vehicle (display) | top_speed | accel | turn | mass | boost | knock | stiff | damp | fric | Flags / notes |
|---|---|---|---|---|---|---|---|---|---|---|
| Kart Standard | 22.0 | 14.0 | 0.6 | 800 | 12.0 | 1.0 | 50.0 | 4.0/4.0 | 10.5 | baseline; curve mid (0.5,0.45) |
| Car Racer | 26.0 | 14.0 | 0.45 | 1100 | 13.0 | 1.0 | 56.0 | 4.6/4.6 | 11.2 | curve (0.5,0.4) |
| Camion Bruiser | 19.0 | 9.0 | 0.42 | 1900 | 11.0 | 0.4 | 70.0 | 5.8/5.8 | 13.0 | `is_plow_class` (chicken/banana immune); curve (0.6,0.35) |
| Moto Sport | 25.0 | 19.0 | 0.85 | 550 | 14.0 | 1.6 | 38.0 | 2.8/2.8 | 8.5 | lean ×2; only knockback>1.3 → full spin; curve (0.4,0.55) |
| Velo BMX | 17.0 | 10.0 | 0.95 | 350 | 10.0 | 1.2 | 32.0 | 2.4/2.4 | 8.0 | `ignores_size_hazards` (shrink/lightning-scale immune, offroad 0.8 vs 0.62); lean ×2; curve (0.35,0.6) |
| Sport GT | 27.0 | 15.0 | 0.5 | 900 | 13.5 | 1.1 | 52.0 | 4.2/4.2 | 10.8 | real FBX shell; curve (0.45,0.5) |
| Taxi Jaune | 23.0 | 15.0 | 0.6 | 1000 | 12.0 | 0.9 | 54.0 | 4.4/4.4 | 11.0 | real FBX shell; curve (0.5,0.45) |
| SUV Baroudeur | 20.0 | 10.0 | 0.45 | 1700 | 11.5 | 0.6 | 66.0 | 5.4/5.4 | 12.5 | real FBX shell; curve (0.6,0.35) |

- Acceleration = force factor (×60 in code); top_speed = m/s cap; turning_radius → `max_steer=0.55×turning×handling`.
- Braking: reverse-throttle brake 8.0; locked 5.0; rolling 2.0; overspeed clamp max+8.0. No separate handbrake action — `drift` (Space/Joy7/touch) + |steer|>0.25 + speed>8.0 is the drift/handbrake.
- Drift: charge +0.45/s to 1.0 cap; release ≥0.99→1.9s / ≥0.7→1.2s / ≥0.35→0.6s, each ×(0.85+0.30×curve sample at release charge).
- Drivers (11 characters: human/crocodile/penguin/chicken/cow/pig/sheep/horse/llama/pug/zebra) are independent of vehicle class; voices 0.7–1.8 pitch-drive audio (§8 in prior context: engine + chicken/hit/star SFX).

---

## 6. Camera

`autoload/game_manager.gd` `_attach_chase_camera` (local player only): creates `Camera3D "ChaseCam"` (`fov=70.0`, `current=true`) under `Node3D "CamRig"` at `CAM_OFFSET=Vector3(0,3.2,6.5)`, `rotation=(-14°,0,0)` (`CAM_PITCH_DEG=-14.0`). Rig is `top_level=true` (ignores vehicle scale/wobble/shrink). `_update_chase_cams` runs every `_process` (all phases): `tp=1−exp(−6.0×delta)` position lerp toward `vehicle×CAM_OFFSET`; `ty=1−exp(−5.0×delta)` yaw-only `lerp_angle`, pitch fixed −14°, roll 0 (`CAM_POS_SMOOTH=6.0`, `CAM_YAW_SMOOTH=5.0`). No FOV changes with speed/boost. Rigs of freed vehicles are pruned lazily (validity checked before cast).

---

## 7. UI/UX

### 7.1 Menu/HUD scenes (6, all code-built; scripts in §4.22–4.26 + 4.23)

`main_menu` (format/map toggles, Course/GP/TT, private salon, records, music toggle), `lobby_screen` (code, 16 slots, carousels, stat bars, quit/ready/start), `countdown_overlay` (3-2-1-GO + rocket-start hint), `race_hud` (§4.22), `results_screen` (4 branches), `pause_menu` (resume, music/volume/quality settings, quit).

### 7.2 Theme resource

Single theme `res://assets/ui/theme.tres` (71 lines, `load_steps=7`): ext `FontFile TitanOne-Regular.ttf`; `btn_normal` navy `Color(0.12,0.14,0.3,1)`; `btn_hover` magenta `Color(1,0.18,0.53,1)`; `btn_pressed` deep magenta `Color(0.65,0.12,0.34,1)`; `btn_disabled` `Color(0.22,0.24,0.36,1)`; `btn_focus` transparent + 3px magenta border; all radius 12, margins 20/20/12/12. Assignments: `default_font` + `default_font_size=22`; `Button/colors/font_disabled_color=Color(0.6,0.62,0.7,1)`; `Button/font_sizes/font_size=22`; styles normal/hover/pressed/disabled/focus; `Label/font_sizes/font_size=22`. No other component types styled.

### 7.3 Fonts

- File: `assets/fonts/TitanOne-Regular.ttf` (TTF, OFL per `OFL.txt`), imported as `FontFile` (`TitanOne-Regular.ttf.import`: `importer="font_data_dynamic"`, `allow_system_fallback=true`). Applied as theme `default_font` → inherited by every Button/Label on all 6 screens + Label3D nametags. Verified in-engine: French diacritics/`«»`/`•`/digits present (413-glyph cmap); arrows/`✓`/`♪`/emoji absent → system fallback (same path emoji already used).
- No `.otf`/`.woff`, no `FontVariation`, no per-widget font assignments in code.

### 7.4 Full color list (distinct `Color(...)` literals; one location each; zero hex colors repo-wide)

Theme: `(0.12,0.14,0.3,1)`, `(1,0.18,0.53,1)`, `(0.65,0.12,0.34,1)`, `(0.22,0.24,0.36,1)`, `(0.6,0.62,0.7,1)`. Item box: `(0.3,0.7,1,1)`. Stats/characters/maps/chars: `(1,0.9,0.2,1)`, `(0.3,0.9,1,1)`, `(1,0.2,0.2,1)`, `(0.4,0.6,1,1)`, `(1,1,1,1)`, `(1,0.4,0.1,1)`, `(0.3,0.8,0.2,1)`, `(0.6,0.3,1,1)`, `(0.2,0.7,1,1)`, `(1,0.25,0.3,1)`, `(1,0.55,0.1,1)`, `(0.5,1,0.3,1)`, `(0.6,0.2,0.9,1)`, `(1,0.8,0.1,1)`, `(0.15,0.35,0.2,1)`, `(1,0.3,0.2,1)`, `(0.5,0.32,0.18,1)`, `(0.15,0.1,0.08,1)`, `(0.2,0.7,0.25,1)`, `(0.9,0.9,0.3,1)`, `(0.55,0.35,0.25,1)`, `(0.9,0.85,0.7,1)`, `(0.5,0.3,0.2,1)`, `(0.1,0.1,0.15,1)`, `(1,0.7,0.7,1)`, `(1,0.5,0.5,1)`, `(0.85,0.7,0.55,1)`, `(0.2,0.12,0.08,1)`, `(0.9,0.9,0.9,1)`, `(0.3,0.3,0.3,1)`, `(1,0.8,0.6,1)`, `(0.2,0.5,1,1)`, `(0.1,0.1,0.1,1)`, `(0.05,0.05,0.12,1)`, `(0.12,0.12,0.25,1)`, `(0.05,0.15,0.08,1)`, `(0.3,0.22,0.12,1)`, `(0.2,0.6,0.2,1)`, `(0.75,0.87,0.95,1)`, `(0.85,0.92,1,1)`, `(0.4,0.7,1,1)`, `(0.35,0.55,0.2,1)`, `(0.55,0.4,0.22,1)`, `(0.6,0.35,0.15,1)`. Defaults: `(0.6,0.3,1.0)`, `(1.0,0.9,0.2)`, `(0.08,0.08,0.16)`, `(0.15,0.15,0.28)`, `(1.0,0.18,0.53)`, `(0.2,0.7,1.0)`, `(1.0,0.8,0.6)`, `(0.2,0.5,1.0)`. Controller: `(0.05,0.05,0.06,0.55)`, `(0.3,0.7,1.0,0.3)`, `(1.0,0.45,0.1)`, `(0.3,0.6,1.0)`, `(1.0,0.9,0.2)`, `(0.6,0.5,0.35)`, `(1.0,0.85,0.2)`, `(0.7,0.5,1.0)`. Driver builder: `(0.8,0.7,0.6)`, `(1,0.8,0.6)`, `(0.25,0.68,0.28)`, `(0.95,0.85,0.2)`, `(0.12,0.12,0.16)`, `(1,1,1)`, `(1,0.35,0.2)`, `(0.05,0.08,0.12)`, `(1,0.9,0.1)`, `(1,0.6,0.1)`, `(0.9,0.15,0.15)`, `(0.9,0.9,0.9)`. Mesh builder: `(1,1,1,1)`, `(0.08,0.08,0.1)`, `(0.15,0.15,0.18)`, `(0.1,0.1,0.12)`, `(0.1,0.16,0.22)`, `(0.7,0.7,0.75)`, `(0.5,0.8,1.0,0.45)`, `(0.9,0.9,0.9)`, `(0.85,0.85,0.9)`, `(0.4,0.2,0.1)`, `(0.75,0.75,0.8)`, `(1,0.95,0.8)`, `(1,0.1,0.1)`, `(0.06,0.06,0.07)`, `(0,0,0,1)`, `(1,1,1)`. Map builder sky/dressing: `(0.01,0.02,0.08)`, `(0.35,0.08,0.35)`, `(0.01,0.01,0.03)`, `(0.15,0.05,0.2)`, `(0.1,0.3,0.25)`, `(0.55,0.7,0.4)`, `(0.03,0.08,0.05)`, `(0.2,0.3,0.15)`, `(0.25,0.5,0.85)`, `(0.75,0.88,1.0)`, `(0.5,0.6,0.7)`, `(0.8,0.9,1.0)`, `(0.25,0.5,0.9)`, `(0.7,0.85,0.95)`, `(0.2,0.25,0.12)`, `(0.5,0.6,0.35)`, `(0.6,0.6,0.7)`, `(0.4,0.55,0.35,1)`, `(1,0.75,0.6)`, `(0.4,0.7,1.0)`, `(0.8,0.5,1.0)`, `(1,1,1,0.85)`, `(0.2,0.9,1.0)`, `(1,0.88,0.2)`, `(0.3,1,0.5)`, `(0.5,0.5,0.6)`, `(0.45,0.3,0.15)`, `(0.8,0.92,1.0)`, `(0.85,0.7,0.3)`, `(1,0.3,0.1)`, `(1,1,1,0.5)`, `(0.9,0.95,1,0.5)`, `(0.9,0.8,0.4,0.5)`, `(0.3,0.4,0.2,0.5)`, `(0.4,0.4,0.5,0.5)`, `(0.15,0.9,1)`, `(0.6,0.3,1)`, `(0.05,0.06,0.12)`, `(0.1,0.1,0.15)`, `(0.4,0.9,1.0)`, `(0.3,0.2,0.12)`, `(0.1,0.35,0.25,0.85)`, `(0.25,0.6,0.25)`, `(0.08,0.35,0.12)`, `(0.12,0.45,0.16)`, `(0.2,0.5,0.18)`, `(0.35,0.25,0.15)`, `(0.45,0.32,0.18)`, `(0.25,0.4,0.15)`, `(0.7,0.88,1.0,0.85)`, `(0.92,0.96,1.0)`, `(0.1,0.12,0.18)`, `(0.2,1.0,0.5,0.16)`, `(0.65,0.15,0.12)`, `(0.5,0.1,0.1)`, `(0.7,0.72,0.75)`, `(0.8,0.8,0.82)`, `(0.9,0.9,0.92)`, `(0.5,0.35,0.2)`, `(0.55,0.4,0.22)`, `(0.9,0.75,0.3)`, `(0.85,0.7,0.3)`, `(1,0.2,0.2,0.6)`, `(0.25,0.2,0.18)`. VFX: `(1.0,0.7,0.1)`, `(1.0,0.2,0.2)`, `(1.0,1.0,1.0)`, `(1.0,0.5,0.0)`, `(1.0,0.3,0.1)`, `(0.6,0.5,0.4)`, `(1,0.9,0.4)`. Coin: `(1.0,0.84,0.1)`, `(1.0,0.8,0.2)`. Shells/trail: `(0.2,0.9,0.2)`, `(0.9,0.15,0.15)`, `(1,0.9,0.2,0.6)`. Countdown: `(0,0,0,0.35)`, `(1,0.88,0.3)`, `(0,0,0)`, `(1,1,1,0.9)`, `(0.3,1,0.4)`, `(1,0.4,0.4)`, `(1,0.7,0.2)`. Lobby: `(0.07,0.08,0.18)`, `(0.5,0.5,0.55)`, `(0.5,0.5,0.6)`. Pause: `(0.06,0.06,0.14,0.92)`, `(0.7,0.7,0.8)`. Main menu: `(0.1,0.06,0.24)`, `(0.02,0.02,0.08)`, `(0.7,0.9,1)`. Results: `(0.06,0.06,0.14)`, `(1,0.85,0.25)`, `(0.4,1,0.5)`. HUD: `(0.8,0.9,1)`, `(1,0.95,0.6)`, `(1,0.85,0.2)`, `(1,0,0,0)`, `(0.55,0.3,1.0,0.18)`, `(1,0.88,0.2)`, `(0.85,0.9,1.0)`, `(1,0.2,0.2)`, `(0.3,0.9,1)`, `(0,0,0,0.45)`, `(1,1,1,0.4)`, `(0.3,0.3,0.4)`, `(0.6,0.6,0.7,0.6)`, `(0.3,0.7,1)`, `(1,0.3,0.3)`, `(0.3,1,0.4)`, `(1,0.6,0.2)`. Joystick: `(1,1,1,0.15)`, `(1,1,1,0.5)`, `(1,0.18,0.53,0.8)`. Shader uniforms: `vec4(0.55,0.3,1.0,0.25)`, wobble `2.0`.

### 7.5 Button/component states

Theme defines all 5 Button styles (normal/hover/pressed/disabled/focus) + disabled font color; only Button/Label font sizes otherwise. Code sets `.disabled` on lobby start (`lobby_screen.gd:199`) and HUD item button (4 branches `race_hud.gd:260–272`, cleared :276). Toggle buttons (`toggle_mode`) reuse the same styles (selected looks like hover). No other component states (no CheckBox/Slider/ProgressBar styling; sliders/bars use engine defaults).

---

## 8. Settings & persistence

`ConfigFile` (INI-like) at `user://crazy_racer.cfg`, owned by `GameManager` (`SAVE_PATH`, `game_manager.gd:31`; `_load_cfg` :355–358). Sections/keys/defaults: `tt/<map_id>={total,best}` (write on record only, `_save_tt_result`; reads `get_tt_best(s)/get_tt_bests`); `carriere/gp_wins` int default 0 (`get_gp_wins`/`add_gp_win`, win counted only if local player is champion); `settings/music` bool default true, `settings/volume` float 0..1 default 1.0 (clamped), `settings/quality` high/low default high (invalid→high) — `load_settings` at autoload ready, `save_settings` wholesale, per-field setters auto-apply+save, `apply_settings` pushes to `VfxFactory.particle_quality` + `Audio.set_master_volume` (Master bus, mute ≤0.001 else `linear_to_db(clamp(v,0.001,1.0))`, base volumes −8.0 SFX/−17.0 engine/−20.0 music preserved) + `Audio.set_music_enabled` (play/stop; called by `Audio._ready` after voices built). Callers: pause menu (music toggle, volume slider live-apply/save-on-drag-end, quality buttons), main-menu music button, `KEY_M` (all via `GameManager` setters). Controls are NOT persisted (fixed Input Map). No second save file.

---

## 9. Assets

- **3D models (20× `.fbx`)**: cars 7 (Cop, NormalCar1/2, SportsCar, SportsCar2, SUV, Taxi), dino 6 (Apatosaurus, Parasaurolophus, Stegosaurus, Trex, Triceratops, Velociraptor), farm 7 (Cow, Horse, Llama, Pig, Pug, Sheep, Zebra). Used: neon parking (Cop/Normal1/2/SportsCar), drivable shells (SportsCar2/Taxi/SUV), swamp dressing + stampede runners (Trex/Apatosaurus/Parasaurolophus + Triceratops/Velociraptor/Stegosaurus), farm dressing + 7 farm drivers, procedural human/croco/penguin/chicken drivers otherwise.
- **Textures**: none (0 png/jpg/webp; only `icon.svg` project icon). All visuals procedural meshes + vertex-color materials + one gradient texture built in code.
- **Fonts**: `TitanOne-Regular.ttf` + `OFL.txt` (+ `.import` as `FontFile`, `allow_system_fallback=true`).
- **Audio**: 0 files; 100% synthesized `AudioStreamWAV` 8-bit/22050 Hz in code (13 SFX + engine/skid/music loops).
- **Particles/shaders**: `gravity_flip.gdshader` (13 lines: `canvas_item`, violet tint `(0.55,0.3,1.0,0.25)`, wobble 2.0) + runtime `GPUParticles3D` (HIGH: 48/0.8s) / `CPUParticles3D` (LOW: 24/0.8s) via `VfxFactory` + results `CPUParticles2D` confetti.
- **Resources (33× `.tres`)**: 8 `KartStats` (§5), 11 `CharacterData` (voices human 1.0, chicken 1.8, cow 0.8, croco 0.7, horse 0.9, llama 1.1, penguin 1.5, pig 1.3, pug 1.6, sheep 1.4, zebra 1.0), 5 `ItemData` (banana_boost 1.2/6.0s/self; rocket 0.7/7.0s; reverse_gun 1.0/4.0s; shrink_ray 0.9/5.0s; chicken_storm 0.9/3.0s; all cooldown 1.0), 4 `ChaosEventData` (collapse 20s w1.0, dino 12s w0.6, gravity 10s w1.0, meteor 10s w1.0; banners orange/green/violet/red), 4 `MapData` (map1 4cp weights grav 0.5/meteor 0.8/collapse 2.0/dino 0.3; map2 5cp 0.5/2.0/0.8/2.2; map3 4cp 2.0/0.7/0.6/0.4; map4 4cp 0.7/1.0/0.7/1.2; all 3 laps), 1 `Theme` (§7.2).

---

## 10. Game flow

`MatchPhase {MENU,LOBBY,COUNTDOWN,RACING,RESULTS,PAUSED}` (0–5); `UI_SCENES` maps each int to its screen (pause=5, appended so RESULTS kept 4). Boot `main.tscn` → `main.gd` registers layers → MENU. `request_quick_play` (single) / `start_gp_lobby` / `start_tt` → LOBBY (bots filled) → `start_countdown` loads map + spawns grid (sorted spawn points, teams assigned, local player + chase cam) → COUNTDOWN 3.5s (controls locked; `ui_up`/touch pre-hold = rocket-start 1.0s boost) → RACING (`race_timer`, chaos unless TT, boundary/clock) → `finish_race` (teams/GP-points/TT-record) → RESULTS (single/GP-manche/champion/TT branches; rematch/`gp_next`/`back_to_menu`). PAUSED only from RACING (Esc/Start/HUD ❚❚ → `toggle_pause`): `get_tree().paused=true` freezes physics/timers/chaos/controls; resume rebuilds HUD; quit unpauses via `_cleanup_race` (also forced in `start_countdown`); rigs of freed vehicles pruned lazily. Managers: `GameManager` (phases/UI/maps/spawns/timer/persist/pause/camera), `main.gd` (boot wiring), UI screens call `GameManager` (menu: quick/gp/tt/join/create/records/music; lobby: format/leave/ready/start; HUD: pause/item/drift/auto; results: rematch/menu/gp-next; pause: resume/music/volume/quality/quit), `BoundaryManager` (finish detection → results), `ChaosEventSystem` (race start/end), `LobbyManager` (roster/ready), `Audio` (KEY_M). No pause during COUNTDOWN/RESULTS; 600s race timeout forfeits.

---

## 11. Known issues / TODOs

- Zero `# TODO`/`# FIXME`/`# XXX`/`# HACK`/`# incomplete` hits in `*.gd` (word-bounded grep).
- `autoload/matchmaking_service.gd:21` — skill/ping balancer stub (`return 0.0`, "stretch goal").
- `scripts/maps/map_builder.gd:65` — empty `GridMap` (cell (10,1,10)) added as contract-compliance stub.
- `scripts/ui/main_menu.gd:108` — `placeholder_text="Code 4 chiffres"` (functional LineEdit property, not unfinished code).
- Former audit issues now resolved in code (kept here for traceability): missing `scripts/items/effects/` scripts (the `effect_script_path` field was deleted from `ItemData` + all 5 item `.tres` + fallback branch); sport/taxi/SUV scene-vs-tres mass mismatches (scenes synced: 900/1000/1700); dead drift-release block (now reads previous-frame `_was_drift`, boosts fire with curve scaling); `friction_slip=2.5` in vehicle scenes is ignored by Godot 4.7 (runtime uses `wheel_friction_slip` from stats, verified 8–13).
- Doc debt (not code): `README.md` build-order still indexes the deleted `00–07_*.md` spec docs; `AI_AGENT_INSTRUCTIONS.md` §0/§3–§5 bullets predate the suspension/drift-curve/font/button/input/pause/settings work (only §-1, mass, effects, counts refreshed); `GAMEPLAY_RULES.md` §3 still says WASD comes from Godot defaults (WASD now works via custom physical-key actions).
