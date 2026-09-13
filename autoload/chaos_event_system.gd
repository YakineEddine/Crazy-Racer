extends Node
## ChaosEventSystem — events globaux serveur, broadcast Signal (01 §6).
## Intervalle 25-45s, jamais 2 simultanes au lancement. Physique serveur, repliquee en *etat*.

signal chaos_event_triggered(event: ChaosEventData)
signal chaos_event_ended(event: ChaosEventData)

var active_events: Array = []
var event_pool: Array = [] ## Array[ChaosEventData]
var min_interval: float = 25.0
var max_interval: float = 45.0
var current_map_id: String = "map1_neon"
var allow_chaos: bool = true ## false en contre-la-montre

var _timer: float = 0.0
var _next_in: float = 30.0
var _racing: bool = false
var _rng := RandomNumberGenerator.new()

const EVENT_PATHS := [
	"res://assets/resources/event_gravity.tres",
	"res://assets/resources/event_collapse.tres",
	"res://assets/resources/event_meteor.tres",
	"res://assets/resources/event_dino.tres",
]

func _ready() -> void:
	_rng.randomize()
	for p in EVENT_PATHS:
		var e: ChaosEventData = load(p) as ChaosEventData
		if e:
			event_pool.append(e)

func on_race_start(map_id: String) -> void:
	current_map_id = map_id
	active_events.clear()
	if not allow_chaos:
		_racing = false
		set_process(false)
		return
	_racing = true
	_next_in = _rng.randf_range(12.0, 18.0) ## premier event plus tot pour la demo
	_timer = 0.0
	set_process(true)

func on_race_end() -> void:
	_racing = false
	for e in active_events.duplicate():
		_on_event_expired(e)
	set_process(false)

func _process(delta: float) -> void:
	if not _racing:
		return
	if GameManager.current_phase != GameManager.MatchPhase.RACING:
		return
	if _is_client():
		return
	_timer += delta
	if not active_events.is_empty():
		return ## jamais 2 simultanes
	if _timer >= _next_in:
		_timer = 0.0
		_next_in = _rng.randf_range(min_interval, max_interval)
		var e := _pick_next_event()
		if e:
			trigger_event(e)

func _is_client() -> bool:
	return multiplayer.has_multiplayer_peer() and not multiplayer.is_server()

func _map_weights() -> Dictionary:
	var paths := {
		"map1_neon": "res://assets/resources/map1_data.tres",
		"map2_swamp": "res://assets/resources/map2_data.tres",
		"map3_ice": "res://assets/resources/map3_data.tres",
		"map4_farm": "res://assets/resources/map4_data.tres",
	}
	var md: MapData = load(paths.get(current_map_id, paths["map1_neon"])) as MapData
	if md:
		return md.weighted_events
	return {}

func _pick_next_event() -> ChaosEventData:
	var weights := _map_weights()
	var total := 0.0
	var cands: Array = []
	for e in event_pool:
		var w: float = float(weights.get(e.id, e.base_weight))
		if w <= 0.0:
			continue
		cands.append([e, w])
		total += w
	if cands.is_empty():
		return null
	var r := _rng.randf() * total
	for pair in cands:
		r -= float(pair[1])
		if r <= 0.0:
			return pair[0]
	return cands[0][0]

## Serveur uniquement.
func trigger_event(event: ChaosEventData) -> void:
	if _is_client():
		return
	active_events.append(event)
	_apply_effect(event, true)
	chaos_event_triggered.emit(event)
	if multiplayer.has_multiplayer_peer():
		_broadcast_event.rpc(event.id, true)
	# Reaction partagee : geste "surpris" pour tous (05 §3).
	get_tree().call_group("vehicles", "play_surprise")
	await get_tree().create_timer(event.duration).timeout
	_on_event_expired(event)

func _on_event_expired(event: ChaosEventData) -> void:
	if not active_events.has(event):
		return
	active_events.erase(event)
	_apply_effect(event, false)
	chaos_event_ended.emit(event)
	if not _is_client() and multiplayer.has_multiplayer_peer():
		_broadcast_event.rpc(event.id, false)

func _apply_effect(event: ChaosEventData, on: bool) -> void:
	match event.id:
		"gravity_inversion":
			var g := -9.8 if on else 9.8
			for v in get_tree().get_nodes_in_group("vehicles"):
				if v.get("gravity_scale") != null:
					v.set("gravity_scale", -1.0 if on else 1.0)
			ProjectSettings.set_setting("physics/3d/default_gravity", g)
			get_tree().call_group("maps", "set_gravity_visual", on)
		"track_collapse":
			get_tree().call_group("maps", "set_shortcut_collapsed", on)
		"dino_stampede":
			if on:
				get_tree().call_group("maps", "start_dino_stampede", event.duration)
			else:
				get_tree().call_group("maps", "stop_dino_stampede")
		"meteor_shower":
			if on:
				get_tree().call_group("maps", "start_meteor_shower", event.duration)
			else:
				get_tree().call_group("maps", "stop_meteor_shower")

@rpc("authority", "call_local", "reliable")
func _broadcast_event(event_id: String, on: bool) -> void:
	if multiplayer.is_server():
		return
	var e := _find(event_id)
	if e == null:
		return
	if on and not active_events.has(e):
		active_events.append(e)
		_apply_effect(e, true)
		chaos_event_triggered.emit(e)
	elif not on and active_events.has(e):
		active_events.erase(e)
		_apply_effect(e, false)
		chaos_event_ended.emit(e)

func _find(event_id: String) -> ChaosEventData:
	for e in event_pool:
		if e.id == event_id:
			return e
	return null
