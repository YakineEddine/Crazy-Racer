class_name ItemSystem
extends Node
## 14 objets Mario-Kart-like, pipeline generique off ItemData (02 §5).
## Charges x3, carapaces projectiles, foudre globale, roulette 0.9s cote vehicule.

var items: Dictionary = {} ## { id: ItemData }
var cooldowns: Dictionary = {}

const ITEM_PATHS := [
	"res://assets/resources/reverse_gun.tres",
	"res://assets/resources/shrink_ray.tres",
	"res://assets/resources/chicken_storm.tres",
	"res://assets/resources/banana_boost.tres",
	"res://assets/resources/rocket.tres",
]

## [id, poids, self-target, duree]
const EXTRA_DEFS := [
	["banana", 1.1, false, 0.0],
	["triple_banana", 0.5, false, 0.0],
	["mushroom", 1.1, true, 0.0],
	["triple_mushroom", 0.5, true, 0.0],
	["shell_green", 1.0, false, 0.0],
	["shell_red", 0.8, false, 0.0],
	["shield", 0.7, true, 0.0],
	["star", 0.35, true, 6.0],
	["lightning", 0.3, false, 3.0],
]

const PRETTY := {
	"banana": "Banane", "triple_banana": "Triple Banane",
	"mushroom": "Champignon", "triple_mushroom": "Triple Champi",
	"shell_green": "Carapace Verte", "shell_red": "Carapace Rouge",
	"shield": "Bouclier", "star": "Etoile", "lightning": "Foudre",
}

static func charges_for(item_id: String) -> int:
	if item_id == "triple_banana" or item_id == "triple_mushroom":
		return 3
	return 1

func _ready() -> void:
	add_to_group("item_system")
	for p in ITEM_PATHS:
		var d: ItemData = load(p) as ItemData
		if d:
			items[d.id] = d
	for e in EXTRA_DEFS:
		var id: String = e[0]
		if items.has(id):
			continue
		var nd := ItemData.new()
		nd.id = id
		nd.display_name = str(PRETTY.get(id, id))
		nd.pickup_rarity = float(e[1])
		nd.is_self_target = bool(e[2])
		nd.effect_duration = float(e[3])
		nd.cooldown = 1.0
		items[id] = nd

func roll_item() -> String:
	var total := 0.0
	for id in items:
		total += float((items[id] as ItemData).pickup_rarity)
	var r := randf() * total
	for id in items:
		r -= float((items[id] as ItemData).pickup_rarity)
		if r <= 0.0:
			return str(id)
	return "mushroom"

func _key(v: Node) -> int:
	return int(v.get("peer_id")) if v.get("peer_id") != null else v.get_instance_id()

