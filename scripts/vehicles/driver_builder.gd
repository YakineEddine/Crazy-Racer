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

## Locomotion reactive (PHYSICS §3), valeurs PROPOSEES a playtester (pas finales).
## Appliquee sur le wrapper "Reactive" interne, jamais sur la racine (qui porte
## les tweens celebration/humiliation + l'echelle shrink/pingouin).
const GAIT_WANTS := ["Run", "Walk"]
const GAIT_MIN_SCALE := 0.5
const GAIT_MAX_SCALE := 1.6
const REACT_LEAN_K := 0.02 ## rotation.x par m/s^2 : + = cabrage (gaz), - = plongee (frein)
const REACT_LEAN_MAX := 0.15
const REACT_YAW_K := 0.35 ## rotation.y par unite de steer (+1 = gauche = -X)

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

## Vrai si le clip joue est une allure (pas un Idle) : cow/horse/zebra ont Run.
static func _is_gait_clip(clip_name: String) -> bool:
	var n := clip_name.to_lower()
	return n.contains("run") or n.contains("walk") or n.contains("gallop") or n.contains("trot")

## Mouvement reactif (PHYSICS §3) : lean cabrage/plongee + regard dans le virage
## + allure cadencee par la vitesse. Decouple du vehicule : ne lit que root + valeurs.
static func apply_motion(root: Node3D, lean_x: float, yaw_y: float, speed_ratio: float) -> void:
	if root == null:
		return
	var wrap := root.get_node_or_null("Reactive") as Node3D
	if wrap:
		wrap.rotation.x = lean_x
		wrap.rotation.y = yaw_y
	if not bool(root.get_meta("has_gait", false)):
		return
	var r := clampf(speed_ratio, 0.0, 1.0)
	for p in root.find_children("*", "AnimationPlayer", true, false):
		(p as AnimationPlayer).speed_scale = lerpf(GAIT_MIN_SCALE, GAIT_MAX_SCALE, r)

static func build(root: Node3D, cid: String) -> void:
	for c in root.get_children():
		c.free()
	# Wrapper interne pour la locomotion reactive : la racine garde position,
	# echelle et tweens (celebration/humiliation), le wrapper prend lean/yaw/allure.
	var wrap := Node3D.new()
	wrap.name = "Reactive"
	root.add_child(wrap)
	root.set_meta("has_gait", false)
	if FARM.has(cid):
		var m := farm_model(cid)
		if m:
			m.position = Vector3(0, -0.15, 0.1)
			wrap.add_child(m)
			# Allure si le FBX en a une (Run pour cow/horse/zebra), sinon Idle (lst[0]).
			var played := ModelFactory.play_anim(m, GAIT_WANTS)
			root.set_meta("has_gait", _is_gait_clip(played))
			return
		# Fallback procedural si le FBX manque.
		capsule(wrap, 0.26, 0.7, Vector3(0, 0.35, 0.1), Color(0.8, 0.7, 0.6))
		ball(wrap, 0.24, Vector3(0, 0.95, 0.05), Color(0.8, 0.7, 0.6))
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
	capsule(wrap, 0.26, 0.7, Vector3(0, 0.35, 0.1), body)
	capsule(wrap, 0.08, 0.45, Vector3(-0.3, 0.55, -0.2), body.darkened(0.1), Vector3(-1.0, 0, 0))
	capsule(wrap, 0.08, 0.45, Vector3(0.3, 0.55, -0.2), body.darkened(0.1), Vector3(-1.0, 0, 0))
	# Casque + visiere.
	ball(wrap, 0.24, Vector3(0, 0.95, 0.05), accent)
	box(wrap, Vector3(0.3, 0.12, 0.1), Vector3(0, 0.95, -0.16), Color(0.05, 0.08, 0.12))
	match cid:
		"crocodile":
			box(wrap, Vector3(0.3, 0.14, 0.35), Vector3(0, 0.86, -0.3), body.darkened(0.15)) # museau
			box(wrap, Vector3(0.16, 0.16, 0.6), Vector3(0, 0.3, 0.55), body.darkened(0.1)) # queue
			ball(wrap, 0.06, Vector3(-0.12, 1.1, -0.05), Color(1, 0.9, 0.1)) # yeux
			ball(wrap, 0.06, Vector3(0.12, 1.1, -0.05), Color(1, 0.9, 0.1))
		"penguin":
			ball(wrap, 0.2, Vector3(0, 0.4, -0.1), Color(1, 1, 1), Vector3(0.85, 1.0, 0.6)) # ventre
			box(wrap, Vector3(0.12, 0.08, 0.16), Vector3(0, 0.9, -0.2), Color(1, 0.6, 0.1)) # bec
			box(wrap, Vector3(0.08, 0.35, 0.15), Vector3(-0.32, 0.4, 0.05), body) # ailerons
			box(wrap, Vector3(0.08, 0.35, 0.15), Vector3(0.32, 0.4, 0.05), body)
		"chicken":
			box(wrap, Vector3(0.1, 0.16, 0.1), Vector3(-0.08, 1.2, 0.05), Color(0.9, 0.15, 0.15)) # crete
			box(wrap, Vector3(0.1, 0.2, 0.1), Vector3(0.08, 1.21, 0.05), Color(0.9, 0.15, 0.15))
			box(wrap, Vector3(0.12, 0.09, 0.16), Vector3(0, 0.88, -0.2), Color(1, 0.6, 0.1)) # bec
			box(wrap, Vector3(0.08, 0.3, 0.08), Vector3(-0.1, 0.5, 0.4), Color(0.9, 0.9, 0.9), Vector3(0.5, 0, 0.3)) # plumes
			box(wrap, Vector3(0.08, 0.3, 0.08), Vector3(0.1, 0.5, 0.4), Color(0.9, 0.9, 0.9), Vector3(0.5, 0, -0.3))
