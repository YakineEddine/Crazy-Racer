class_name VehicleController
extends VehicleBody3D
## Controleur de base (01 §7 + 02) : KartStats, drift a paliers, rocket-start,
## roulette d'objets, charges x3, pieces, bouclier/etoile, offroad, aspiration,
## caoutchouc IA, bots. Autoritaire serveur, visuel client.

signal checkpoint_entered(index: int)
signal item_changed(item_id: String)

@export var stats: KartStats
@export var peer_id: int = 1
@export var character_id: String = "human"
@export var racer_name: String = "Joueur"

var controls_locked: bool = true
var touch_steer: float = 0.0
var touch_throttle: float = 1.0
var touch_drift: bool = false
var auto_accelerate: bool = true
var _keys_seen: bool = false
var is_bot: bool = false

var held_item: String = ""
var held_charges: int = 0
var pending_item: String = ""
var pending_t: float = 0.0
var boost_charge: float = 0.0
var boosting_time: float = 0.0
var soft_slow_factor: float = 1.0
var coins: int = 0

var reverse_timer: float = 0.0
var shrink_timer: float = 0.0
var chicken_timer: float = 0.0
var penguin_timer: float = 0.0
var slip_timer: float = 0.0
var star_timer: float = 0.0
var shield: bool = false

## NOTE : gravity_scale vient de RigidBody3D (pas de var ici, sinon conflit).
var _orig_scale: Vector3 = Vector3.ONE
var _wheels: Array = []
var _driver: Node3D = null
var _body_mat: StandardMaterial3D = null
var _shield_mesh: MeshInstance3D = null
var _front_meshes: Array = []
var _wheel_meshes: Array = []
var _skid_mat: StandardMaterial3D = null
var _skid_t: float = 0.0
var drift_active: bool = false
var _map: Node = null
var _was_drift: bool = false
var _spark_t: float = 0.0
var _pad_cd: float = 0.0
var _draft: float = 0.0
var _draft_cd: float = 0.0
var _pre_go: bool = false

func _ready() -> void:
	add_to_group("vehicles")
	is_bot = peer_id < 0
	_orig_scale = scale
	if stats == null:
		stats = load("res://assets/resources/kart_stats.tres") as KartStats
	mass = stats.mass
	center_of_mass_mode = 1 # MANUAL : anti-tonneaux
	center_of_mass = Vector3(0, -0.4, 0)
	for c in get_children():
		if c is VehicleWheel3D:
			_wheels.append(c)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = stats.body_color
	_body_mat.roughness = 0.5
	_driver = Node3D.new()
	_driver.name = "Driver"
	_driver.position = Vector3(0, 0.21, 0.35)
	(get_node("Body") as Node3D).add_child(_driver)
	DriverBuilder.build(_driver, character_id)
	VehicleMeshBuilder.build(self)
	_apply_body_color()
	_build_shield()
	_skid_mat = StandardMaterial3D.new()
	_skid_mat.albedo_color = Color(0.05, 0.05, 0.06, 0.55)
	_skid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for n in ["WheelMeshFL", "WheelMeshFR", "WheelMeshRL", "WheelMeshRR"]:
		var wm := get_node_or_null(n) as MeshInstance3D
		if wm:
			_wheel_meshes.append(wm)
	_front_meshes = [get_node_or_null("WheelMeshFL"), get_node_or_null("WheelMeshFR")]
	BoundaryManager.register_vehicle(self)
	set_controls_locked(GameManager.current_phase != GameManager.MatchPhase.RACING)

func _apply_body_color() -> void:
	var body: MeshInstance3D = get_node_or_null("Body") as MeshInstance3D
	if body and _body_mat:
		body.set_surface_override_material(0, _body_mat)

func _build_shield() -> void:
	_shield_mesh = MeshInstance3D.new()
	_shield_mesh.name = "ShieldBubble"
	var sm := SphereMesh.new()
	sm.radius = 1.7
	sm.height = 3.4
	_shield_mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.7, 1.0, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.7, 1.0)
	_shield_mesh.set_surface_override_material(0, mat)
	_shield_mesh.position = Vector3(0, 0.8, 0)
	_shield_mesh.visible = false
	add_child(_shield_mesh)

