# 01 — Core Systems & Logic

Implementation contracts for every autoload and the networking model. Build in this order; each system should be testable offline before the next is wired in.

## 1. GameManager (`autoload/game_manager.gd`)

**Responsibility:** global match state machine. Single source of truth for "what phase are we in."

**State enum:**
```gdscript
enum MatchPhase { MENU, LOBBY, COUNTDOWN, RACING, RESULTS }
```

**Exposed state:**
- `current_phase: MatchPhase`
- `current_format: String` — one of `"1v1"`, `"duo"`, `"squad"`, `"ffa"`
- `race_timer: float`
- `lap_count: int` (fixed at 3)

**Signals:**
- `phase_changed(new_phase: MatchPhase)`
- `race_started()`
- `race_finished(results: Array)`

**Logic notes:**
- Only `GameManager` may mutate `current_phase`; every other system reacts to `phase_changed`.
- On dedicated server, `GameManager` phase transitions are authoritative and replicated to clients via RPC; clients never self-transition to `RACING` or `RESULTS`.

## 2. LobbyManager (`autoload/lobby_manager.gd`)

**Responsibility:** room lifecycle.

**Data:**
- `room_code: String` (4-digit, generated on host create)
- `players: Dictionary` — `{ peer_id: { name, vehicle_class, character_id, ready: bool } }`
- `max_players := 16`

**Functions (contract, not implementation):**
- `create_room(format: String) -> String` — returns room code, host-only
- `join_room(code: String) -> bool`
- `set_ready(peer_id: int, ready: bool)`
- `can_start() -> bool` — true when all players ready AND slot count valid for `current_format`

**Signals:**
- `player_joined(peer_id)`
- `player_left(peer_id)`
- `all_players_ready()`

**Logic notes:**
- Room code collision check on generation (regenerate if in use).
- If host leaves mid-lobby, promote next-joined peer to host (reassign RPC authority for room control calls).
- Under-filled private rooms: bot-fill is an open design flag — implement `players` dict to tolerate a `is_bot: bool` field even if bot-fill logic ships later.

## 3. TeamManager (`autoload/team_manager.gd`)

**Responsibility:** team assignment + team-level scoring.

**Data:**
- `teams: Dictionary` — `{ team_id: [peer_id, peer_id, ...] }`
- `team_scores: Dictionary` — `{ team_id: float }`

**Functions:**
- `assign_teams(format: String, player_ids: Array)` — even distribution; `1v1`/`ffa` → each player is their own team of 1
- `compute_team_score(team_id: int) -> float` — **default formula: sum of teammates' finishing positions (lower = better)**; flag this as tunable per Open Design Question in the GDD
- `get_team_ranking() -> Array` — sorted team_ids by score ascending

**Signals:**
- `teams_assigned(teams: Dictionary)`
- `team_score_updated(team_id, new_score)`

## 4. MatchmakingService (`autoload/matchmaking_service.gd`)

**Responsibility:** pairs random players into a lobby respecting format.

**Functions:**
- `enqueue(peer_id: int, format: String)`
- `dequeue(peer_id: int)`
- `_try_form_lobby(format: String)` — internal, fires when enough queued players match format's required slot count (2 for 1v1, multiples of 2 for duo, multiples of 4 for squad, up to 16 for ffa)

**Logic notes:**
- Skill/ping-based balancing is a stretch goal — stub the function signature (`_score_player(peer_id) -> float`) now so it can be filled in later without refactoring the queue.
- On lobby formed, hand off to `LobbyManager.create_room()` server-side, then RPC room code to matched peers.

## 5. BoundaryManager (`autoload/boundary_manager.gd`)

**Responsibility:** tracks in/out-of-bounds state per player per map; drives off-track respawn.

**Data:**
- `player_states: Dictionary` — `{ peer_id: { in_bounds: bool, off_track_timer: float, last_checkpoint: Vector3 } }`

