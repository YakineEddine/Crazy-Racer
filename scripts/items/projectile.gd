class_name ShellProjectile
extends Area3D
## Carapace verte (tout droit) / rouge (a tete chercheuse). Serveur Valide, visuel broadcast.

var speed: float = 30.0
var homing: bool = false
var life: float = 6.0
var _owner: Node = null
var _target: Node = null
var _vel: Vector3 = Vector3.ZERO

func setup(owner: Node, target: Node, is_homing: bool, col: Color) -> void:
	_owner = owner
	_target = target
	homing = is_homing
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.9
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 1.5
	mi.set_surface_override_material(0, m)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = 0.6
	cs.shape = ss
	add_child(cs)
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body)
	var fwd: Vector3 = -(_owner as Node3D).global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.1:
		fwd = Vector3(0, 0, 1)
	_vel = fwd.normalized() * speed
	global_position = (_owner as Node3D).global_position + fwd.normalized() * 2.5 + Vector3(0, 1.0, 0)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0 or not is_instance_valid(_owner):
		queue_free()
		return
	if homing:
		if not is_instance_valid(_target):
			_target = _reacquire()
		if is_instance_valid(_target):
			var want: Vector3 = (_target as Node3D).global_position - global_position
			want.y = 0.0
			if want.length() > 0.5:
				_vel = _vel.lerp(want.normalized() * speed, clampf(3.0 * delta, 0.0, 1.0))
	global_position += _vel * delta
	if global_position.y < -2.0 or global_position.y > 40.0:
		queue_free()

func _reacquire() -> Node:
	var best: Node = null
	var bd := INF
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v == _owner:
			continue
		var d: float = (v as Node3D).global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = v
	return best

func _on_body(b: Node3D) -> void:
	if b == _owner:
		return
	if b.is_in_group("vehicles") and b.has_method("apply_shell_hit"):
		b.call("apply_shell_hit", global_position)
		Audio.play("hit")
		VfxFactory.burst(b, "rocket")
		queue_free()
	elif b is StaticBody3D:
		VfxFactory.burst(self, "collapse")
		queue_free()