func set_controls_locked(locked: bool) -> void:
	var was := controls_locked
	controls_locked = locked
	if locked:
		_set_engine(0.0)
		_set_brake(5.0)
	elif was and GameManager.current_phase == GameManager.MatchPhase.RACING and _pre_go:
		# Depart turbo : acceleration maintenue pendant le compte a rebours.
		boosting_time = 1.0
		_pre_go = false
		Audio.play("boost")
		VfxFactory.burst(self, "boost")

func set_soft_slow(in_zone: bool, factor: float = 0.5) -> void:
	soft_slow_factor = factor if in_zone else 1.0

func reset_effects() -> void:
	reverse_timer = 0.0
	shrink_timer = 0.0
	chicken_timer = 0.0
	penguin_timer = 0.0
	slip_timer = 0.0
	star_timer = 0.0
	set_shield(false)
	pending_item = ""
	boost_charge = 0.0
	boosting_time = 0.0
	_draft = 0.0
	scale = _orig_scale
	_refresh_driver_model()

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if controls_locked or GameManager.current_phase != GameManager.MatchPhase.RACING:
		_pre_go = Input.is_action_pressed("ui_up") or touch_drift
		_set_engine(0.0)
		if absf(linear_velocity.length()) > 0.5:
			_set_brake(2.0)
		else:
			_set_brake(0.0)
		return
	var steer := 0.0
	var throttle := 1.0
	var drift := false
	if is_bot:
		var ai := _bot_input()
		steer = float(ai[0])
		throttle = float(ai[1])
		drift = bool(ai[2])
	else:
		steer = Input.get_axis("ui_right", "ui_left")
		if absf(touch_steer) > 0.05 or touch_drift:
			steer = touch_steer
			_keys_seen = false
		if Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right") or Input.is_action_pressed("ui_up") or Input.is_action_pressed("ui_down"):
			_keys_seen = true
		var auto_on := auto_accelerate and not _keys_seen
		if Input.is_action_pressed("ui_up"):
			throttle = 1.0
		elif Input.is_action_pressed("ui_down"):
			throttle = -0.6
		elif auto_on:
			throttle = touch_throttle
		else:
			throttle = 0.0
		drift = Input.is_action_pressed("drift") or touch_drift or Input.is_key_pressed(KEY_SPACE)
		if Input.is_action_just_pressed("item_use"):
			use_item()
	if reverse_timer > 0.0:
		steer = -steer
	if chicken_timer > 0.0:
		steer += sin(Time.get_ticks_msec() / 90.0) * 0.6
	var handling := 1.0
	if penguin_timer > 0.0:
		handling = 0.55
	if shrink_timer > 0.0:
		handling *= 0.8
	if slip_timer > 0.0:
		steer = clampf(steer * 1.8 + sin(Time.get_ticks_msec() / 120.0) * 0.5, -1.0, 1.0)
	# Direction via les roues motrices.
	var max_steer := 0.55 * stats.turning_radius * handling
	_set_steering(lerpf(_get_steering(), steer * max_steer, 12.0 * delta))
	# Vitesse max : pieces (+1.5%/piece), offroad, etoile, caoutchouc IA.
	var speed := linear_velocity.length()
	var off := _offroad_factor(delta)
	var rubber := _rubber_band()
	var star_mult := 1.22 if star_timer > 0.0 else 1.0
	var max_speed := stats.top_speed * soft_slow_factor * off * star_mult * rubber * (1.0 + coins * 0.015)
	if shrink_timer > 0.0:
		max_speed *= 0.6
	var target_force := stats.acceleration * 60.0 * throttle * soft_slow_factor
	if shrink_timer > 0.0:
		target_force *= 0.55
	if boosting_time > 0.0:
		target_force += stats.boost_power * 60.0
		boosting_time -= delta
	if speed > max_speed + 8.0 and _is_server():
		linear_velocity = linear_velocity.normalized() * (max_speed + 8.0)
	if speed < max_speed:
		_set_engine(target_force)
	else:
		_set_engine(0.0)
	_set_brake(0.0)
	if throttle < 0.0:
		_set_brake(8.0)
	# Drift a paliers : bleu (mini) -> orange (super) -> violet (ultra).
	var drifting := drift and absf(steer) > 0.25 and speed > 8.0
	drift_active = drifting
	if drifting:
		boost_charge = minf(1.0, boost_charge + delta * 0.45)
		_spark_t -= delta
		if _spark_t <= 0.0:
			_spark_t = 0.25
			if boost_charge >= 0.7:
				VfxFactory.burst_colored(self, Color(1.0, 0.45, 0.1))
			elif boost_charge >= 0.35:
				VfxFactory.burst_colored(self, Color(0.3, 0.6, 1.0))
		_apply_lean(steer, true)
		_skid_t -= delta
		if _skid_t <= 0.0:
			_skid_t = 0.06
			_spawn_skid("DriftTrailAnchorL")
			_spawn_skid("DriftTrailAnchorR")
	else:
		_apply_lean(steer, false)
	if not drift and _was_drift:
		if boost_charge >= 0.99:
			boosting_time = 1.9
			_squash_stretch()
			Audio.play("boost")
			VfxFactory.burst(self, "boost")
		elif boost_charge >= 0.7:
			boosting_time = 1.2
			_squash_stretch()
			Audio.play("boost")
			VfxFactory.burst(self, "boost")
		elif boost_charge >= 0.35:
			boosting_time = 0.6
			Audio.play("boost")
			VfxFactory.burst(self, "boost")
		boost_charge = 0.0
	if gravity_scale < 0.0:
		apply_central_force(Vector3.UP * 9.8 * mass * 2.0)
	# Roues visuelles : spin + braquage avant.
	var steer_vis := _get_steering()
	for w in _wheels:
		(w as VehicleWheel3D).rotation.x += speed * delta / 0.35
	for wm in _wheel_meshes:
		if is_instance_valid(wm):
			(wm as MeshInstance3D).rotation.x += speed * delta / 0.35
	for fm in _front_meshes:
		if is_instance_valid(fm):
			(fm as MeshInstance3D).rotation.y = steer_vis
	_update_draft(delta, speed)
	if is_bot and held_item != "" and pending_item == "" and randf() < delta * 0.4:
		use_item()