func request_use(user: Node, item_id: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		_send_use_request.rpc_id(1, user.get_path(), item_id)
		return
	_resolve_use(user, item_id)

@rpc("any_peer", "call_remote", "reliable")
func _send_use_request(user_path: NodePath, item_id: String) -> void:
	if not multiplayer.is_server():
		return
	var user := get_node_or_null(user_path)
	if user == null:
		return
	_resolve_use(user, item_id)

func _resolve_use(user: Node, item_id: String) -> void:
	if not items.has(item_id):
		return
	var data: ItemData = items[item_id]
	var now := Time.get_ticks_msec() / 1000.0
	var k := _key(user)
	if cooldowns.get(k, -99.0) + data.cooldown > now:
		return
	cooldowns[k] = now
	match item_id:
		"shell_green":
			_fire_shell(user, null, false)
		"shell_red":
			_fire_shell(user, _nearest_ahead(user), true)
		"lightning":
			Audio.play("lightning")
			for v in get_tree().get_nodes_in_group("vehicles"):
				if v != user and v.has_method("apply_lightning"):
					v.call("apply_lightning")
		_:
			if data.is_self_target:
				_apply_to(user, item_id, data)
			else:
				var target := _nearest_ahead(user)
				if target == null:
					if user.has_method("give_item"):
						user.call("give_item", item_id, charges_for(item_id))
					return
				_apply_to(target, item_id, data)
	if multiplayer.has_multiplayer_peer():
		_broadcast_use.rpc(user.get_path(), item_id)

func _nearest_ahead(user: Node) -> Node:
	if not (user is Node3D):
		return null
	var best: Node = null
	var best_d := INF
	var up := (user as Node3D).global_transform.origin
	var fwd := -(user as Node3D).global_transform.basis.z
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v == user or not (v is Node3D):
			continue
		var d: Vector3 = (v as Node3D).global_transform.origin - up
		var dist := d.length()
		if d.normalized().dot(fwd) < -0.2:
			dist *= 0.6
		if dist < best_d:
			best_d = dist
			best = v
	return best

func _apply_to(target: Node, item_id: String, data: ItemData) -> void:
	match item_id:
		"reverse_gun":
			target.call("apply_reverse", data.effect_duration)
		"shrink_ray":
			target.call("apply_shrink", data.effect_duration)
		"chicken_storm":
			target.call("apply_chicken", data.effect_duration)
		"banana_boost":
			target.set("boosting_time", 1.2)
			Audio.play("boost")
			VfxFactory.burst(target, "boost")
			_spawn_banana_trail(target)
		"mushroom", "triple_mushroom":
			target.set("boosting_time", maxf(float(target.get("boosting_time")), 1.1))
			Audio.play("boost")
			VfxFactory.burst(target, "boost")
		"banana", "triple_banana":
			_spawn_banana_trail(target)
			Audio.play("pad")
		"shield":
			target.call("set_shield", true)
		"star":
			target.call("apply_star", 6.0)
		"rocket":
			target.call("apply_rocket", 7.0)
		_:
			if data.effect_script_path != "" and ResourceLoader.exists(data.effect_script_path):
				var s: Script = load(data.effect_script_path) as Script
				if s:
					s.call("apply", target, data)

func _fire_shell(user: Node, target: Node, homing: bool) -> void:
	var sh := ShellProjectile.new()
	(user as Node).get_parent().add_child(sh)
	var col := Color(0.2, 0.9, 0.2) if not homing else Color(0.9, 0.15, 0.15)
	sh.setup(user, target, homing, col)
	Audio.play("shell")
	VfxFactory.burst(user, "rocket")

@rpc("authority", "call_local", "reliable")
func _broadcast_use(user_path: NodePath, item_id: String) -> void:
	# En ligne : rejoue le visuel cote clients (effets gameplay deja appliques serveur).
	if multiplayer.is_server():
		return
	var u := get_node_or_null(user_path)
	if u == null or not items.has(item_id):
		return
	var data: ItemData = items[item_id]
	if item_id == "shell_green":
		_fire_shell(u, null, false)
	elif item_id == "shell_red":
		_fire_shell(u, _nearest_ahead(u), true)
	elif item_id == "lightning":
		for v in get_tree().get_nodes_in_group("vehicles"):
			if v != u and v.has_method("apply_lightning"):
				v.call("apply_lightning")
	elif data.is_self_target:
		_apply_to(u, item_id, data)

func _spawn_banana_trail(vehicle: Node) -> void:
	var trail := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 0.5, 4.0)
	col.shape = shape
	trail.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0, 0.2, 4.0)
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.9, 0.2, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.set_surface_override_material(0, mat)
	trail.add_child(mesh)
	vehicle.get_parent().add_child(trail)
	trail.global_transform = (vehicle as Node3D).global_transform.translated_local(Vector3(0, 0.2, 4.0))
	trail.body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group("vehicles") and b != vehicle and b.has_method("apply_banana_hit"):
			b.call("apply_banana_hit")
	)
	await get_tree().create_timer(6.0).timeout
	if is_instance_valid(trail):
		trail.queue_free()
