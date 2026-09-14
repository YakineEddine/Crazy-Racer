extends Node
## GameManager — machine a etats + modes Course / Grand Prix / Contre-la-montre (01 §1).
## Seul ce singleton mute current_phase. Transitions autoritaires serveur -> RPC.

enum MatchPhase { MENU, LOBBY, COUNTDOWN, RACING, RESULTS, PAUSED, AUTH, BOARD }

signal phase_changed(new_phase: int)
signal race_started()
signal race_finished(results: Array)

var current_phase: int = MatchPhase.MENU
var current_format: String = "ffa" ## "1v1","duo","squad","ffa"
var race_timer: float = 0.0
var lap_count: int = 3
var current_map_id: String = "map1_neon"
var results: Array = []
var mode: String = "single" ## "single","gp","tt"

var gp_order: Array = ["map1_neon", "map2_swamp", "map3_ice", "map4_farm"]
var gp_index: int = 0
var gp_points: Dictionary = {} ## { nom: pts }
var gp_final: bool = false
var tt_last: Dictionary = {} ## { total, best, is_record, map }

## Classement en ligne : contexte board + anti-double-soumission par course.
var board_return: int = MatchPhase.MENU
var board_map_id: String = "map1_neon"
var results_submitted: bool = false

## Reglages persistants (section "settings" du meme cfg, defauts = comportement actuel).
var settings_music: bool = true
var settings_volume: float = 1.0 ## 0.0..1.0, bus Master
var settings_quality: String = "high" ## "high" ou "low" (VfxFactory)

const GP_TABLE := [15, 12, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1]
const SAVE_PATH := "user://crazy_racer.cfg"

var _ui_layer: CanvasLayer = null
var _map_holder: Node3D = null
var _current_ui: Control = null
var _current_map: Node3D = null
var _countdown_time: float = 0.0

## Poursuite camera (lissage) : meme fov/offset de repos qu'avant, suivi adouci.
const CAM_OFFSET := Vector3(0, 3.2, 6.5)
const CAM_PITCH_DEG := -14.0
const CAM_POS_SMOOTH := 6.0
const CAM_YAW_SMOOTH := 5.0
var _chase_rigs: Array = [] ## [{rig: Node3D, vehicle: Node3D}]

const UI_SCENES := {
	0: "res://scenes/ui/main_menu.tscn",
	1: "res://scenes/ui/lobby_screen.tscn",
	2: "res://scenes/ui/countdown_overlay.tscn",
	3: "res://scenes/ui/race_hud.tscn",
	4: "res://scenes/ui/results_screen.tscn",
	5: "res://scenes/ui/pause_menu.tscn",
	6: "res://scenes/ui/auth_screen.tscn",
	7: "res://scenes/ui/leaderboard_screen.tscn",
}

const MAP_SCENES := {
	"map1_neon": "res://scenes/maps/map1_neon_circuit_city.tscn",
	"map2_swamp": "res://scenes/maps/map2_swamp_gator_gp.tscn",
	"map3_ice": "res://scenes/maps/map3_frozen_waddle_way.tscn",
	"map4_farm": "res://scenes/maps/map4_barnyard_bedlam.tscn",
}

const MAP_SHORT := {"map1_neon": "Neon", "map2_swamp": "Swamp", "map3_ice": "Glace", "map4_farm": "Ferme"}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()

static func fmt_time(t: float) -> String:
	return "%d:%05.2f" % [int(t) / 60, fmod(maxf(t, 0.0), 60.0)]

func map_name(map_id: String) -> String:
	var paths := {
		"map1_neon": "res://assets/resources/map1_data.tres",
		"map2_swamp": "res://assets/resources/map2_data.tres",
		"map3_ice": "res://assets/resources/map3_data.tres",
		"map4_farm": "res://assets/resources/map4_data.tres",
	}
	if ResourceLoader.exists(paths.get(map_id, "")):
		var md: MapData = load(paths[map_id]) as MapData
		if md:
			return md.display_name
	return str(MAP_SHORT.get(map_id, map_id))

func register_layers(ui_layer: CanvasLayer, map_holder: Node3D) -> void:
	_ui_layer = ui_layer
	_map_holder = map_holder
	_show_ui_for_phase()

func change_phase(new_phase: int) -> void:
	if new_phase == current_phase:
		return
	if _is_networked() and not multiplayer.is_server():
		if new_phase == MatchPhase.RACING or new_phase == MatchPhase.RESULTS:
			push_warning("[GameManager] client refuse self-transition vers RACING/RESULTS")
			return
	current_phase = new_phase
	phase_changed.emit(current_phase)
	_show_ui_for_phase()
	if _is_networked() and multiplayer.is_server():
		_broadcast_phase.rpc(current_phase)