func _apply_lean(steer: float, drifting: bool) -> void:
	_was_drift = drifting
	var body: MeshInstance3D = get_node_or_null("Body") as MeshInstance3D
	if body:
		var target_z := -steer * (0.22 if drifting else 0.06)
		if stats.display_name.contains("Moto") or stats.display_name.contains("Velo"):
			target_z *= 2.0
		body.rotation.z = lerpf(body.rotation.z, target_z, 0.15)

func _squash_stretch() -> void:
	var body: Node3D = get_node_or_null("Body") as Node3D
	if body == null:
		return
	var tw := create_tween()
	tw.tween_property(body, "scale", Vector3(1.15, 0.8, 1.15), 0.09)
	tw.tween_property(body, "scale", Vector3.ONE, 0.18)

func _spawn_skid(anchor_name: String) -> void:
	var anchor := get_node_or_null(anchor_name) as Marker3D
	var parent := get_parent()
	if anchor == null or parent == null or _skid_mat == null:
		return
	if parent.get_child_count() > 400:
		return ## plafond anti-spam
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.35, 0.9)
	mi.mesh = pm
	mi.set_surface_override_material(0, _skid_mat)
	parent.add_child(mi)
	mi.global_position = anchor.global_position
	mi.global_position.y = 0.16
	mi.global_rotation.y = global_rotation.y
	var tw := mi.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(mi, "scale", Vector3(0.6, 1.0, 0.6), 0.8)
	tw.tween_callback(mi.queue_free)

