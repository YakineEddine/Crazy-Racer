extends Node
## BoundaryManager — in/out-of-bounds + checkpoints + respawn (01 §5).
## Autoritaire cote serveur ; clients recoivent des corrections, jamais d'auto-respawn.

signal player_respawned(peer_id: int)
signal lap_completed(peer_id: int, lap: int)

var player_states: Dictionary = {} ## { key: { in_bounds, off_track_timer, last_checkpoint, next_checkpoint, lap, pos } }
var off_track_delay: float = 2.5
var lap_start: Dictionary = {} ## { key: race_timer au debut du tour }
var last_lap: Dictionary = {} ## { key: dernier temps }
var best_lap: Dictionary = {} ## { key: meilleur temps }
var _vehicle_by_key: Dictionary = {}

func reset() -> void:
	player_states.clear()
	lap_start.clear()
	last_lap.clear()
	best_lap.clear()
	_vehicle_by_key.clear()

func start_clock() -> void:
	# Appele au GO : zero les chronos du tour en cours.
	for k in player_states:
		lap_start[k] = 0.0
	last_lap.clear()
	best_lap.clear()

func _key_of(vehicle: Node) -> int:
	if vehicle.get("peer_id") != null:
		return int(vehicle.get("peer_id"))
	return vehicle.get_instance_id()

func register_vehicle(vehicle: Node) -> void:
	var k := _key_of(vehicle)
	_vehicle_by_key[k] = vehicle
	if not player_states.has(k):
		player_states[k] = {
			"in_bounds": true, "off_track_timer": 0.0,
			"last_checkpoint": vehicle.global_transform.origin if vehicle is Node3D else Vector3.ZERO,
			"next_checkpoint": 1, "lap": 1, "finished": false,
		}
		lap_start[k] = GameManager.race_timer
	# Brancher les Area3D checkpoints : le vehicule emet via ses propres Area detectors.
	if vehicle.has_signal("checkpoint_entered"):
		if not vehicle.is_connected("checkpoint_entered", _on_vehicle_checkpoint):
			vehicle.connect("checkpoint_entered", _on_vehicle_checkpoint.bind(vehicle))

func _process(delta: float) -> void:
	if GameManager.current_phase != GameManager.MatchPhase.RACING:
		return
	if _is_client():
		return
	for k in player_states.keys():
		var st: Dictionary = player_states[k]
		if bool(st.get("finished", false)):
			continue
		var v: Node = _vehicle_by_key.get(k, null)
		if not is_instance_valid(v):
			continue
		# Filet anti-chaos : hors limites absolues => off-track (meme par-dessus les murs).
		if v is Node3D:
			var pp: Vector3 = (v as Node3D).global_position
			if absf(pp.x) > 78.0 or absf(pp.z) > 58.0 or pp.y < -2.0 or pp.y > 30.0:
				st["in_bounds"] = false
		# Hors-piste : timer puis teleport au dernier checkpoint.
		if not bool(st.get("in_bounds", true)):
			st["off_track_timer"] = float(st.get("off_track_timer", 0.0)) + delta
			if float(st["off_track_timer"]) >= off_track_delay:
				_respawn(k)

func _is_client() -> bool:
	return multiplayer.has_multiplayer_peer() and not multiplayer.is_server()

func set_in_bounds(vehicle: Node, in_bounds: bool) -> void:
	if _is_client():
		return
	var k := _key_of(vehicle)
	_ensure(k, vehicle)
	player_states[k]["in_bounds"] = in_bounds
	if in_bounds:
		player_states[k]["off_track_timer"] = 0.0

func apply_soft_zone(vehicle: Node, in_zone: bool, factor: float = 0.5) -> void:
	if vehicle.has_method("set_soft_slow"):
		vehicle.call("set_soft_slow", in_zone, factor)

func _ensure(k: int, vehicle: Node) -> void:
	if not player_states.has(k):
		var p := (vehicle as Node3D).global_transform.origin if vehicle is Node3D else Vector3.ZERO
		player_states[k] = {"in_bounds": true, "off_track_timer": 0.0, "last_checkpoint": p, "next_checkpoint": 1, "lap": 1, "finished": false}
		_vehicle_by_key[k] = vehicle

func _on_vehicle_checkpoint(index: int, vehicle: Node) -> void:
	if _is_client():
		return
	var k := _key_of(vehicle)
	_ensure(k, vehicle)
	var st: Dictionary = player_states[k]
	var expected := int(st.get("next_checkpoint", 1))
	# Ordre strict : hors-ordre ignore, jamais compte (03 §4).
	if index != expected:
		return
	if vehicle is Node3D:
		st["last_checkpoint"] = (vehicle as Node3D).global_transform.origin
	var total: int = _checkpoint_total()
	st["next_checkpoint"] = expected + 1
	if int(st["next_checkpoint"]) >= total:
		# Tour boucle : ligne 0 valide le tour.
		pass

func on_start_finish(vehicle: Node) -> void:
	if _is_client():
		return
	var k := _key_of(vehicle)
	_ensure(k, vehicle)
	var st: Dictionary = player_states[k]
	var total: int = _checkpoint_total()
	if int(st.get("next_checkpoint", 1)) >= total:
		st["next_checkpoint"] = 1
		st["lap"] = int(st.get("lap", 1)) + 1
		# Chrono du tour boucle.
		var now: float = GameManager.race_timer
		var lt: float = now - float(lap_start.get(k, 0.0))
		last_lap[k] = lt
		if not best_lap.has(k) or lt < float(best_lap[k]):
			best_lap[k] = lt
		lap_start[k] = now
		if vehicle is Node3D:
			st["last_checkpoint"] = (vehicle as Node3D).global_transform.origin
		lap_completed.emit(k, int(st["lap"]))
		if int(st["lap"]) > GameManager.lap_count:
			st["finished"] = true
			_report_finish(vehicle, k)

func _checkpoint_total() -> int:
	var n := get_tree().get_nodes_in_group("checkpoint").size()
	return maxi(n, 2)

func _report_finish(vehicle: Node, k: int) -> void:
	# Construit le classement au fil des arrivees.
	var arr: Array = GameManager.results.duplicate()
	var pos := arr.size() + 1
	arr.append({"peer_id": k, "position": pos, "vehicle": str(vehicle.get_path()) if is_instance_valid(vehicle) else ""})
	if pos >= _vehicle_by_key.size():
		GameManager.finish_race(arr)
	else:
		GameManager.results = arr

func _respawn(k: int) -> void:
	var v: Node = _vehicle_by_key.get(k, null)
	if not is_instance_valid(v) or not (v is Node3D):
		return
	var st: Dictionary = player_states[k]
	var target: Vector3 = st.get("last_checkpoint", (v as Node3D).global_transform.origin)
	(v as Node3D).global_transform.origin = target + Vector3(0, 1.5, 0)
	if v.get("linear_velocity") != null:
		v.set("linear_velocity", Vector3.ZERO)
		v.set("angular_velocity", Vector3.ZERO)
	if v.has_method("reset_effects"):
		v.call("reset_effects")
	st["in_bounds"] = true
	st["off_track_timer"] = 0.0
	player_respawned.emit(k)
	if multiplayer.has_multiplayer_peer():
		_apply_respawn.rpc(k, target)

@rpc("authority", "call_local", "reliable")
func _apply_respawn(k: int, target: Vector3) -> void:
	if multiplayer.is_server():
		return
	var v: Node = _vehicle_by_key.get(k, null)
	if is_instance_valid(v) and v is Node3D:
		(v as Node3D).global_transform.origin = target + Vector3(0, 1.5, 0)
