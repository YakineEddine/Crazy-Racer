# Map / Environment Instructions — Crazy Racer v1.1

Answers "how do I build a complete racing map like other games — can I get ready-to-use maps?" Current state: all 4 maps (`map_builder.gd` + 4 `MapData` `.tres`) are procedurally dressed scenes with checkpoints/weighted chaos events but no imported track-mesh assets — no textures at all in the project (`PROJECT_AUDIT.md` §9: "0 png/jpg/webp").

## 1. You don't need to buy anything to get real track pieces

**Kenney's Racing Kit (CC0, free, no attribution required)** — `kenney.nl/assets/racing-kit`. This is the **3D** pack: its `Models/` folder ships DAE/FBX/glTF/OBJ/STL versions of modular road-tile, barrier, ramp, and prop meshes. This is the one to use for this project's `GridMap` track tiles.

Note on a related pack: `kenney.nl/assets/racing-pack` is a **2D top-down sprite pack** (SVG/spritesheets/PNG — cars, objects, characters, motorcycles, tiles, all flat images). It's not usable for this project's 3D pipeline and shouldn't be imported as track geometry — don't be misled by the similar name.

Kenney also ships a ready-made **Godot 4.6 racing starter kit** built around 3D road tiles like these: `github.com/KenneyNL/Starter-Kit-Racing`. It uses a `GridMap` of pre-made road tiles you place in the editor, plus a handful of drivable vehicle scenes — worth opening as a reference even if you don't import its code, specifically to see how it structures a `GridMap`-based track (this repo's own `map_builder.gd` already has an *empty* `GridMap` stub at cell `(10,1,10)`, per `PROJECT_AUDIT.md` §11 — the Kenney kit shows exactly what that stub was scaffolded for).

## 2. If you want something closer to "AAA-looking" than Kenney's flat-shaded low-poly style

- **Synty Studios** (`syntystudios.com`) — paid, low-poly-but-stylized packs including dedicated racing/vehicle sets; commercial license included, works fine imported as glTF/FBX into Godot. This is the most common paid choice for indie racers that want more visual polish than CC0 packs while staying low-poly (matches this project's already-low-poly aesthetic, e.g. its FBX Quaternius vehicles).
- **Quixel Megascans / Fab (Epic's asset marketplace, `fab.com`)** — photogrammetry-quality environment props (rocks, foliage, road surfaces) if you want to build a more "real" outdoor track rather than a stylized one; free with a Fab/Epic account for many assets, some paid. Heavier polycount than this project currently uses anywhere — budget accordingly if mixing with the existing procedural maps.
- **itch.io asset packs** (`itch.io/game-assets/tag-race`) — wide quality range, but many are free or pay-what-you-want; vet each one's license individually before use (unlike Kenney/CC0, these vary pack to pack).

## 3. If you specifically want "real-world" tracks

**OpenStreetMap-based approaches** exist (see reference repo `Open Street Kart` below) — they reconstruct drivable roads from real map data rather than hand-authored tracks. This is a much bigger technical undertaking (OSM data parsing, procedural road mesh generation) than swapping in an asset pack, and isn't a good fit for this project's current scope/timeline unless that's specifically what's wanted — flag it back to the user rather than starting it speculatively (per `AGENT_MEMORY_THINKING.md` §3's "don't silently resolve open questions" rule).

## 4. How to integrate any of the above with this project's existing map system

- Each map is a `Node3D` root scene (`map1_neon_circuit_city.tscn` etc.) with `map_builder.gd` + a `map_id` string — **don't replace this pattern**; import track meshes as children under the existing structure, driven by the same `MapData` `.tres` (checkpoints, weighted chaos events, spawn grid) that already exists for all 4 maps.
- If you adopt a `GridMap`-based tile workflow (Kenney-kit style): populate the currently-empty `GridMap` stub in `map_builder.gd` instead of adding a second track-building system — that stub exists for exactly this purpose per the audit.
- Checkpoints/boundaries (`BoundaryManager`) and chaos-event trigger zones are logic, not geometry — they attach to whatever track mesh you bring in the same way they attach to the current procedural dressing; don't touch `boundary_manager.gd`'s multiplayer/RPC logic while doing an asset swap (`AI_AGENT_INSTRUCTIONS.md` §2 scope-discipline rule already flags this file as fragile).
- Textures: this project currently has **zero** texture files and relies entirely on vertex-color procedural materials. Bringing in a textured asset pack (Kenney/Synty/Fab all ship with real textures) is the first time this project would need texture import settings configured — check `project.godot`'s `[rendering]` import settings (currently `vram_compression/import_etc2_astc=true` per `PROJECT_AUDIT.md` §2.1) still make sense once real textures exist; this is a one-time project-settings check, not a per-asset concern.

## Reference repos worth opening (not importing wholesale)

- `github.com/KenneyNL/Starter-Kit-Racing` — GridMap track-tile placement pattern, Godot 4.6.
- `github.com/choijunhuk/arcade-kart-racer` — Godot 4.7 arcade kart racer built phase-by-phase, closest genre match to this project; useful for comparing item/drift/local-multiplayer structuring choices, not for copying code wholesale (different architecture).
- `github.com/QueenOfSquiggles/godot-kart-racer`, `github.com/kirca/godot_vehicle_arcade` — smaller Godot kart-racer examples, useful for `VehicleBody3D` tuning comparisons.
- `github.com/nonunknown/crash-team-racing-godot` — CTR-inspired physics/kart-handling reference if deeper drift/powerslide tuning is wanted later.