func _tick_timers(delta: float) -> void:
	if reverse_timer > 0.0: reverse_timer -= delta
	if shrink_timer > 0.0:
		shrink_timer -= delta
		if shrink_timer <= 0.0:
			scale = _orig_scale
			# Fin du rayon : on rend le vrai pilote (pingouin si transform actif).
			_refresh_driver_model()
	if chicken_timer > 0.0: chicken_timer -= delta
	if penguin_timer > 0.0:
		penguin_timer -= delta
		if penguin_timer <= 0.0:
			_refresh_driver_model()
	if slip_timer > 0.0: slip_timer -= delta
	if star_timer > 0.0:
		star_timer -= delta
		if randf() < delta * 4.0:
			VfxFactory.burst_colored(self, Color(1.0, 0.9, 0.2))
	if _pad_cd > 0.0: _pad_cd -= delta
	if pending_item != "":
		pending_t -= delta
		if pending_t <= 0.0:
			held_item = pending_item
			held_charges = ItemSystem.charges_for(pending_item)
			pending_item = ""
			item_changed.emit(held_item)
			Audio.play("pickup")

# --- Facteurs arcade ---

func _offroad_factor(delta: float) -> float:
	if not is_instance_valid(_map):
		_map = get_tree().get_first_node_in_group("maps")
	if _map and _map.has_method("is_on_road") and not bool(_map.call("is_on_road", global_position)):
		if randf() < delta * 8.0:
			VfxFactory.burst_colored(self, Color(0.6, 0.5, 0.35))
		return 0.8 if stats.ignores_size_hazards else 0.62
	return 1.0

func _rubber_band() -> float:
	if not is_bot:
		return 1.0
	var st: Dictionary = BoundaryManager.player_states.get(peer_id, {})
	var my := float(st.get("lap", 1)) * 100.0 + float(st.get("next_checkpoint", 1))
	var best := my
	for k in BoundaryManager.player_states:
		var s: Dictionary = BoundaryManager.player_states[k]
		best = maxf(best, float(s.get("lap", 1)) * 100.0 + float(s.get("next_checkpoint", 1)))
	var diff := best - my
	return 1.0 + clampf(diff * 0.02, 0.0, 0.12) - (0.05 if diff <= 0.0 else 0.0)

func _update_draft(delta: float, speed: float) -> void:
	_draft_cd -= delta
	if _draft_cd > 0.0:
		return
	_draft_cd = 0.25
	if speed < 12.0 or controls_locked:
		_draft = maxf(0.0, _draft - 0.5)
		return
	var fwd: Vector3 = -global_transform.basis.z
	fwd.y = 0.0
	var found := false
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v == self or not (v is Node3D):
			continue
		var to: Vector3 = (v as Node3D).global_position - global_position
		var dist := to.length()
		if dist > 1.5 and dist < 7.0:
			to.y = 0.0
			if to.normalized().dot(fwd.normalized()) > 0.75:
				found = true
				break
	if found:
		_draft += 0.25
		if _draft >= 1.0:
			_draft = 0.0
			boosting_time = maxf(boosting_time, 0.8)
			Audio.play("boost")
			VfxFactory.burst(self, "boost")
	else:
		_draft = maxf(0.0, _draft - 0.5)

# --- Roues ---

func _set_engine(force: float) -> void:
	for w in _wheels:
		var wheel := w as VehicleWheel3D
		if wheel.use_as_traction:
			wheel.engine_force = force

func _set_brake(b: float) -> void:
	for w in _wheels:
		(w as VehicleWheel3D).brake = b

func _set_steering(s: float) -> void:
	for w in _wheels:
		var wheel := w as VehicleWheel3D
		if wheel.use_as_steering:
			wheel.steering = s

func _get_steering() -> float:
	for w in _wheels:
		var wheel := w as VehicleWheel3D
		if wheel.use_as_steering:
			return wheel.steering
	return 0.0

