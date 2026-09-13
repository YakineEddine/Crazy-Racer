class_name CoinPickup
extends Area3D
## Piece Mario-Kart : +1 (max 10), chaque piece +1.5% vitesse max. Respawn 8s.

var respawn_delay: float = 8.0
var _active: bool = true
var _mesh: MeshInstance3D = null
var _t: float = 0.0

static func create() -> CoinPickup:
	var c := CoinPickup.new()
	var col := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.4
	col.shape = sp
	c.add_child(col)
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.55
	cm.height = 0.12
	mi.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.84, 0.1)
	mat.metallic = 0.7
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 0.6
	mi.set_surface_override_material(0, mat)
	mi.position = Vector3(0, 1.0, 0)
	c.add_child(mi)
	c.collision_layer = 1
	c.collision_mask = 0
	c.monitoring = false
	c.monitorable = true
	return c

func _ready() -> void:
	add_to_group("coin")
	_mesh = get_node_or_null("Mesh") as MeshInstance3D

func _process(delta: float) -> void:
	_t += delta
	if _mesh and _active:
		_mesh.rotation.y += delta * 2.5
		_mesh.position.y = 1.0 + sin(_t * 3.0) * 0.12

func try_collect(vehicle: Node) -> bool:
	if not _active:
		return false
	if vehicle.has_method("add_coin") and bool(vehicle.call("add_coin")):
		_active = false
		visible = false
		await get_tree().create_timer(respawn_delay).timeout
		_active = true
		visible = true
		return true
	return false
