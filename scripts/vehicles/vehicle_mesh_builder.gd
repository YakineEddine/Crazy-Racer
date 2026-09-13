class_name VehicleMeshBuilder
extends RefCounted
## Vrais karts low-poly par classe : chassis, siege, volant, aileron, echappements,
## phares, roues (pneu+jante, avant directrices), pseudo + spec 02 ( gabarits ).

static func _mat(c: Color, rough: float = 0.45, metal: float = 0.1, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	return m

static func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rough: float = 0.45, metal: float = 0.1, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.set_surface_override_material(0, _mat(c, rough, metal, emission))
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, metal: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	mi.mesh = cm
	mi.set_surface_override_material(0, _mat(c, 0.5, metal))
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func _ball(parent: Node3D, r: float, pos: Vector3, c: Color, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.set_surface_override_material(0, _mat(c, 0.35, 0.0, emission))
	mi.position = pos
	parent.add_child(mi)
	return mi

static func _class_of(v: Node) -> String:
	var dn: String = str((v.get("stats") as KartStats).display_name)
	if dn.contains("Camion"):
		return "truck"
	if dn.contains("Moto"):
		return "moto"
	if dn.contains("Velo"):
		return "bike"
	if dn.contains("Car"):
		return "car"
	return "kart"

static func build(v: Node) -> void:
	var body := v.get_node("Body") as MeshInstance3D
	var stats: KartStats = v.get("stats")
	var cls := _class_of(v)
	var paint: Color = stats.body_color
	var dark: Color = paint.darkened(0.35)
	var L := 2.4 # longueur chassis
	var W := 1.5 # largeur
	var y := 0.55
	match cls:
		"car":
			L = 2.9
			W = 1.7
		"truck":
			L = 3.4
			W = 2.1
			y = 0.75
		"moto":
			L = 2.1
			W = 0.8
		"bike":
			L = 1.9
			W = 0.6
	# Chassis.
	var cb := BoxMesh.new()
	cb.size = Vector3(W, 0.42, L)
	body.mesh = cb
	body.set_surface_override_material(0, _mat(paint, 0.35, 0.25))
	body.position = Vector3(0, y, 0)
	var front := -L / 2.0
	var rear := L / 2.0
	# Nez + bande deco.
	_box(body, Vector3(W * 0.7, 0.28, 0.7), Vector3(0, 0.1, front + 0.4), dark)
	_box(body, Vector3(0.32, 0.03, L * 0.62), Vector3(0, 0.23, 0), Color(1, 1, 1, 1))
	# Siege + volant.
	_box(body, Vector3(minf(W * 0.55, 0.9), 0.5, 0.7), Vector3(0, 0.45, 0.35), Color(0.08, 0.08, 0.1), 0.7)
	var col := _cyl(body, 0.045, 0.5, Vector3(0, 0.6, -0.3), Color(0.15, 0.15, 0.18), Vector3(0.9, 0, 0))
	col.rotation.x = 0.9
	var wheel := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.outer_radius = 0.2
	tor.inner_radius = 0.16
	wheel.mesh = tor
	wheel.set_surface_override_material(0, _mat(Color(0.1, 0.1, 0.12), 0.6))
	wheel.position = Vector3(0, 0.78, -0.5)
	wheel.rotation.x = -0.5
	body.add_child(wheel)
	if cls == "truck":
		# Cabine + pare-brise + benne.
		_box(body, Vector3(W * 0.92, 0.95, 1.0), Vector3(0, 0.65, front + 0.8), paint)
		_box(body, Vector3(W * 0.8, 0.5, 0.12), Vector3(0, 0.75, front + 0.32), Color(0.1, 0.16, 0.22), 0.2)
		_box(body, Vector3(W, 0.12, 1.8), Vector3(0, 0.35, rear - 1.0), dark)
		_box(body, Vector3(W, 0.55, 0.12), Vector3(0, 0.6, rear - 0.15), dark)
		_box(body, Vector3(0.12, 0.55, 1.8), Vector3(-W / 2.0 + 0.06, 0.6, rear - 1.0), dark)
		_box(body, Vector3(0.12, 0.55, 1.8), Vector3(W / 2.0 - 0.06, 0.6, rear - 1.0), dark)
	elif cls == "moto":
		_box(body, Vector3(0.5, 0.35, 0.9), Vector3(0, 0.35, -0.2), dark) # reservoir
		_box(body, Vector3(0.45, 0.22, 1.0), Vector3(0, 0.3, 0.6), Color(0.08, 0.08, 0.1), 0.7) # selle
		_cyl(body, 0.05, 1.0, Vector3(-0.2, 0.3, front + 0.3), Color(0.7, 0.7, 0.75), Vector3(0.35, 0, 0), 0.8) # fourche
		_cyl(body, 0.05, 1.0, Vector3(0.2, 0.3, front + 0.3), Color(0.7, 0.7, 0.75), Vector3(0.35, 0, 0), 0.8)
		_box(body, Vector3(0.6, 0.08, 0.12), Vector3(0, 0.85, front + 0.15), Color(0.1, 0.1, 0.12)) # guidon
		_box(body, Vector3(0.5, 0.35, 0.06), Vector3(0, 0.75, front + 0.05), Color(0.5, 0.8, 1.0, 0.45)) # bulle
	elif cls == "bike":
		_box(body, Vector3(0.12, 0.12, 1.5), Vector3(0, 0.35, 0), Color(0.9, 0.9, 0.9), 0.4, 0.6) # cadre
		_cyl(body, 0.05, 0.9, Vector3(0, 0.1, front + 0.35), Color(0.85, 0.85, 0.9), Vector3(0.3, 0, 0), 0.6)
		_box(body, Vector3(0.55, 0.07, 0.12), Vector3(0, 0.95, front + 0.2), Color(0.1, 0.1, 0.12)) # cintre
		_box(body, Vector3(0.3, 0.12, 0.35), Vector3(0, 0.62, 0.55), Color(0.4, 0.2, 0.1), 0.7) # selle cuir
	else:
		# Aileron sport (kart/car).
		_box(body, Vector3(0.1, 0.42, 0.5), Vector3(-W / 2.0 + 0.08, 0.4, rear - 0.2), dark)
		_box(body, Vector3(0.1, 0.42, 0.5), Vector3(W / 2.0 - 0.08, 0.4, rear - 0.2), dark)
		_box(body, Vector3(W * 0.95, 0.09, 0.55), Vector3(0, 0.62, rear - 0.2), dark)
	# Echappements + phares + feu arriere.
	_cyl(body, 0.09, 0.5, Vector3(-0.35, 0.05, rear + 0.15), Color(0.75, 0.75, 0.8), Vector3(1.5708, 0, 0), 0.85)
	_cyl(body, 0.09, 0.5, Vector3(0.35, 0.05, rear + 0.15), Color(0.75, 0.75, 0.8), Vector3(1.5708, 0, 0), 0.85)
	_ball(body, 0.12, Vector3(-W * 0.32, 0.15, front - 0.02), Color(1, 0.95, 0.8), 1.5)
	_ball(body, 0.12, Vector3(W * 0.32, 0.15, front - 0.02), Color(1, 0.95, 0.8), 1.5)
	_box(body, Vector3(W * 0.7, 0.12, 0.1), Vector3(0, 0.15, rear + 0.02), Color(1, 0.1, 0.1), 0.4, 0.0, 1.2)
	_build_wheels(v, cls)
	_build_nametag(v)

static func _build_wheels(v: Node, cls: String) -> void:
	var tire_r := 0.35
	var tire_w := 0.32
	if cls == "truck":
		tire_r = 0.45
		tire_w = 0.45
	var narrow := 0.12 if cls == "bike" else (0.18 if cls == "moto" else -1.0)
	for n in ["WheelMeshFL", "WheelMeshFR", "WheelMeshRL", "WheelMeshRR"]:
		var wm := v.get_node_or_null(n) as MeshInstance3D
		if wm == null:
			continue
		for c in wm.get_children():
			c.free()
		if narrow > 0.0:
			var px: float = wm.position.x
			wm.position.x = narrow if px > 0.0 else -narrow
		var tire := MeshInstance3D.new()
		tire.name = "Tire"
		var tm := CylinderMesh.new()
		tm.top_radius = tire_r
		tm.bottom_radius = tire_r
		tm.height = tire_w
		tire.mesh = tm
		tire.set_surface_override_material(0, _mat(Color(0.06, 0.06, 0.07), 0.85))
		tire.rotation.z = 1.5708
		wm.add_child(tire)
		var rim := MeshInstance3D.new()
		rim.name = "Rim"
		var rm := CylinderMesh.new()
		rm.top_radius = tire_r * 0.55
		rm.bottom_radius = tire_r * 0.55
		rm.height = tire_w + 0.02
		rim.mesh = rm
		rim.set_surface_override_material(0, _mat(Color(0.85, 0.85, 0.9), 0.3, 0.8))
		rim.rotation.z = 1.5708
		wm.add_child(rim)

static func _build_nametag(v: Node) -> void:
	var tag := Label3D.new()
	tag.name = "NameTag"
	tag.text = str(v.get("racer_name"))
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.font_size = 96
	tag.pixel_size = 0.01
	tag.outline_size = 16
	tag.outline_modulate = Color(0, 0, 0, 1)
	tag.modulate = Color(1, 1, 1)
	tag.position = Vector3(0, 2.4, 0)
	v.add_child(tag)