@rpc("authority", "call_local", "reliable")
func _broadcast_phase(new_phase: int) -> void:
	if multiplayer.is_server():
		return
	current_phase = new_phase
	phase_changed.emit(current_phase)
	_show_ui_for_phase()

func _is_networked() -> bool:
	return multiplayer.has_multiplayer_peer()

func _show_ui_for_phase() -> void:
	if _ui_layer == null:
		return
	if is_instance_valid(_current_ui):
		_current_ui.queue_free()
		_current_ui = null
	var path: String = UI_SCENES.get(current_phase, "")
	if path == "":
		return
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("[GameManager] UI introuvable: " + path)
		return
	_current_ui = packed.instantiate() as Control
	_ui_layer.add_child(_current_ui)
	_current_ui.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_current_ui, "modulate:a", 1.0, 0.25)

## --- Entrees menu ---

func request_quick_play(format: String, map_id: String) -> void:
	mode = "single"
	gp_final = false
	current_format = format
	current_map_id = map_id
	LobbyManager.create_room(format)
	LobbyManager.set_ready(multiplayer.get_unique_id(), true)
	LobbyManager.ensure_bot_fill()
	change_phase(MatchPhase.LOBBY)
	if not _is_networked():
		start_countdown()

func start_gp_lobby(format: String) -> void:
	mode = "gp"
	gp_index = 0
	gp_points.clear()
	gp_final = false
	current_format = format
	current_map_id = gp_order[0]
	LobbyManager.create_room(format)
	LobbyManager.set_ready(multiplayer.get_unique_id(), true)
	LobbyManager.ensure_bot_fill()
	change_phase(MatchPhase.LOBBY)

func start_tt(map_id: String) -> void:
	mode = "tt"
	gp_final = false
	current_format = "ffa"
	current_map_id = map_id
	LobbyManager.leave_all()
	start_countdown()

## --- Cycle de course ---

func start_countdown() -> void:
	if _is_networked() and not multiplayer.is_server():
		return
	get_tree().paused = false
	_load_map()
	_spawn_racers()
	results_submitted = false
	change_phase(MatchPhase.COUNTDOWN)
	_countdown_time = 3.5
	set_process(true)
	if _is_networked():
		_begin_countdown.rpc()

@rpc("authority", "call_local", "reliable")
func _begin_countdown() -> void:
	_countdown_time = 3.5
	set_process(true)

func _process(delta: float) -> void:
	if current_phase == MatchPhase.RACING:
		race_timer += delta
		if race_timer > 600.0:
			finish_race([])
	elif current_phase == MatchPhase.COUNTDOWN:
		_countdown_time -= delta
		if _countdown_time <= 0.0:
			_begin_race()
	_update_chase_cams(delta)

func _begin_race() -> void:
	change_phase(MatchPhase.RACING)
	race_timer = 0.0
	race_started.emit()
	_lock_controls(false)
	BoundaryManager.start_clock()
	ChaosEventSystem.allow_chaos = (mode != "tt")
	ChaosEventSystem.on_race_start(current_map_id)

func _lock_controls(locked: bool) -> void:
	get_tree().call_group("vehicles", "set_controls_locked", locked)

## --- Pause (RACING <-> PAUSED, locale uniquement, pas de RPC) ---

func pause_race() -> void:
	if current_phase != MatchPhase.RACING:
		return
	if _is_networked() and not multiplayer.is_server():
		return
	_lock_controls(true)
	change_phase(MatchPhase.PAUSED)
	get_tree().paused = true

func resume_race() -> void:
	if current_phase != MatchPhase.PAUSED:
		return
	get_tree().paused = false
	change_phase(MatchPhase.RACING)
	# _pre_go est faux ici (pose pendant RACING debloque, jamais pendant PAUSED
	# car la physique est gelee) : pas de turbo surprise a la reprise.
	_lock_controls(false)

func toggle_pause() -> void:
	if current_phase == MatchPhase.RACING:
		pause_race()
	elif current_phase == MatchPhase.PAUSED:
		resume_race()

func get_display_name(pid: int) -> String:
	var info: Dictionary = LobbyManager.players.get(pid, {})
	return str(info.get("name", "Joueur %d" % pid))

func finish_race(ordered_results: Array) -> void:
	if current_phase != MatchPhase.RACING:
		return
	if _is_networked() and not multiplayer.is_server():
		return
	results = ordered_results
	for r in results:
		TeamManager.register_finish(int(r.get("peer_id", 1)), int(r.get("position", 1)))
	if mode == "gp":
		_award_gp_points()
	elif mode == "tt":
		_save_tt_result()
	ChaosEventSystem.on_race_end()
	change_phase(MatchPhase.RESULTS)
	race_finished.emit(results)
	if _is_networked():
		_broadcast_results.rpc(results)