# --- Objets ---

func give_item(item_id: String, charges: int = 1) -> void:
	held_item = item_id
	held_charges = charges
	item_changed.emit(item_id)

func start_roulette(item_id: String) -> void:
	if held_item != "" or pending_item != "":
		return
	pending_item = item_id
	pending_t = 0.9
	Audio.play("roulette")

func use_item() -> void:
	if held_item == "" or pending_item != "" or controls_locked:
		return
	var id := held_item
	held_charges -= 1
	if held_charges <= 0:
		held_item = ""
		held_charges = 0
	item_changed.emit(held_item)
	var sys := get_tree().get_first_node_in_group("item_system")
	if sys and sys.has_method("request_use"):
		sys.call("request_use", self, id)

func add_coin() -> bool:
	if coins >= 10:
		return false
	coins += 1
	Audio.play("coin")
	VfxFactory.burst_colored(self, Color(1.0, 0.85, 0.2))
	return true

func set_shield(on: bool) -> void:
	shield = on
	if _shield_mesh:
		_shield_mesh.visible = on
	if on:
		Audio.play("shield")
		VfxFactory.burst_colored(self, Color(0.3, 0.7, 1.0))

func _blocked_by_defense() -> bool:
	if star_timer > 0.0:
		return true
	if shield:
		set_shield(false)
		Audio.play("shield")
		VfxFactory.burst_colored(self, Color(0.3, 0.7, 1.0))
		return true
	return false

func _lose_coins() -> void:
	coins = maxi(0, coins - 3)

func apply_reverse(dur: float) -> void:
	if _blocked_by_defense():
		return
	reverse_timer = dur
	_lose_coins()
	_hit_wobble()
	Audio.play("hit")
	VfxFactory.burst(self, "reverse")

func apply_shrink(dur: float) -> void:
	if _blocked_by_defense():
		return
	if stats.ignores_size_hazards:
		return
	shrink_timer = dur
	scale = _orig_scale * 0.55
	# Rayon reducteur : le pilote devient un mini-cochon.
	DriverBuilder.build(_driver, "pig")
	_lose_coins()
	_hit_wobble()
	Audio.play("hit")
	VfxFactory.burst(self, "shrink")

func apply_chicken(dur: float) -> void:
	if _blocked_by_defense():
		return
	if stats.is_plow_class:
		return
	chicken_timer = dur
	_lose_coins()
	_hit_wobble()
	Audio.play("chicken")
	VfxFactory.burst(self, "chicken")

func apply_rocket(dur: float) -> void:
	if _blocked_by_defense():
		return
	penguin_timer = dur
	_refresh_driver_model()
	_lose_coins()
	_hit_wobble()
	Audio.play("hit")
	VfxFactory.burst(self, "rocket")

func apply_banana_hit() -> void:
	if _blocked_by_defense():
		return
	if stats.is_plow_class:
		return
	slip_timer = 2.0
	_lose_coins()
	_hit_wobble()
	Audio.play("hit")

func apply_shell_hit(from_pos: Vector3) -> void:
	if _blocked_by_defense():
		return
	_lose_coins()
	apply_knockback(from_pos, 12.0)
	_hit_wobble()
	Audio.play("hit")
	VfxFactory.burst(self, "rocket")

func apply_lightning() -> void:
	if star_timer > 0.0:
		return
	if shield:
		set_shield(false)
		Audio.play("shield")
		return
	shrink_timer = 3.0
	if not stats.ignores_size_hazards:
		scale = _orig_scale * 0.6
	_lose_coins()
	_hit_wobble()
	Audio.play("lightning")
	VfxFactory.burst_colored(self, Color(0.7, 0.5, 1.0))

func apply_star(dur: float) -> void:
	star_timer = dur
	Audio.play("star")
	VfxFactory.burst_colored(self, Color(1.0, 0.9, 0.2))

