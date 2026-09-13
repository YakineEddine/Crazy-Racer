# 02 — Vehicles & Items

## 1. Vehicle Classes

Five classes, each backed by one `KartStats` Resource (`.tres`) in `assets/resources/`. Skins are new meshes/materials on the *same* rig — never a new stats file per skin.

| Class | Resource file | Top Speed | Acceleration | Turning Radius | Mass | Collision Width | Special |
|---|---|---|---|---|---|---|---|
| Kart | `kart_stats.tres` | Medium | Medium | Medium | Medium | Medium (baseline) | Reference class — tune all others relative to this |
| Car | `car_stats.tres` | High | Medium | Wide | Medium-high | Medium-wide | — |
| Truck/Camion | `truck_stats.tres` | Low | Low | Wide | High | Wide | Plows through small hazards & other karts on contact (no knockback taken from bananas/chicken swarms) |
| Motorcycle | `motorcycle_stats.tres` | High (fastest accel) | Highest | Tightest | Low | Narrow | Low stability — takes increased knockback/spin-out duration from hits |
| Bicycle | `bicycle_stats.tres` | Lowest | Low | Tightest | Lowest | Narrowest | Immune to "size-gated" hazards; can use gap-shortcuts trucks can't fit through |

**Balance intent:** Truck and Bicycle are the two extremes (mass/collision vs. agility/novelty). Kart/Car/Motorcycle are the competitive middle. Confirm exact numeric values in a spreadsheet pass before locking `.tres` values — this table is relative, not final numbers.

## 2. KartStats Resource Schema

```gdscript
class_name KartStats extends Resource

@export var display_name: String
@export var top_speed: float
@export var acceleration: float
@export var turning_radius: float
@export var mass: float
@export var drift_boost_curve: Curve
@export var collision_shape_scale: Vector3
@export var is_plow_class: bool = false      # true for Truck
@export var knockback_multiplier: float = 1.0 # >1 for Motorcycle
@export var ignores_size_hazards: bool = false # true for Bicycle
```

## 3. Vehicle Scene Contract

Every vehicle scene (`scenes/vehicles/*.tscn`) must contain, at minimum:
- Root: `VehicleBody3D` with `vehicle_controller.gd` attached
- `CollisionShape3D` sized per class (see table above)
- 4× `VehicleWheel3D` (motorcycles/bicycles use a lean-rig variant — see `05_ANIMATIONS_SPEC.md`)
- `Marker3D` nodes: `DriftTrailAnchorL`, `DriftTrailAnchorR`, `BoostTrailAnchor`, `ItemHoldAnchor` (for visible held-item models)
- `MultiplayerSynchronizer` node syncing `global_transform` and `linear_velocity`

## 4. Items

| Item | Resource | Effect | Duration | Cooldown (post-use) |
|---|---|---|---|---|
| Reverse Gun (Pistolet Inverseur) | `reverse_gun.tres` | Reverses target's steering input mapping | 4s (tune) | Standard pickup cooldown |
| Shrink Ray (Rayon Réducteur) | `shrink_ray.tres` | Swaps target's visible model to bathtub/snail + applies top_speed multiplier < 1 | 5s (tune) | Standard |
| Chicken Storm (Pluie de Poulets) | `chicken_storm.tres` | Spawns obscuring chicken swarm VFX in target's view + minor trajectory disruption impulse | 3s (tune) | Standard |
| Banana Super Boost | `banana_boost.tres` | Forward speed boost to self + spawns a slippery trail hazard behind | Boost: instant; trail: 6s lifetime | Standard |
| Rocket → Penguin Transform | `rocket.tres` | Direct hit: target's driver model → penguin, impaired handling | **7s exactly** (signature effect — do not deviate) | Standard |

**ItemData Resource schema:**
```gdscript
class_name ItemData extends Resource

@export var id: String
@export var display_name: String
@export var pickup_rarity: float       # relative weight in item box roll
@export var effect_duration: float
@export var cooldown: float
@export var vfx_scene: PackedScene
@export var sfx_stream: AudioStream
@export var icon: Texture2D
```

## 5. Item System Logic (`scripts/items/item_system.gd`)

- Pickup: item box (`Area3D`, group `"item_box"`) on `body_entered` → server rolls weighted-random `ItemData` from pool, RPCs result to that player only, box respawns after N seconds (hide + `Timer` + show).
- Held item: stored in a single-slot inventory on the vehicle controller; visually represented at `ItemHoldAnchor`.
- Use: item button → `@rpc("any_peer")` use-request to server → server validates player has item + resolves target (nearest-ahead-of-target for offensive items, self for boost) → server applies effect + broadcasts via authority RPC to all clients (for VFX/SFX playback) → clears held-item slot.
- Hit resolution is always server-side, using server-tracked positions, never client-reported collisions.
- Extensibility: the item list is explicitly designed to grow (roadmap target 15–20 at launch per the GDD open questions) — implement the pickup/use pipeline generically off `ItemData`, never hardcode a switch statement keyed to exactly these 5 ids if it can be avoided; prefer each item having its own small effect script referenced by the resource.

## 6. Related Docs

- `01_CORE_SYSTEMS_LOGIC.md` — networking/RPC conventions these items use
- `03_MAPS_AND_CHAOS_EVENTS.md` — how truck plow/bicycle gap-slip interacts with map geometry
- `05_ANIMATIONS_SPEC.md` — penguin transform, humiliation, celebration clips
- `06_VFX_SPEC.md` — per-item VFX specs
