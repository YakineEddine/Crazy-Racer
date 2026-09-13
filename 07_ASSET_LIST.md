# 07 — Asset List & Formats

## 1. File Format Standards

| Asset Type | Format | Notes |
|---|---|---|
| 3D Models | `.glb` (glTF 2.0) preferred, `.fbx` supported | glTF is Godot's most reliable import path |
| Textures | `.png` (with alpha) | 512–1024px max for mobile; Godot auto-atlases |
| Track geometry | `.glb` modular pieces via `GridMap` `MeshLibrary` | Snap to 10m or 20m grid unit |
| UI Icons | `.svg` (source) or `.png` | SVG importable directly in Godot |
| SFX | `.wav` | Uncompressed, low-latency |
| Music/Ambience | `.ogg` | Godot's native streaming format |
| VFX | `GPUParticles3D` scenes, `CPUParticles3D` fallback | See `06_VFX_SPEC.md` |
| Animations | `AnimationPlayer` clips / `AnimationLibrary` (.tres) | 3–5s loops |
| Data | `Resource` (.tres) | KartStats, ItemData, ChaosEventData, MapData |

**Mobile polycount targets:** Vehicles 1,500–4,000 tris (LOD0) + visibility-range LODs; Characters 2,000–5,000 tris; Track tiles under ~1,000 tris.

## 2. Full Asset Checklist

### Vehicles (× 5 classes: Kart, Car, Truck, Motorcycle, Bicycle)
- [ ] Base model, rigged (wheel-rig or lean-rig) — `.glb`
- [ ] ≥1 cosmetic skin per class (same rig)
- [ ] Drift trail VFX scene (×2 anchors)
- [ ] Boost trail VFX scene
- [ ] `KartStats.tres` per class

### Characters (× 4: human, crocodile, penguin, chicken)
- [ ] Rigged model, shared skeleton where possible
- [ ] `idle_driving`, `celebration`, `humiliation`, `hit_reaction` clips
- [ ] Voice bark SFX set (win/lose/hit/getting-hit) per character
- [ ] `CharacterData.tres` per character

### Items/Props (× 5 items)
- [ ] Reverse Gun: projectile model + UI icon
- [ ] Shrink Ray: beam VFX + bathtub model + snail model
- [ ] Chicken Storm: swarm particle (reuses chicken LOD)
- [ ] Banana Super Boost: banana model + boost/slip trail VFX
- [ ] Rocket: projectile + impact VFX + reuses Penguin character model
- [ ] Item pickup box: model + rotate script
- [ ] `ItemData.tres` per item

### Environment / Chaos Events
- [ ] Meteor model + impact VFX
- [ ] Collapsing bridge/highway segment model + break animation
- [ ] Gravity-flip shader + VFX
- [ ] Ice patch decal + `PhysicsMaterial`
- [ ] Per-map boundary dressing (guardrails / rope-bridge rails+tree-line / snowbank+ice-crack / fence+hay bales)
- [ ] `ChaosEventData.tres` per event

### Maps (× 4)
- [ ] Modular track tile set per theme, registered in a `MeshLibrary`
- [ ] Checkpoint `Area3D` set (4–5 per map)
- [ ] Boundary collider set (hard + soft)
- [ ] Item box spawn markers
- [ ] Chaos-event zone markers
- [ ] `MapData.tres` per map

### UI/HUD
- [ ] Lobby UI (room code panel, player slot list, format selector)
- [ ] Race HUD (position, lap counter, item slot, minimap, chaos banner, hit-flash)
- [ ] Results/podium screen (team score breakdown)
- [ ] Icon set (`.svg`)
- [ ] Shared `Theme.tres`

### Audio
- [ ] Voice barks per character (`.wav`)
- [ ] SFX: items, hits, chaos events (`.wav`)
- [ ] Music: lobby, per-map race theme, results (`.ogg`)
- [ ] Ambient loop per map theme (`.ogg`)

## 3. Free Public Assets for Testing/Prototyping

*Verify license per-asset before shipping commercially — most are CC0 or MIT.*

**Godot-native vehicle/driving starters**
- SRCoder — Simple Car (CC0): https://godotengine.org/asset-library/asset/3610
- DAShoe — Godot Easy Vehicle Physics (MIT, includes arcade/simcade/monster-truck/drift demo rigs): https://godotengine.org/asset-library/asset/2558
- 3D Car with Settingspanel: https://godotengine.org/asset-library/asset/661
- fluxrider — godot_3d_racing (kart-physics template): https://github.com/fluxrider/godot_3d_racing

**Vehicles (art)**
- Kenney — Racing Pack (CC0): https://kenney.nl/assets/racing-pack
- Kenney — Racing Kit (CC0): https://kenney.nl/assets/racing-kit
- Kenney — Car Kit (CC0): https://kenney.nl/assets/car-kit

**Characters/Animals**
- OpenGameArt — CC0 3D Animals/Creatures: https://opengameart.org/content/cc0-3d-animals-creatures
- Kenney — Animal Pack (CC0): https://kenney.nl/assets/animal-pack
- ITHappy Studios — Animals Free Pack (rigged, includes penguin & chicken): https://ithappystudios.com/free/animals-free/

**Track/Environment**
- Kenney — Nature Kit (CC0): https://kenney.nl/assets/nature-kit
- Kenney — City Kit Roads (CC0): https://kenney.nl/assets/city-kit-roads
- Fertile Soil Productions — Modular Racekart Track, Hilly Terrain (CC0): https://fertile-soil-productions.itch.io/modular-racekart-track-hilly-terrain-theme
- Fertile Soil Productions — Hexagonal Racetrack Collection (CC0): https://fertile-soil-productions.itch.io/hexagonal-racetrack-collection

**Bonus (UI/audio/everything)**
- Kenney — Game Assets All-in-1: https://kenney.itch.io/kenney-game-assets

**Suggested prototyping order:** import DAShoe's Godot Easy Vehicle Physics first to validate the 5 vehicle classes' feel, then Kenney Racing Kit + Nature Kit for a Map 1–4 GridMap blockout, then progressively replace with final art per `00_PROJECT_STRUCTURE.md`.