func _award_gp_points() -> void:
	for i in results.size():
		var r: Dictionary = results[i]
		var pname := get_display_name(int(r.get("peer_id", 0)))
		var pts: int = GP_TABLE[mini(i, GP_TABLE.size() - 1)]
		gp_points[pname] = int(gp_points.get(pname, 0)) + pts
	gp_final = gp_index >= gp_order.size() - 1
	if gp_final:
		var champ := gp_standings()
		if not champ.is_empty() and str(champ[0].get("name", "")) == get_display_name(multiplayer.get_unique_id()):
			add_gp_win()

func gp_standings() -> Array:
	var arr: Array = []
	for pname in gp_points:
		arr.append({"name": pname, "pts": int(gp_points[pname])})
	arr.sort_custom(func(a, b) -> bool: return int(a["pts"]) > int(b["pts"]))
	return arr

func gp_next() -> void:
	if gp_final or gp_index + 1 >= gp_order.size():
		return
	gp_index += 1
	current_map_id = gp_order[gp_index]
	_cleanup_race()
	start_countdown()

func _save_tt_result() -> void:
	var total := race_timer
	var me := multiplayer.get_unique_id()
	var best := float(BoundaryManager.best_lap.get(me, total))
	var prev: Dictionary = get_tt_best(current_map_id)
	var is_record := not prev.has("total") or total < float(prev.get("total", INF))
	tt_last = {"total": total, "best": best, "is_record": is_record, "map": current_map_id}
	if is_record:
		var cfg := _load_cfg()
		cfg.set_value("tt", current_map_id, {"total": total, "best": best})
		cfg.save(SAVE_PATH)

func get_tt_best(map_id: String) -> Dictionary:
	return dict(_load_cfg().get_value("tt", map_id, {}))

func get_tt_bests() -> Dictionary:
	var out := {}
	var cfg := _load_cfg()
	for m in gp_order:
		if cfg.has_section_key("tt", m):
			out[m] = dict(cfg.get_value("tt", m))
	return out

func get_gp_wins() -> int:
	return int(_load_cfg().get_value("carriere", "gp_wins", 0))

func add_gp_win() -> void:
	var cfg := _load_cfg()
	cfg.set_value("carriere", "gp_wins", get_gp_wins() + 1)
	cfg.save(SAVE_PATH)

func dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}

## --- Reglages persistants (meme fichier, section "settings") ---

func load_settings() -> void:
	var cfg := _load_cfg()
	settings_music = bool(cfg.get_value("settings", "music", true))
	settings_volume = clampf(float(cfg.get_value("settings", "volume", 1.0)), 0.0, 1.0)
	var q := str(cfg.get_value("settings", "quality", "high"))
	settings_quality = q if (q == "low" or q == "high") else "high"

func save_settings() -> void:
	var cfg := _load_cfg()
	cfg.set_value("settings", "music", settings_music)
	cfg.set_value("settings", "volume", settings_volume)
	cfg.set_value("settings", "quality", settings_quality)
	cfg.save(SAVE_PATH)

func apply_settings() -> void:
	# Pousse vers Audio (bus + musique) et VfxFactory. Appele par Audio._ready
	# (Audio demarre apres GameManager, reglages deja charges) et par chaque setter.
	VfxFactory.particle_quality = VfxFactory.Quality.LOW if settings_quality == "low" else VfxFactory.Quality.HIGH
	Audio.set_master_volume(settings_volume)
	Audio.set_music_enabled(settings_music)

func set_music_enabled(on: bool) -> void:
	settings_music = on
	apply_settings()
	save_settings()

func set_volume(v: float) -> void:
	settings_volume = clampf(v, 0.0, 1.0)
	apply_settings()
	save_settings()

func set_quality(q: String) -> void:
	settings_quality = "low" if q == "low" else "high"
	apply_settings()
	save_settings()

func _load_cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return cfg

@rpc("authority", "call_local", "reliable")
func _broadcast_results(r: Array) -> void:
	if multiplayer.is_server():
		return
	results = r
	race_finished.emit(results)

func rematch() -> void:
	if mode == "tt":
		start_tt(current_map_id)
		return
	_cleanup_race()
	start_countdown()

func back_to_menu() -> void:
	mode = "single"
	gp_final = false
	_cleanup_race()
	LobbyManager.leave_all()
	change_phase(MatchPhase.MENU)

func _cleanup_race() -> void:
	get_tree().paused = false
	race_timer = 0.0
	results = []
	tt_last = {}
	BoundaryManager.reset()
	ChaosEventSystem.on_race_end()
	if is_instance_valid(_current_map):
		_current_map.queue_free()
		_current_map = null

func _load_map() -> void:
	if _map_holder == null:
		return
	if is_instance_valid(_current_map):
		_current_map.queue_free()
	var path: String = MAP_SCENES.get(current_map_id, MAP_SCENES["map1_neon"])
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("[GameManager] Map introuvable: " + path)
		return
	_current_map = packed.instantiate() as Node3D
	_map_holder.add_child(_current_map)

