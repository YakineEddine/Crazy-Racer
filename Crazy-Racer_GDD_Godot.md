# CRAZY RACER — Game Design Document

*Master reference document — consolidates game systems, vehicles, maps, and asset requirements.*

---

## 1. Overview

| Field | Detail |
|---|---|
| Working Title | Crazy Racer |
| Genre | Party Racing / Kart Racer, Multiplayer |
| Platform | Mobile (Android & iOS) |
| Business Model | Free-to-Play, Zero Pay-to-Win |
| Engine | **Godot 4.x (GDScript, with optional C# via the .NET build)** |
| Target Audience | Casual gamers, friend groups, party/competitive game fans |
| Max Players per Room | 16 |

**Pitch:** A fast, chaotic, unpredictable kart racer built for group play. Victory depends as much on driving skill as on smart item usage and reacting to absurd global events (gravity flips, collapsing tracks, meteor showers). Comic, over-the-top presentation — losers get "humiliated" in the funniest way possible.

---

## 2. Art Direction & Tone

- **Visual style:** Cartoon / Synthwave / Low-poly hybrid — colorful, bold shapes, optimized for low/mid-range phones.
- **Tone:** Silly, festive, mocking-but-friendly. Comedy is a core pillar, not a side effect.
- **Audio direction:** Exaggerated comedic voice lines, cartoonish sound effects (quacks, honks, screams), ridiculous celebration/humiliation stingers.
- **Asset families needed:** vehicles (see Section 6), characters/creatures (crocodiles, penguins, chickens, and more), environmental props (chaos-event-specific assets), and four themed maps (see Section 7).

---

## 3. Core Gameplay Loop

1. **Lobby & Matchmaking**
   - Host creates a private room (4-digit code) or joins Quick Play (public random matchmaking).
   - Room supports up to **16 players**.
   - Host selects match format before start (see Section 4).
2. **Customization**
   - Vehicle, character, cosmetics selection (cosmetic-only, no stat impact on Pay-to-Win axis, though vehicle *class* — see Section 6 — does affect handling as a skill/strategy choice, not a paid advantage).
3. **Race (3 laps)**
   - Driving, drifting, boosting.
   - Item pickups on track.
   - Interaction with dynamic hazards and global Chaos Events.
   - Track boundaries keep all players inside the playable race space (see Section 7.6).
4. **Finish & Rewards**
   - Podium/results screen, XP toward Battle Pass, in-game currency payout.
   - Comic humiliation animations for bottom placements.

---

## 4. Multiplayer Modes & Team Structure

### 4.1 Room Capacity
- Max **16 players** per room.

### 4.2 Match Formats (host-selectable at lobby creation)
| Format | Structure | Example Fill |
|---|---|---|
| 1v1 | 2 solo players | Direct duel |
| Duo | Teams of 2 | Up to 8 teams × 2 |
| Squad | Teams of 4 | Up to 4 teams × 4 |
| Free-for-all | All solo | Up to 16 individuals |

- Matchmaking must dynamically balance lobbies based on selected format.
- Team scoring: shared/aggregated team score (not just individual placement) for Duo/Squad formats — team ranking should reflect combined performance (e.g., sum or best-N of teammates' finishing positions).

### 4.3 Online Modes
- **Random Matchmaking:** quick play against random opponents, matched by selected format.
- **Private/Friends Room:** invite via 4-digit code, custom format selection, can mix bots to fill if under capacity (optional design decision — flag for later).

### 4.4 Required Systems
- **LobbyManager:** handles room creation, code generation, player slot assignment, format selection, ready-check.
- **TeamManager:** assigns players to teams based on format, tracks team-level state (score, elimination status if relevant).
- **MatchmakingService:** pairs/pools random players according to selected format and (ideally) skill/ping-based balancing.

---

## 5. Controls

- Mobile-first, one-thumb driving (virtual steering / auto-accelerate options considered).
- Dedicated item-use button (fire/trigger collected item).
- Drift mechanic tied to boost charge (standard kart-racer convention — confirm exact drift-to-boost curve during prototyping).
- Vehicle-class-specific handling feel (see Section 6) means control tuning must be re-validated per class, not assumed identical across the roster.

---

## 6. Vehicles

All vehicles are cosmetic/strategic choices, not pay-to-win — differences are in **handling feel**, not raw power ceiling. Each class should end up roughly balanced (e.g., fast-but-fragile-handling vs. slow-but-stable) so no single class dominates.

### 6.1 Vehicle Classes

| Class | Description | Handling Profile | Roster Examples |
|---|---|---|---|
| **Karts** | The baseline class, standard 4-wheel small racer | Balanced speed/handling — the "default" reference class all others are tuned against | Standard Kart, Rocket Kart |
| **Cars** | Slightly larger sedans/hatchbacks reskinned as racers | Higher top speed, wider turning radius (harder to thread tight corners) | Compact Racer, Muscle Car reskin |
| **Trucks / Camions** | Heavy vehicles (pickup, monster-truck style) | High mass — plows through small hazards (bananas, chicken swarms) and other karts on contact, but slow acceleration and poor drift agility | Pickup Bruiser, Monster Camion |
| **Motorcycles** | 2-wheel, lean-based steering | Fastest acceleration and tightest turning, but most vulnerable to knockback/spin-out from hits (low stability) | Sport Bike, Chopper |
| **Bicycles** | Novelty/joke-tier vehicle, human or animal-pedaled | Slowest top speed by design, but extremely tight turning and immune/resistant to certain "size-based" hazards (e.g., can slip through gaps trucks can't) — a comedic underdog/skill pick | BMX, Beach Cruiser |

*(Design intent: Trucks/Camions and Bicycles are the two "extreme" picks — one leans into mass/collision, the other into agility/novelty — while Karts, Cars, and Motorcycles form the more competitive middle ground. This gives the roster comedic range and genuine strategic variety.)*

### 6.2 Shared Vehicle Requirements

- Every vehicle needs: a wheel-rotation rig (or lean-rig for motorcycles/bicycles), a `CollisionShape3D` matched to its class (trucks get wider colliders, bicycles/motorcycles get narrower ones — this matters for the "gap-slipping" design intent above), and drift/boost VFX anchor points (`Marker3D` nodes for particle spawn positions).
- Cosmetic skins per class (e.g., a truck could be a "rolling bed" or "jet-powered camion") plug into the same base rig per class, so art doesn't need a new skeleton per skin — only per class.
- See Section 14 (Asset List) for file formats and polycount targets.

---

## 7. Maps & Tracks

Four launch maps, each themed to a Chaos Event and part of the character roster, so world, mechanics, and cast reinforce each other. See Section 14.3 for the build methodology (modular tile-based tracks, Godot Scene per map, glTF prefab pieces) and open-source starter assets.

### 7.1 Map 1 — "Neon Circuit City" (Synthwave Urban Night Track)

- **Setting:** Neon-lit city streets at night, glowing road edges, skyscraper silhouettes, holographic billboards.
- **Route:** A wide figure-eight-adjacent loop — start/finish on a straight main avenue, leading into a sweeping right-hand curve around a central plaza, then up an on-ramp to an **elevated highway loop** (the map's signature shortcut: faster but narrower, with lower guardrails), rejoining the main avenue via a tunnel section before the final straight.
- **Checkpoints:** 4 (start/finish, plaza exit, highway loop merge, tunnel exit).
- **Shortcut(s):** Elevated highway loop (risk: narrower lane, more exposed to being knocked off during the "collapsing track" Chaos Event).
- **Signature Chaos Event:** Live track modification — sections of the elevated highway can collapse mid-race, closing the shortcut and forcing a reroute back through the plaza.
- **Borders/Boundary handling:** Street-level curbs and guardrails as physical `CollisionShape3D` colliders along the main route; the elevated highway has raised guardrail meshes (higher collision walls, since a fall here should read as a bigger mistake); city-block edges beyond the drivable street are sealed with invisible `StaticBody3D` collision walls dressed behind building facades so the city "reads" as endless without being drivable.

### 7.2 Map 2 — "Swamp Gator Grand Prix" (Jungle/Swamp Track)

- **Setting:** Murky swamp, dense jungle canopy, wooden rope bridges, crocodile-infested waters (thematically tied to the crocodile character roster).
- **Route:** A tight, twisty course — start/finish on a dirt clearing, into a series of S-curves through jungle undergrowth, across two narrow rope bridges over swamp water, then a muddy uphill switchback before the final descent back to the clearing.
- **Checkpoints:** 5 (start/finish, first bridge entry, second bridge entry, switchback summit, final descent).
- **Shortcut(s):** A narrow log-crossing shortcut through the swamp water itself — faster, but very narrow with no side protection.
- **Signature Chaos Event:** Meteor/obstacle shower — falling debris knocks jungle trees onto the track as new temporary obstacles.
- **Borders/Boundary handling:** Rope bridges have physical rail colliders (low, so falling off is possible but intentional — falling into the swamp triggers a respawn-on-track penalty via an `Area3D` trigger rather than a hard wall); the jungle tree-line beyond the route is a dense, deliberately impassable prop wall (trees placed edge-to-edge as informal boundary) backed by an invisible collision plane so players can't clip through gaps in the foliage.

### 7.3 Map 3 — "Frozen Waddle Way" (Arctic/Ice Track)

- **Setting:** Icy tundra, frozen lake, igloo props, aurora-lit sky — directly reinforces the Penguin-transform item mechanic.
- **Route:** Start/finish on a packed-snow straight, curving around an ice-cave tunnel, out onto the open **frozen lake** (the shortcut), around a cluster of igloos, and back via a final icy hairpin turn to the start straight.
- **Checkpoints:** 4 (start/finish, ice-cave exit, lake exit, igloo cluster exit).
- **Shortcut(s):** Frozen lake crossing — significantly faster, but low-traction (naturally slippery even without the Penguin item effect, via a low-friction `PhysicsMaterial`) and features a "thin ice" hazard zone that can crack under multiple simultaneous vehicles (see Chaos Event tie-in).
- **Signature Chaos Event:** Gravity Inversion — thematically the most natural fit here (floaty, icy, slapstick feel already matches the visual tone), triggering ~10 seconds of inverted gravity anywhere on the track.
- **Borders/Boundary handling:** Snowbank walls (soft-collision, low-speed-penalty on contact rather than a hard stop, to keep the "icy chaos" feel) line the main route; the frozen lake shortcut is bounded by visible crack-lines in the ice with invisible hard walls just beyond the visual ice edge (falling through into open water should be a rare, obviously-telegraphed event, not an invisible-wall surprise).

### 7.4 Map 4 — "Barnyard Bedlam" (Farm/Rural Track)

- **Setting:** Open farmland, barns, hay bales, tractors, wheat fields — ties to the Chicken character/item roster.
- **Route:** Start/finish alongside the main barn, a wide sweeping route around the outer fence-line of the farm, cutting past a silo, through an open field section, and back past a tractor-filled equipment yard to the finish.
- **Checkpoints:** 4 (start/finish, silo turn, field midpoint, equipment yard exit).
- **Shortcut(s):** Cutting directly through the wheat field instead of following the fence-line road — faster, but crops slightly slow the vehicle (a "soft" penalty shortcut, good for lower-skill vehicles like Bicycles which suffer less from the drag).
- **Signature Chaos Event:** Chicken Storm feels most at home here; the map is also the natural testbed for a future "loose farm animals wander onto track" hazard type (flagged as a roadmap idea, not a launch requirement).
- **Borders/Boundary handling:** Wooden fence-line as the primary boundary collider around the whole farm perimeter (thematically consistent — it's literally a farm fence); hay bale stacks and barn walls double as secondary blockers at specific points where the fence alone wouldn't stop players from cutting into non-drivable areas.

### 7.5 Route Design Principles (applies to all 4 maps)

- Every map needs a minimum of one **shortcut with a genuine risk/reward trade-off** (narrower path, hazard exposure, or a soft speed penalty) — never a "free" shortcut with no downside.
- Every map's signature Chaos Event should have a **visually/thematically obvious reason to occur there**, reinforcing world-building instead of feeling randomly bolted on.
- Checkpoint counts (4–5 per map) exist for lap-validation and anti-cheat (a lap only counts if all checkpoints were crossed in order, tracked via `Area3D` checkpoint triggers) — this also lets the server correct/respawn a player who falls off-route.

### 7.6 Map Borders / Out-of-Bounds System

Every map must prevent players from leaving the intended race space. Recommended approach (applies to all maps, with per-map dressing as described above):

1. **Physical boundary colliders:** invisible (or thematically dressed, like fences/guardrails/tree-lines) `StaticBody3D`/`CollisionShape3D` geometry placed along the entire perimeter of the drivable area, including around shortcuts.
2. **Soft vs. hard boundaries:** where possible, boundaries should be *soft* (a slow-down/redirect nudge, like a snowbank or hay bale) rather than a hard stop, since hard walls feel bad in a comedic arcade racer — reserve true hard walls for cases where falling off should read as a clear, telegraphed mistake (e.g., off the elevated highway, into the swamp, through thin ice).
3. **Out-of-bounds recovery:** if a player somehow clips past a boundary (physics glitch, chaos-event side effect), a server-side "off-track" timer (an `Area3D` exit signal driving a `Timer` node) should trigger an automatic respawn onto the nearest checkpoint after a few seconds, rather than leaving them stuck outside the map.
4. **Chaos Event interaction with boundaries:** events like Gravity Inversion or collapsing track sections must not be able to fling a player past the outer boundary — boundary colliders should be tall/deep enough (or capped) to contain even chaos-event physics extremes.

---

## 8. Items & Chaotic Mechanics

### 8.1 Player-Triggered Items (picked up on track, used via item button)

| Item | Effect |
|---|---|
| Reverse Gun (Pistolet Inverseur) | Temporarily reverses target's steering controls |
| Shrink Ray (Rayon Réducteur) | Turns targeted kart into something slow/comedic (bathtub, snail) |
| Chicken Storm (Pluie de Poulets) | Obscures target's view / disrupts their trajectory |
| Banana Super Boost | Forward speed boost while leaving a slippery trail behind |
| Rocket → Penguin Transform | Direct hit turns the targeted kart's driver into a **penguin for 7 seconds** — impaired handling during that window (signature "humiliation" effect) |

*(This list is extensible — item roster should keep growing through production; each item needs: pickup rarity, effect duration, cooldown, and a comedic VFX/SFX pass.)*

### 8.2 Global Chaos Events (ChaosEventSystem — server-triggered, affects all players simultaneously)

- Gravity Inversion (10 seconds)
- Live track modification (bridges collapsing, new shortcuts opening)
- Meteor/giant obstacle shower

Events fire at random intervals per race, broadcast server-side so all clients stay in sync (critical for fairness — must be deterministic or tightly synced, not client-guessed, via Godot's high-level multiplayer RPCs). See Section 7 for which map each event is thematically anchored to (all events can technically fire on any map — the "signature" tie-in is about where they land best narratively/visually).

---

## 9. Comedy & Presentation Layer

- **Voice lines:** exaggerated reactions on win/lose/hit/getting hit, per-character comedic barks.
- **Humiliation animations:** triggered on low placement or on being hit by signature items (e.g., penguin waddle animation + quack SFX).
- **Celebration animations:** over-the-top podium dances, confetti, taunt gestures for top finishers.
- **Chaos event reactions:** all players get a shared reaction beat (e.g., synced "surprised" voice line) when a global event triggers, to sell the chaos as a communal moment.

---

## 10. Technical Architecture (Godot / GDScript)

### 10.1 Networking
- Client-server architecture using Godot's **High-Level Multiplayer API** (`MultiplayerAPI`, `MultiplayerSpawner`, `MultiplayerSynchronizer`).
- Client-side prediction to hide latency for local player movement.
- Server-authoritative for: race results, item hit resolution, Chaos Event triggers, team scoring, out-of-bounds/respawn decisions (anti-cheat baseline) — enforced via `@rpc("authority")` calls, with player input sent up via `@rpc("any_peer")`.

### 10.2 Data Structure
- **Custom `Resource` scripts (`.tres` files)** for static data — decouples data from logic, lets designers tune without touching code:
  - `KartStats` (`class_name KartStats extends Resource`) — per-vehicle stats (speed, acceleration, turning radius, mass, drift profile) — one per vehicle *class* (Kart/Car/Truck/Motorcycle/Bicycle), with skins referencing the same class stats.
  - `CharacterData` — per-character data (animation set, voice bark set).
  - `ItemData` — per-item effect data (duration, cooldown, VFX/SFX references).
  - `ChaosEventData` — per-event data (duration, trigger conditions, affected systems).
  - `MapData` (new) — per-map metadata (checkpoint list, boundary collider references, shortcut definitions, which Chaos Events are weighted more likely on this map).

### 10.3 Design Patterns
- **Singleton (Autoload):** `GameManager` — global state (match phase, timers, current format), registered as a Godot Autoload.
- **Observer (Signals):** `ChaosEventSystem` — Godot `Signal`-based broadcast/subscription for global events (`chaos_event_triggered.emit(event_data)`, listeners `connect()` to it).
- **Object Pooling:** custom pool script (or the community Object Pool plugin) for projectiles, item VFX, hazard instances — avoids GC/instantiation spikes on mobile.

### 10.4 Core Systems
- `LobbyManager` (Autoload — room creation, code system, slot management)
- `TeamManager` (Autoload — team assignment, team-level scoring/state)
- `MatchmakingService` (Autoload — random pairing respecting selected format)
- `BoundaryManager` (new, Autoload) — tracks each player's in-bounds/out-of-bounds state per map via `Area3D` triggers, drives the off-track respawn timer described in Section 7.6.

---

## 11. Monetization

- **Zero Pay-to-Win:** no purchase affects speed or stats — vehicle *class* choice (Section 6) is a free strategic decision available to everyone, not a paid unlock tier.
- **Cosmetic IAP:** absurd vehicle skins per class (rolling bed, jet bathtub, rolling couch, etc.), silly characters, celebration/humiliation animation packs.
- **Seasonal Battle Pass:** 30-day progression, free track + premium track (FOMO-driven premium track).
- **Opt-in Rewarded Ads:** player chooses to watch a short ad to double post-race XP or trial a skin for free.

---

## 12. Development Roadmap

| Phase | Focus |
|---|---|
| 1 | Core architecture & offline driving prototype (`VehicleBody3D` + custom Resource data), including at least one vehicle per class and one blockout map with boundaries |
| 2 | Multiplayer network layer (lobby, matchmaking, kart sync, team system) |
| 3 | Item system, weapons, ChaosEventSystem (Signal-based Observer pattern) |
| 4 | UI (lobby, race HUD, results screen) |
| 5 | Mobile optimization (Object Pooling, visibility-range LODs, network call reduction) |
| 6 | Monetization integration (shop, Battle Pass, rewarded ads) |
| 7 | Full 4-map rollout with final art, per-map boundary/shortcut polish |

**Note:** Team/Lobby system (16-player rooms, 1v1/Duo/Squad formats) should be folded into **Phase 2**, since it's core to the multiplayer architecture, not a later add-on. Recommend prototyping Phase 1 using one of the free Godot vehicle-physics templates listed in Section 14.4 to validate vehicle-class feel before committing final art.

---

## 13. Open Design Questions (to resolve before deeper production)

- Should under-filled private rooms be padded with bots, or strictly wait for human players?
- Exact drift → boost mechanic tuning per vehicle class (feel target: arcade-forgiving vs. skill-gated).
- Team scoring formula for Duo/Squad (sum of positions? best finisher counts double? etc.)
- Full extensible item list — current 5 items are a strong start but roadmap needs a target count (e.g., 15–20 at launch) for pickup variety.
- Anti-cheat approach for server-authoritative validation on item hits, chaos events, and boundary/out-of-bounds decisions.
- Exact balance pass needed between vehicle classes (Trucks/Camions vs. Bicycles especially, since they're the two "extreme" picks).
- Whether additional maps beyond the 4 launch tracks are planned per season (ties into Battle Pass content cadence).

---

## 14. Appendix — Asset List, Formats & Open-Source Resources

### 14.1 File Format Standards (Godot mobile pipeline)

| Asset Type | Format | Notes |
|---|---|---|
| 3D Models (vehicles, characters, props) | **.glb (glTF 2.0)** preferred, **.fbx** also supported | glTF is Godot's most reliably-supported import path; FBX works too but glTF avoids extra import-plugin friction |
| Rigged/Animated characters | **.glb** with embedded skeleton + `AnimationLibrary` | Skeleton reuse across characters where possible to save animation cost |
| Textures | **.PNG** (with alpha) | 512×512–1024×1024 max per texture for mobile; Godot auto-generates `AtlasTexture`s to cut draw calls |
| Track/environment geometry | **.glb** (modular pieces), placed via Godot **GridMap** (`MeshLibrary`) | Modular tile-based, snapped to a grid unit (10m or 20m recommended) |
| UI Icons/HUD | **.SVG** (source, importable directly) or **.PNG** | SVG during design, exported to PNG sprite sheets at runtime if needed |
| Audio (SFX) | **.WAV** | Item pickups, hits, voice barks — uncompressed for low-latency triggers |
| Audio (Music/Ambience) | **.OGG** (Ogg Vorbis) | Background music, ambient loops — Godot's native streaming format |
| VFX | **GPUParticles3D** (native), with **CPUParticles3D** fallback | GPU particles risk poor compatibility on the very lowest-end Android GPUs — keep a CPU fallback path |
| Animations | **AnimationPlayer** clips (embedded in .glb) or Godot `AnimationLibrary` (.tres) | Short, loopable clips (idle, celebration, humiliation, hit-reaction) |

**Mobile optimization targets:**
- Vehicles: 1,500–4,000 triangles (LOD0), with visibility-range LOD1/LOD2 for distant karts.
- Characters: 2,000–5,000 triangles, rigged, 3–5 second animation loops.
- Track modules: under ~1,000 triangles per tile (tiles repeat heavily per scene via GridMap).

### 14.2 Full Asset List

**Vehicles** (per class in Section 6: Kart, Car, Truck/Camion, Motorcycle, Bicycle)
- Base model per class (.glb, rigged wheels or lean-rig)
- Cosmetic skins per class (same rig, new mesh/material)
- Wheel/drift/boost trail VFX (GPUParticles3D scene, `.tscn`)

**Characters**
- Generic human driver base (.glb, rigged)
- Crocodile driver (.glb, rigged, idle/celebration/humiliation clips)
- Penguin driver (.glb, rigged — doubles as the "transformed" state model for the Rocket item)
- Chicken driver (.glb, rigged, flap/panic animation — also basis for Chicken Storm swarm VFX)
- Future roster expansions (reuse shared skeleton across characters to save animation cost)

**Items/Props**
- Reverse Gun projectile (.glb + .png icon)
- Shrink Ray beam VFX + shrink-target models (bathtub/snail)
- Chicken Storm swarm (low-poly chicken LOD reused)
- Banana peel/boost trail (.glb + GPUParticles3D scene)
- Rocket projectile + impact VFX + penguin transform model
- Item pickup box (.glb + rotation script, `.gd`)

**Environment / Chaos Events**
- Meteor/giant obstacle (.glb + impact VFX)
- Collapsing bridge segment (.glb + `AnimationPlayer` or physics-break script)
- Gravity-flip VFX (GPUParticles3D / `CanvasLayer` post-processing shader trigger)
- Ice patch / slippery zone decal (.png decal + `PhysicsMaterial`)
- Per-map boundary dressing: guardrails (Map 1), rope-bridge rails & tree-line walls (Map 2), snowbank/ice-crack visuals (Map 3), fence-line & hay bales (Map 4)

**UI/HUD**
- Lobby UI (room code, player slots, format selector) — built from Godot `Control` nodes + a shared `Theme` resource
- Race HUD (position, lap counter, item slot, minimap)
- Results/podium screen (with team score breakdown for Duo/Squad)

**Audio**
- Voice barks per character (.wav)
- SFX for items, hits, chaos events (.wav)
- Music: lobby, race (per-map variant recommended), results (.ogg)
- Ambient loops per map theme (.ogg)

### 14.3 Map Build Methodology

- **Build method:** Modular tile-based tracks — repeatable road/terrain segments (straight, curve, incline, bridge, intersection) placed via Godot's **GridMap** node, snapped to a fixed grid unit.
- **Recommended tools:** Godot's built-in **GridMap** + **CSGShape3D** nodes for fast blockout before final art swap.
- **File format per map:** Each map = one Godot **Scene (.tscn)** built from modular `.glb` mesh instances registered in a `MeshLibrary`; the map itself isn't a single exported file.
- **Structure requirement per map:** start/finish line, checkpoint triggers (`Area3D`, lap validation + anti-cheat), item box placement, at least one risk/reward shortcut, boundary colliders around the full perimeter (Section 7.6), and a zone suited to that map's signature Chaos Event.

### 14.4 Open-Source / Free Assets for Testing

*Always verify the license on each individual asset page before shipping commercially — most below are CC0 (public domain) or MIT, but confirm per-asset.*

**Godot-native vehicle/driving starters**
- SRCoder — Simple Car (CC0): drag-and-drop arcade car + follow camera, good baseline for a Kart-class prototype: https://godotengine.org/asset-library/asset/3610
- DAShoe — Godot Easy Vehicle Physics (MIT): 4 ready demo vehicles — `demo_arcade` (kart-like), `demo_simcade`, `demo_monster_truck` (Truck/Camion-class reference), `demo_drift`: https://godotengine.org/asset-library/asset/2558
- 3D Car with Settingspanel (Godot Asset Library): drivable `VehicleBody3D` car with a tunable wheel/suspension settings panel: https://godotengine.org/asset-library/asset/661
- fluxrider — godot_3d_racing (GitHub, open source): basic non-realistic kart-physics racing template, the closest free analogue to a "kart racing starter project": https://github.com/fluxrider/godot_3d_racing

**Vehicles (art)**
- Kenney — Racing Pack (420 assets, CC0): https://kenney.nl/assets/racing-pack
- Kenney — Racing Kit (110 assets, CC0): https://kenney.nl/assets/racing-kit
- Kenney — Car Kit (40+ vehicles, CC0): https://kenney.nl/assets/car-kit

**Characters/Animals** (crocodile, penguin, chicken, etc.)
- OpenGameArt — CC0 3D Animals/Creatures: https://opengameart.org/content/cc0-3d-animals-creatures
- Kenney — Animal Pack (80 assets, CC0): https://kenney.nl/assets/animal-pack
- ITHappy Studios — Animals Free Pack (rigged/animated, includes penguin & chicken): https://ithappystudios.com/free/animals-free/

**Track/Environment Kits**
- Kenney — Nature Kit (330 assets, CC0): https://kenney.nl/assets/nature-kit
- Kenney — City Kit (Roads) (90 modular road assets, CC0): https://kenney.nl/assets/city-kit-roads
- Fertile Soil Productions — Modular Racekart Track (Hilly Terrain), CC0, 200+ snap-together pieces designed for kart tracks: https://fertile-soil-productions.itch.io/modular-racekart-track-hilly-terrain-theme
- Fertile Soil Productions — Hexagonal Racetrack Collection, CC0: https://fertile-soil-productions.itch.io/hexagonal-racetrack-collection

**Bonus**
- Kenney — Game Assets All-in-1 (60,000+ assets, one-time low cost, covers UI/audio/everything else): https://kenney.itch.io/kenney-game-assets

**Recommended first step:** Import DAShoe's **Godot Easy Vehicle Physics** for Phase 1 to validate vehicle-class feel (Kart/Car baseline vs. Truck/Motorcycle extremes) immediately, then progressively swap in Kenney/OpenGameArt themed assets per map as final art comes online.

---

*End of document — living reference, to be updated as systems get prototyped.*