func apply_knockback(from_pos: Vector3, power: float = 8.0) -> void:
	var dir := global_transform.origin - from_pos
	dir.y = 0.3
	apply_central_impulse(dir.normalized() * power * stats.knockback_multiplier * mass * 0.01)

func _hit_wobble() -> void:
	var mult := stats.knockback_multiplier
	var body: Node3D = get_node_or_null("Body") as Node3D
	if body == null:
		return
	var tw := create_tween()
	if mult > 1.3:
		tw.tween_property(body, "rotation:y", body.rotation.y + TAU, 0.5)
	else:
		tw.tween_property(body, "rotation:z", 0.3 * mult, 0.08)
		tw.tween_property(body, "rotation:z", 0.0, 0.2)

func _refresh_driver_model() -> void:
	if _driver == null:
		return
	# Transform Rocket->pingouin : on reconstruit le pilote (pop comique).
	DriverBuilder.build(_driver, "penguin" if penguin_timer > 0.0 else character_id)
	_driver.scale = Vector3(1.0, 0.8, 1.2) if penguin_timer > 0.0 else Vector3.ONE

func play_surprise() -> void:
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y + 0.6, 0.12)
	tw.tween_property(self, "position:y", position.y, 0.18)

func play_celebration() -> void:
	if _driver:
		var tw := create_tween().set_loops()
		tw.tween_property(_driver, "position:y", 1.4, 0.25)
		tw.tween_property(_driver, "position:y", 0.95, 0.25)

func play_humiliation() -> void:
	if _driver:
		var tw := create_tween().set_loops()
		tw.tween_property(_driver, "rotation:z", 0.4, 0.3)
		tw.tween_property(_driver, "rotation:z", -0.4, 0.3)

# --- Detection zones ---

func _on_detect_area(area: Area3D) -> void:
	if area.is_in_group("checkpoint"):
		var idx := int(area.get_meta("index", 0))
		if idx == 0:
			BoundaryManager.on_start_finish(self)
		else:
			checkpoint_entered.emit(idx)
	elif area.is_in_group("item_box"):
		if held_item == "" and pending_item == "" and area.has_method("try_pickup"):
			var got: String = str(area.call("try_pickup", self))
			if got != "":
				start_roulette(got)
	elif area.is_in_group("coin"):
		if area.has_method("try_collect"):
			area.call("try_collect", self)
	elif area.is_in_group("boost_pad"):
		if _pad_cd <= 0.0:
			_pad_cd = 1.0
			boosting_time = maxf(boosting_time, 1.1)
			Audio.play("pad")
			VfxFactory.burst(self, "boost")
	elif area.is_in_group("boundary_soft"):
		BoundaryManager.apply_soft_zone(self, true, 0.5)
	elif area.is_in_group("drivable_edge"):
		BoundaryManager.set_in_bounds(self, false)

func _on_detect_exit(area: Area3D) -> void:
	if area.is_in_group("boundary_soft"):
		BoundaryManager.apply_soft_zone(self, false)
	elif area.is_in_group("drivable_edge"):
		BoundaryManager.set_in_bounds(self, true)

func _is_server() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

# --- IA ---

func _bot_input() -> Array:
	var next := _bot_target()
	if next == null:
		return [0.0, 0.8, false]
	var local: Vector3 = to_local(next.global_transform.origin)
	var steer := clampf(-local.x / 8.0, -1.0, 1.0)
	var throttle := 0.85
	if absf(local.x) > 10.0:
		throttle = 0.5
	return [steer, throttle, absf(steer) > 0.6]

func _bot_target() -> Node3D:
	var st: Dictionary = BoundaryManager.player_states.get(peer_id, {})
	var want := int(st.get("next_checkpoint", 1))
	var best: Node3D = null
	for n in get_tree().get_nodes_in_group("checkpoint"):
		if n is Node3D and int(n.get_meta("index", -1)) == want:
			best = n
			break
	if best == null and not get_tree().get_nodes_in_group("checkpoint").is_empty():
		best = get_tree().get_nodes_in_group("checkpoint")[0]
	return best
