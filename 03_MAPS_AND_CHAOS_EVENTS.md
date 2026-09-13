# 03 — Maps & Chaos Events

## 1. MapData Resource Schema

One `.tres` per map in `assets/resources/`:

```gdscript
class_name MapData extends Resource

@export var map_id: String
@export var display_name: String
@export var checkpoint_count: int
@export var shortcut_description: String
@export var weighted_events: Dictionary   # { ChaosEventData: float weight }
@export var scene_path: String            # res://scenes/maps/<map>.tscn
```

## 2. Common Map Scene Contract

Every map scene must contain:
- `StartFinishLine` — `Area3D`, group `"checkpoint"`, index 0
- N× `Checkpoint` nodes — `Area3D`, group `"checkpoint"`, sequential index, crossed-in-order validated by `BoundaryManager`
- `DrivableArea` — `Area3D` volume covering the full track; `body_exited` starts the off-track timer
- `BoundaryWalls` — `StaticBody3D` + `CollisionShape3D` group `"boundary_wall"` (hard stop) along true out-of-bounds edges
- `SoftBoundaryZones` — `Area3D` group `"boundary_soft"` (snowbank/hay bale/crop-drag style slow zones)
- At least one `ShortcutZone` — marked area with a defined risk (narrower `DrivableArea`, hazard `Area3D`, or a speed-dampening `SoftBoundaryZones` overlay)
- `ItemBoxSpawn` markers (`Marker3D`, group `"item_box_spawn"`) — item box scenes instanced here at map load
- `ChaosEventZones` — map-specific `Marker3D`/`Area3D` regions the map's signature event operates on (e.g. collapsible highway segment, thin-ice crack zone)
- GridMap node (`res://assets/maps/<map>/`) holding the modular track tiles, `MeshLibrary` per map theme

## 3. Per-Map Specification

### 3.1 Map 1 — Neon Circuit City
- Theme: synthwave night city
- Checkpoints: 4 — start/finish, plaza exit, highway loop merge, tunnel exit
- Shortcut: elevated highway loop — narrower `DrivableArea`, lower `boundary_wall` height (fall = bigger mistake, hard wall)
- Signature Chaos Event: **Live Track Modification** — highway segment(s) tagged in `ChaosEventZones` can toggle to a "collapsed" state (swap mesh/collision to broken variant + play break animation), forcing reroute through plaza. Weighted higher than other events in this map's `MapData.weighted_events`.
- Boundary notes: street curbs = hard `boundary_wall`; city-block edges beyond street = invisible hard walls behind building facades.

### 3.2 Map 2 — Swamp Gator Grand Prix
- Theme: jungle/swamp
- Checkpoints: 5 — start/finish, bridge 1 entry, bridge 2 entry, switchback summit, final descent
- Shortcut: log-crossing through swamp water — narrow `DrivableArea`, no side protection (falling in = respawn penalty via `Area3D` "swamp water" zone, not instant hard wall)
- Signature Chaos Event: **Meteor/Obstacle Shower** — weighted higher here; spawns falling tree obstacles (temporary `StaticBody3D` instances with a fall-in animation) onto `ChaosEventZones` markers along the track
- Boundary notes: rope bridges = low physical rail colliders (falling off is possible/intentional, triggers swamp-water respawn `Area3D`, not a hard wall); jungle tree-line = dense prop wall + invisible collision plane behind it.

### 3.3 Map 3 — Frozen Waddle Way
- Theme: arctic/ice
- Checkpoints: 4 — start/finish, ice-cave exit, lake exit, igloo cluster exit
- Shortcut: frozen lake crossing — low-friction `PhysicsMaterial` on lake surface tiles (slippery even without Penguin item effect); "thin ice" hazard zone can crack under multiple simultaneous vehicles (track overlapping-body count on a designated `Area3D`; beyond a threshold, trigger crack VFX + a delayed fall-through event)
- Signature Chaos Event: **Gravity Inversion (10s)** — weighted highest here; server sets inverted `gravity_scale` on all `VehicleBody3D` instances for the duration, broadcast as state not recomputed per client
- Boundary notes: snowbank walls = soft zones (velocity dampening, not hard stop); lake shortcut bounded by visible crack-line dressing + invisible hard walls just beyond the visual ice edge — falling into open water should be rare and telegraphed, never a surprise invisible wall.

### 3.4 Map 4 — Barnyard Bedlam
- Theme: farm/rural
- Checkpoints: 4 — start/finish, silo turn, field midpoint, equipment yard exit
- Shortcut: cutting through the wheat field instead of the fence-line road — soft speed penalty (drag multiplier in a `SoftBoundaryZones`-style overlay, not a hard slowdown wall) — deliberately favors low-top-speed classes like Bicycle
- Signature Chaos Event: **Chicken Storm** (the player item) is thematically home here; also flagged as the future testbed for a "loose farm animals wander onto track" hazard type — **not a launch requirement**, stub a `ChaosEventZones` region for it but don't implement the wandering-animal logic yet
- Boundary notes: wooden fence-line = primary hard boundary around the whole perimeter; hay bale stacks + barn walls = secondary blockers at specific cut-through points.

## 4. Route Design Invariants (apply to every map, including future ones)

- Every map needs ≥1 shortcut with a genuine risk/reward trade-off — never a free shortcut.
- Every map's signature Chaos Event must have a visually/thematically obvious reason to occur there.
- Checkpoints (4–5 per map) must be crossed in order for a lap to count; out-of-order crossings are ignored, not scored.

## 5. Chaos Event Catalogue

| Event | Duration | Server-side effect | Client-side representation |
|---|---|---|---|
| Gravity Inversion | 10s | Set `gravity_scale = -1` on all vehicles map-wide | Inverted-world VFX/shader, synced "surprised" voice bark on trigger |
| Live Track Modification | Until reroute resolves (or fixed window, tune) | Swap tagged track segment to collapsed collision/mesh state | Break animation/VFX plays for all clients on trigger |
| Meteor/Obstacle Shower | ~8–12s spawn window (tune) | Spawn timed obstacle instances at `ChaosEventZones` markers, server-authoritative positions | Falling meteor VFX + impact VFX per spawn |

See `01_CORE_SYSTEMS_LOGIC.md` §6 for the ChaosEventSystem contract these all plug into. All events must respect `BoundaryManager` containment — a chaos event must never be able to fling a player past the outer boundary; boundary colliders are tall/deep enough (or capped) to contain event-driven physics extremes.

## 6. Related Docs

- `01_CORE_SYSTEMS_LOGIC.md` §5–6 — BoundaryManager & ChaosEventSystem implementation contracts
- `06_VFX_SPEC.md` — per-event VFX detail
- `07_ASSET_LIST.md` — per-map asset/prop lists
