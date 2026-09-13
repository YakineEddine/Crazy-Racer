class_name VfxFactory
extends Node
## Helper VFX (06) : spawn GPUParticles3D + fallback CPU via Settings.particle_quality.
## Particules procedurales + poofs comiques (jamais gore). One-shot liberes apres 2s.

enum Quality { LOW, HIGH }

static var particle_quality: int = Quality.HIGH

static func burst(parent: Node, kind: String) -> void:
	_burst_colored(parent, _color_for(kind))

static func burst_colored(parent: Node, col: Color) -> void:
	_burst_colored(parent, col)

static func _color_for(kind: String) -> Color:
	match kind:
		"boost":
			return Color(1.0, 0.7, 0.1)
		"reverse":
			return Color(1.0, 0.2, 0.2)
		"shrink":
			return Color(0.4, 0.6, 1.0)
		"chicken":
			return Color(1.0, 1.0, 1.0)
		"rocket":
			return Color(1.0, 0.5, 0.0)
		"meteor":
			return Color(1.0, 0.3, 0.1)
		"collapse":
			return Color(0.6, 0.5, 0.4)
	return Color(1, 0.9, 0.4)

static func _burst_colored(parent: Node, col: Color) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var tree := parent.get_tree()
	if tree == null or tree.current_scene == null:
		return
	var fx := _make(col)
	if fx == null:
		return
	if parent is Node3D:
		tree.current_scene.add_child(fx)
		fx.global_transform = (parent as Node3D).global_transform.translated_local(Vector3(0, 1.2, 0))
	else:
		parent.add_child(fx)
	if fx is GPUParticles3D or fx is CPUParticles3D:
		fx.emitting = true
	tree.create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(fx):
			fx.queue_free()
	)

static func _make(col: Color) -> Node3D:
	if particle_quality == Quality.LOW:
		var cpu := CPUParticles3D.new()
		cpu.amount = 24
		cpu.lifetime = 0.8
		cpu.one_shot = true
		cpu.explosiveness = 0.9
		cpu.direction = Vector3(0, 1, 0)
		cpu.spread = 45.0
		cpu.initial_velocity_min = 4.0
		cpu.initial_velocity_max = 9.0
		cpu.color = col
		cpu.scale_amount_min = 0.15
		cpu.scale_amount_max = 0.4
		return cpu
	var gpu := GPUParticles3D.new()
	gpu.amount = 48
	gpu.lifetime = 0.8
	gpu.one_shot = true
	gpu.explosiveness = 0.9
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 45.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 9.0
	pm.color = col
	pm.scale_min = 0.15
	pm.scale_max = 0.4
	gpu.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	gpu.draw_pass_1 = quad
	return gpu