func _spawn_racers() -> void:
	if _current_map == null:
		return
	var spawns: Array = get_tree().get_nodes_in_group("spawn_point")
	spawns.sort_custom(func(a: Node3D, b: Node3D) -> bool: return str(a.name) < str(b.name))
	var ids: Array = LobbyManager.get_all_peer_ids()
	if ids.is_empty():
		ids = [1]
	TeamManager.assign_teams(current_format, ids)
	var idx := 0
	for pid in ids:
		var info: Dictionary = LobbyManager.players.get(pid, {})
		var vclass: String = str(info.get("vehicle_class", "kart"))
		var ch: String = str(info.get("character_id", "human"))
		_spawn_vehicle(int(pid), vclass, ch, _grid_pos(spawns, idx))
		idx += 1

func _grid_pos(spawns: Array, idx: int) -> Transform3D:
	if spawns.is_empty():
		return Transform3D(Basis(), Vector3(0, 2, -idx * 6.0))
	var s: Node3D = spawns[idx % spawns.size()]
	return s.global_transform

func _spawn_vehicle(peer_id: int, vehicle_class: String, character_id: String, t: Transform3D) -> void:
	var paths := {
		"kart": "res://scenes/vehicles/kart.tscn",
		"car": "res://scenes/vehicles/car.tscn",
		"truck": "res://scenes/vehicles/truck.tscn",
		"motorcycle": "res://scenes/vehicles/motorcycle.tscn",
		"bicycle": "res://scenes/vehicles/bicycle.tscn",
		"sport": "res://scenes/vehicles/sport.tscn",
		"taxi": "res://scenes/vehicles/taxi.tscn",
		"suv": "res://scenes/vehicles/suv.tscn",
	}
	var path: String = paths.get(vehicle_class, paths["kart"])
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("[GameManager] Vehicule introuvable: " + path)
		return
	var v = packed.instantiate()
	v.set("peer_id", peer_id)
	v.set("character_id", character_id)
	v.set("racer_name", get_display_name(peer_id))
	_current_map.add_child(v)
	if v is Node3D:
		(v as Node3D).global_transform = t
	if peer_id == multiplayer.get_unique_id() or (not _is_networked() and peer_id == 1):
		v.add_to_group("local_player")
		_attach_chase_camera(v)

func _attach_chase_camera(v: Node) -> void:
	var cam := Camera3D.new()
	cam.name = "ChaseCam"
	cam.fov = 70.0
	cam.current = true
	var rig := Node3D.new()
	rig.name = "CamRig"
	v.add_child(rig)
	rig.position = CAM_OFFSET
	rig.rotation_degrees = Vector3(CAM_PITCH_DEG, 0, 0)
	rig.add_child(cam)
	# Lissage : le rig ne suit plus le vehicule de facon rigide (collisions, drift,
	# wobble, shrink scalaient/secouaient la vue). En top_level, on le ramene chaque
	# frame vers la position de repos (memes fov/offset), sans changer le setup.
	rig.top_level = true
	_chase_rigs.append({"rig": rig, "vehicle": v})

func _update_chase_cams(delta: float) -> void:
	if _chase_rigs.is_empty():
		return
	# Integration independante du framerate : t = 1 - exp(-vitesse * delta).
	var tp := 1.0 - exp(-CAM_POS_SMOOTH * delta)
	var ty := 1.0 - exp(-CAM_YAW_SMOOTH * delta)
	var pitch := deg_to_rad(CAM_PITCH_DEG)
	var kept: Array = []
	for e in _chase_rigs:
		# Validite AVANT le cast : `as` sur un objet libere (quit vers menu) = erreur.
		var rig_obj: Variant = e.get("rig")
		var veh_obj: Variant = e.get("vehicle")
		if not is_instance_valid(rig_obj) or not is_instance_valid(veh_obj):
			continue
		var rig := rig_obj as Node3D
		var veh := veh_obj as Node3D
		# Cible = offset de repos dans le repere du vehicule (derriere +Z, dessus).
		var target_pos: Vector3 = (veh.global_transform * Transform3D(Basis(), CAM_OFFSET)).origin
		rig.global_position = rig.global_position.lerp(target_pos, clampf(tp, 0.0, 1.0))
		# Suivi du lacet (yaw) uniquement : tangage fixe, roulis a zero.
		# Isole la camera des tonneaux/wobbles, garde le derriere-vue en virage.
		var yaw: float = veh.global_rotation.y
		var cur: Vector3 = rig.global_rotation
		rig.global_rotation = Vector3(pitch, lerp_angle(cur.y, yaw, clampf(ty, 0.0, 1.0)), 0.0)
		kept.append(e)
	_chase_rigs = kept
