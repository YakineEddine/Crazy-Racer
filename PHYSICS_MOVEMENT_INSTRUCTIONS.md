# Physics & Movement Instructions — Crazy Racer v1.1

Baseline: `GAMEPLAY_RULES.md` §1 (current per-vehicle stat/suspension tables) and `PROJECT_AUDIT.md` §4.29/§4.27 (`vehicle_mesh_builder.gd`, `driver_builder.gd`). Read `AI_AGENT_INSTRUCTIONS.md` §-1 before touching anything in `vehicle_controller.gd` — the forward-axis fix there is fragile and must survive every change below.

## 1. Vehicle asset swap (remove default procedural meshes, use downloaded CC0 models)

Current state: 5 of 8 vehicles (Kart, Car, Truck, Motorcycle, Bicycle) are built entirely from procedural primitives in `VehicleMeshBuilder` (boxes/cylinders for chassis/seat/steering/spoiler, per class). Only Sport/Taxi/SUV mount real FBX shells (Quaternius pack), with static wheels hidden and the project's own animated wheels layered underneath (`model_factory.gd`'s wheel-hiding logic, name-string-matched against `REAL_MODELS` in `vehicle_mesh_builder.gd`).

Goal: replace the procedural bodies with free, ready-made vehicle models (no Blender authoring involved — these are downloaded, not custom-modeled), following the **same pattern already proven** by Sport/Taxi/SUV — don't invent a second mounting system. Recommended sources, all CC0/free:

- **`poly.pizza`** — a searchable aggregator of CC0 models (mostly Quaternius + Kenney), downloadable directly as `.glb`, no login required. Search per vehicle class (`kart`, `motorcycle`, `bicycle`, `truck`) and pick the closest style match to the existing Quaternius cars already in the project, for visual consistency.
- **Kenney Car Kit** (`kenney.nl/assets/car-kit`) — 45 CC0 models including cars/trucks/vans; good source for the Truck class specifically.
- **`github.com/KenneyNL/Starter-Kit-Racing`** — this repo already bundles ready drivable vehicle models including a motorcycle (`vehicle-motorcycle.glb`/`.tscn`) — usable directly for the Motorcycle class without further searching.
- Kart and Bicycle are the two hardest to find pre-made (most free packs skew toward cars/trucks) — search `poly.pizza` for "go kart" / "bicycle" specifically; if nothing fits well, it's reasonable to leave those two as the existing procedural build for now and only swap the classes where a good free model exists.

Steps:

