class_name DriverBuilder
extends RefCounted
## Pilotes : Quaternius CC0 (vache, cochon...) ou low-poly procedural (casque, visiere).
## build() vide le conteneur puis reconstruit (sert aussi au transform Rocket->pingouin).

## Animaux Quaternius : [fichier FBX, echelle] — visage vers -Z (rotation PI).
const FARM := {
	"cow": ["Cow", 0.20], "pig": ["Pig", 0.22], "sheep": ["Sheep", 0.23],
	"horse": ["Horse", 0.16], "llama": ["Llama", 0.18], "pug": ["Pug", 0.38],
	"zebra": ["Zebra", 0.155],
}

static func mat(c: Color, rough: float = 0.6, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	return m

static func box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.set_surface_override_material(0, mat(c))
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func ball(parent: Node3D, r: float, pos: Vector3, c: Color, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.set_surface_override_material(0, mat(c))
	mi.position = pos
	mi.scale = sc
	parent.add_child(mi)
	return mi

static func capsule(parent: Node3D, r: float, h: float, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	mi.mesh = cm
	mi.set_surface_override_material(0, mat(c))
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi

static func farm_model(cid: String) -> Node3D:
	var e: Array = FARM.get(cid, [])
	if e.is_empty():
		return null
	var m := ModelFactory.instance("res://assets/models/farm/%s.fbx" % str(e[0]))
	if m == null:
		return null
	ModelFactory.scale_to(m, float(e[1]))
	m.rotation.y = PI
	ModelFactory.play_anim(m, ["Idle"])
	return m

static func build(root: Node3D, cid: String) -> void:
	for c in root.get_children():
		c.free()
	if FARM.has(cid):
		var m := farm_model(cid)
		if m:
			m.position = Vector3(0, -0.15, 0.1)
			root.add_child(m)
			return
		# Fallback procedural si le FBX manque.
		capsule(root, 0.26, 0.7, Vector3(0, 0.35, 0.1), Color(0.8, 0.7, 0.6))
		ball(root, 0.24, Vector3(0, 0.95, 0.05), Color(0.8, 0.7, 0.6))
		return
	var body := Color(1, 0.8, 0.6)
	var accent := Color(0.2, 0.5, 1.0)
	match cid:
		"crocodile":
			body = Color(0.25, 0.68, 0.28)
			accent = Color(0.95, 0.85, 0.2)
		"penguin":
			body = Color(0.12, 0.12, 0.16)
			accent = Color(1, 1, 1)
		"chicken":
			body = Color(1, 1, 1)
			accent = Color(1, 0.35, 0.2)
	# Torse + bras vers le volant (regard vers -Z).
	capsule(root, 0.26, 0.7, Vector3(0, 0.35, 0.1), body)
	capsule(root, 0.08, 0.45, Vector3(-0.3, 0.55, -0.2), body.darkened(0.1), Vector3(-1.0, 0, 0))
	capsule(root, 0.08, 0.45, Vector3(0.3, 0.55, -0.2), body.darkened(0.1), Vector3(-1.0, 0, 0))
	# Casque + visiere.
	ball(root, 0.24, Vector3(0, 0.95, 0.05), accent)
	box(root, Vector3(0.3, 0.12, 0.1), Vector3(0, 0.95, -0.16), Color(0.05, 0.08, 0.12))
	match cid:
		"crocodile":
			box(root, Vector3(0.3, 0.14, 0.35), Vector3(0, 0.86, -0.3), body.darkened(0.15)) # museau
			box(root, Vector3(0.16, 0.16, 0.6), Vector3(0, 0.3, 0.55), body.darkened(0.1)) # queue
			ball(root, 0.06, Vector3(-0.12, 1.1, -0.05), Color(1, 0.9, 0.1)) # yeux
			ball(root, 0.06, Vector3(0.12, 1.1, -0.05), Color(1, 0.9, 0.1))
		"penguin":
			ball(root, 0.2, Vector3(0, 0.4, -0.1), Color(1, 1, 1), Vector3(0.85, 1.0, 0.6)) # ventre
			box(root, Vector3(0.12, 0.08, 0.16), Vector3(0, 0.9, -0.2), Color(1, 0.6, 0.1)) # bec
			box(root, Vector3(0.08, 0.35, 0.15), Vector3(-0.32, 0.4, 0.05), body) # ailerons
			box(root, Vector3(0.08, 0.35, 0.15), Vector3(0.32, 0.4, 0.05), body)
		"chicken":
			box(root, Vector3(0.1, 0.16, 0.1), Vector3(-0.08, 1.2, 0.05), Color(0.9, 0.15, 0.15)) # crete
			box(root, Vector3(0.1, 0.2, 0.1), Vector3(0.08, 1.21, 0.05), Color(0.9, 0.15, 0.15))
			box(root, Vector3(0.12, 0.09, 0.16), Vector3(0, 0.88, -0.2), Color(1, 0.6, 0.1)) # bec
			box(root, Vector3(0.08, 0.3, 0.08), Vector3(-0.1, 0.5, 0.4), Color(0.9, 0.9, 0.9), Vector3(0.5, 0, 0.3)) # plumes
			box(root, Vector3(0.08, 0.3, 0.08), Vector3(0.1, 0.5, 0.4), Color(0.9, 0.9, 0.9), Vector3(0.5, 0, -0.3))