**Logic notes:**
- Every map's boundary geometry is `Area3D` nodes tagged with group `"boundary_wall"` (hard) or `"boundary_soft"` (slow-down zone).
- On `body_exited` from the drivable-area `Area3D` volume: start a `Timer` (2–3s default, confirm per-map). On timeout, teleport player to `last_checkpoint` and reset velocity.
- On soft boundary contact (snowbank, hay bale, crops): apply a velocity dampening multiplier (e.g. `* 0.5`) for the duration of overlap — no timer, no respawn.
- Checkpoints update `last_checkpoint` via `Area3D` groups `"checkpoint"`, validated in order (store `expected_next_checkpoint_index` per player; crossing out of order is ignored, not counted).
- This system must run authoritative-side only; clients receive position corrections via RPC, never decide their own respawn.

## 6. ChaosEventSystem (`autoload/chaos_event_system.gd`)

**Responsibility:** server-triggered global events, Signal-broadcast to all clients.

**Data:**
- `active_events: Array` — currently running `ChaosEventData` resources
- `event_pool: Array[ChaosEventData]` — all available events, filtered per-map by `MapData.weighted_events`

**Functions:**
- `_pick_next_event() -> ChaosEventData` — weighted random from pool, weights come from current map's `MapData`
- `trigger_event(event: ChaosEventData)` — server-only; applies effect, starts duration timer, emits signal
- `_on_event_expired(event: ChaosEventData)`

**Signals:**
- `chaos_event_triggered(event: ChaosEventData)`
- `chaos_event_ended(event: ChaosEventData)`

**Logic notes:**
- Fire interval: random within a designer-tunable range (e.g. 25–45s), never two events simultaneously at launch (simplifies sync + readability — stack support is a post-launch stretch).
- All physics-affecting logic (gravity inversion, bridge collapse) executes server-side and is replicated as *state*, not recomputed per client — e.g. broadcast `gravity_scale = -1` and duration, don't ask clients to independently simulate the flip.
- Boundary containment: gravity inversion / collapse events must not let a player's velocity exceed the boundary containment check in `BoundaryManager` — treat this as a shared invariant, test them together.

## 7. Vehicle Controller (`scripts/vehicles/vehicle_controller.gd`)

Base script attached to every vehicle scene root (`VehicleBody3D`).

**Loads:** a `KartStats` Resource (`.tres`) per instance, assigned in the editor or at spawn time based on player's class selection.

**Exposed per-class tunables (from `KartStats` resource):**
- `top_speed: float`
- `acceleration: float`
- `turning_radius: float`
- `mass: float`
- `drift_boost_curve: Curve`
- `collision_shape_scale: Vector3` — wider for trucks, narrower for motorcycles/bicycles

**Input handling:**
- One-thumb virtual steering axis + auto-accelerate toggle (read from a `Control`-based on-screen joystick, not keyboard, though keyboard should work for editor testing).
- Drift held → charges a `boost_charge` float 0–1 using `drift_boost_curve`; release → apply forward impulse scaled by `boost_charge`.
- Item button → calls `ItemSystem.use_item(held_item)` (see `02_VEHICLES_AND_ITEMS.md`).

**Networking:**
- Local player: full input processed locally, position sent via `MultiplayerSynchronizer` at a fixed tick rate; server validates against `top_speed`/`acceleration` bounds (basic anti-cheat — reject or clamp implausible deltas).
- Remote players: interpolate received transform, no local physics simulation of their vehicle.

## 8. RPC / Authority Conventions

- All state-changing calls that affect fairness (item hits, chaos events, race results, respawns) are `@rpc("authority", "call_local")` — only the server calls them, and they always also run locally on the server.
- Player *input* (steering, item-use request) is `@rpc("any_peer")` sent to the server, which validates and then re-broadcasts the *result* via an authority RPC.
- Never trust a client-reported outcome (e.g. "I hit player X with banana") — server re-validates hit detection server-side before broadcasting the effect.