1. Download each model as `.glb` (preferred over `.fbx` for Godot 4 — smaller, no import-orientation surprises) from one of the sources above, into `assets/models/vehicles_custom/` (new folder, mirrors the existing `assets/models/cars/` etc. convention). Keep each source's license/attribution file alongside them (CC0 doesn't require attribution, but it's good practice to document sourcing in-repo the same way as the map assets).
2. In `vehicle_mesh_builder.gd`, extend the existing `REAL_MODELS` dictionary/branch (the one that currently only lists Sport/Taxi/SUV) to include the new vehicle classes and their model paths — this is a data addition to an existing `match`/dictionary, per `AI_AGENT_INSTRUCTIONS.md` §1's "lookup dictionary, not if/elif chain" rule.
3. Reuse `model_factory.gd`'s existing defensive-instantiate + wheel-hiding-by-name logic unchanged; if the Blender file's wheel mesh names don't match the current substring match, either rename them in Blender before export (cheapest) or add the new name variants to the match list — don't rewrite the matching strategy.
4. Target-size normalization: the current FBX path scales each shell to fit a fixed chassis footprint per vehicle (`vehicle_mesh_builder.gd` targets ~2.9×2.9×3.4 against each model's native bounds, then offsets `y=-1.05`). Compute the same kind of bounding-box-based scale/offset for the new models instead of hardcoding a guessed scale — this keeps wheel contact and collision shape alignment correct across differently-proportioned Blender exports.
5. **Do not change `CollisionShape3D`/`BoxShape3D` sizes or `KartStats.mass`/handling values as a side effect of the visual swap** — those are gameplay-tuning values (`GAMEPLAY_RULES.md` §1) and changing them silently by "matching the new model's size" will retune the whole game's balance. If the new model's proportions genuinely warrant a collision-shape change, do that as an explicit, separately-documented step, not bundled into the asset swap.
6. Driver placement: keep using `ItemHoldAnchor`/the existing driver-seat offset per vehicle; adjust only the seat `y`-offset if the new model's cockpit height differs, same as the FBX path already does (`driver y −0.9/−0.7` per class, `PROJECT_AUDIT.md` §4.29).
7. After swapping, re-verify §"Before finishing any task" in `AI_AGENT_INSTRUCTIONS.md` — specifically the FBX-mounting-can-silently-break-wheel-hiding warning already called out there.

The coding agent's job here is steps 1(placement)–7 once the `.glb` files are downloaded to your machine — point it at wherever you saved them (Downloads folder is fine, same as the Kenney track-asset flow) and it copies/organizes/wires them in, the same as it already did for the Kenney track tiles.

## 2. Motorcycle — real instability (can lean/turn too hard and fall over)

Current state (`GAMEPLAY_RULES.md` §1): all 8 vehicles run identical wheel physics (suspension/damping/friction differ only by the auto-tuned-by-mass table added in the last pass) with the same "always upright" `VehicleBody3D` behavior; Motorcycle only differs numerically (top speed 25, accel 19, turn radius 0.85, knockback 1.6× — "only vehicle whose knockback >1.3 triggers full spin-out"). There is no risk of tipping over from **the player's own steering/speed**, only from being hit.

Target: motorcycle-specific handling that can punish aggressive turning at speed, without becoming unfun or fighting the "arcade party racer, not simulation" design target (`GAMEPLAY_RULES.md`/`AI_AGENT_INSTRUCTIONS.md` §3).

Suggested approach (data + a small per-class branch, not a fork of the shared script — `AI_AGENT_INSTRUCTIONS.md` §0 forbids per-vehicle script forks):

- Add a `lean_angle` (visual, via the existing 2× lean animation already applied to the Motorcycle mesh) driven by current steering input × speed, and a **stability threshold**: past some combined (steer input × speed) value, instead of just visual lean, apply a temporary steering/traction penalty (reduced `wheel_friction_slip` for N frames, or a forced partial spin-out reusing the existing >1.3-knockback spin-out code path) so the bike visibly struggles rather than teleporting into a crash animation.
- Gate this behind a new `KartStats` field (e.g. `tip_over_risk: float`, default `0.0` for all classes except Motorcycle) so it's data-driven per `AI_AGENT_INSTRUCTIONS.md` §3's rule against new dead `@export` fields — wire it into the controller in the same change, don't add it as a placeholder.
- Keep `max_steer` and the documented drift/boost thresholds untouched (`GAMEPLAY_RULES.md` §1 explicitly calls these out as "never change without documenting old/new values") — this is a new penalty layered on top of existing steering, not a change to the steering curve itself.
- Playtest target: this should be noticeable but not make the Motorcycle strictly worse than Kart/Bicycle for a careful player — it's a skill-expression risk/reward class, matching the class's already-higher knockback/lower mass profile.

## 3. Animal drivers — real locomotion instead of a static posed rider

Current state (`driver_builder.gd`, `PROJECT_AUDIT.md` §4.27): farm-animal drivers (cow/horse/llama/pig/pug/sheep/zebra) are FBX models scaled and rotated onto the seat as a static prop (`torso`/`arms`/`helmet` are the human/procedural fallback only; animal FBX drivers currently have **no per-limb animation tied to vehicle motion**). `LIREMOI-JOUER.md` §8 already notes these are "modèles animés, Idle" — i.e. whatever built-in idle animation ships with the Quaternius FBX, not something reactive to driving.

Target: give animal drivers *some* reactive movement — legs/body responding to acceleration, braking, and turning — without building a full animation-blend system from scratch (out of scope for a party-kart driver prop).

Suggested approach:

- Check what animation clips actually ship inside each farm FBX (`ModelFactory`'s substring anim-match + first-clip-fallback logic, `PROJECT_AUDIT.md` §4.8, already handles picking a clip by name) — if a "run"/"gallop"/"trot" clip exists alongside "Idle", play that one scaled by current speed (`AnimationPlayer.speed_scale = clamp(current_speed / top_speed, ...)`) instead of always defaulting to Idle. This reuses existing infrastructure rather than adding new animation import work.
- Add a lightweight procedural layer on top for reactivity the FBX clips can't give you: a small body-lean (`rotation.x`) proportional to acceleration/braking (lean back on throttle, forward on brake — same idea as the Motorcycle's lean in §2, reusing that code path/pattern rather than writing a second lean system), and head/torso yaw proportional to steering input, applied to the animal's root bone or a wrapping `Node3D` if bone access is impractical.
- Don't attempt full quadruped IK foot-planting — that's simulation-grade work disproportionate to a background driver prop in an arcade racer. The bar is "looks alive and reacts to input", not "biomechanically accurate gait".
- Keep this decoupled from vehicle choice (`GAMEPLAY_RULES.md` §6: "any character can pilot any vehicle" must stay true) — the reactive-movement layer belongs to the **character**, applied wherever that character is currently seated, same as `CharacterData.voice_pitch` already applies regardless of vehicle.
- This applies equally to the existing Quaternius farm FBX drivers already in the project **and** to any new downloaded driver models added per §4 below — one reactive-movement layer, not two.

## 4. Driver/character asset swap (human + animal models)

Current state: `driver_builder.gd` builds the human driver (and the procedural croco/penguin/chicken drivers) from primitives, and mounts the 7 farm-animal FBX (`assets/models/farm/*.fbx`) as static seated props (§3 above covers making those move). This is a separate track from §1's vehicle swap, but uses the same underlying idea: downloaded, ready-made models replacing procedural or currently-static ones.

If new human/animal driver models are added (downloaded, not custom-authored — same CC0 sources as §1), follow the same discipline as the vehicle swap:

- Mount new models the same way `driver_builder.gd` already mounts the 7 farm FBX — reuse the existing per-character scale/offset/rotation pattern (`PROJECT_AUDIT.md` §4.27's magic numbers: e.g. cow scale 0.20, pig 0.22, at `(0,−0.15,0.1)` rotated `PI`) as the template, computing an equivalent scale/offset for each new model from its own bounding box rather than reusing another character's numbers verbatim.
- `CharacterData` is the schema for character roster entries (`AI_AGENT_INSTRUCTIONS.md` §1: "new characters should be new `.tres` resources of these existing classes"). Adding a new drivable character (not just re-skinning an existing one) means a new `character_*.tres` with its own `voice_pitch`, not a hardcoded branch.
- If a new model is meant to **replace** an existing character's look (e.g. a better cow model swapping out the current one) rather than add a new character, keep the same `character_id` string and just swap what `driver_builder.gd` mounts for it — don't rename the id, since it's referenced by string across scripts/`.tres` files (`AI_AGENT_INSTRUCTIONS.md` §1's "don't rename fields referenced by string" rule extends to character ids).
- Human driver: if a downloaded human model is meant to replace the current procedural build, it still needs to fit through the same helmet/visor mounting logic (`driver_builder.gd`'s torso/arms/helmet primitives currently sit on top of/around the procedural body) — a full human FBX may need that helmet logic adapted to attach at a head-bone offset instead of a fixed primitive position; treat this as its own sub-step, not an assumption that it'll just work.
