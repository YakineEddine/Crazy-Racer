class_name MapBuilder
extends Node3D
## Construit proceduralement un circuit ovalaire thematique + tout le contrat 03 §2.
## Chaque map .tscn = root Node3D avec ce script + export map_id. Aucun .glb requis pour jouer.
## Invariants : >=1 raccourci risque/recompense, checkpoints 4-5 en ordre, boundaries tall/deep.

@export var map_id: String = "map1_neon"

var map_data: MapData = null
var shortcut_collapsed: bool = false
var _shortcut_meshes: Array = []
var _shortcut_blocker: StaticBody3D = null
var _meteor_active: bool = false
var _meteor_nodes: Array = []
var _env: WorldEnvironment = null
var _rng := RandomNumberGenerator.new()

const MAP_RES := {
	"map1_neon": "res://assets/resources/map1_data.tres",
	"map2_swamp": "res://assets/resources/map2_data.tres",
	"map3_ice": "res://assets/resources/map3_data.tres",
	"map4_farm": "res://assets/resources/map4_data.tres",
}
# Note: map3 path fallback (le .tres s'appelle map3_data.tres).
const MAP_RES_FALLBACK := "res://assets/resources/map3_data.tres"

## Reskin map3_ice : tuiles Kenney (visuel seul, PAS de collision — les boites
## procedurales restent la surface physique). Peinture source le long de Z,
## coins base +X/+Z (mesure sur les vertex, pas suppose).
const KENNEY_DIR := "res://assets/models/tracks_kenney/"
const KENNEY_TILES := {
	"straight_ns": ["roadStraight.glb", 0],
	"straight_ew": ["roadStraight.glb", 90],
	"corner_se": ["roadCornerSmall.glb", 0],
	"corner_en": ["roadCornerSmall.glb", 90],
	"corner_nw": ["roadCornerSmall.glb", 180],
	"corner_ws": ["roadCornerSmall.glb", 270],
	"filler": ["roadCornerSmallSquare.glb", 0],
}
static var _kenney_lib: MeshLibrary = null
static var _kenney_ids := {}

func _ready() -> void:
	add_to_group("maps")
	_rng.randomize()
	_load_data()
	_build_all()

func _load_data() -> void:
	var p: String = MAP_RES.get(map_id, "res://assets/resources/map1_data.tres")
	if not ResourceLoader.exists(p):
		p = "res://assets/resources/map1_data.tres"
	if ResourceLoader.exists(p):
		map_data = load(p) as MapData
	if map_data == null:
		map_data = MapData.new()

func _mat(c: Color, rough: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metallic
	return m

func _build_all() -> void:
	_build_env()
	_build_ground_and_track()
	_build_road_lines()
	_build_walls()
	_build_gantry()
	_build_checkpoints()
	_build_spawns()
	_build_item_boxes()
	_build_boost_pads()
	_build_coins()
	_build_chaos_zones()
	_build_shortcut()
	_build_drivable_area()
	_build_soft_zones()
	_build_dressing()
	# GridMap : stub vide (contrat) sauf map3_ice, pavee de tuiles Kenney (visuel seul).
	var gm := GridMap.new()
	gm.name = "GridMap"
	if map_id == "map3_ice":
		_build_kenney_road(gm)
	else:
		gm.cell_size = Vector3(10, 1, 10)
	add_child(gm)

## Pavage map3_ice : MeshLibrary construite une fois (baked rotations, materiaux
## portes), cellules 1m derivees des memes constantes que is_on_road (pas de
## second systeme, pas de nouveau champ MapData). Orientations bakees : pas de
## pari sur la convention d'orientation du GridMap.
func _build_kenney_road(gm: GridMap) -> void:
	var lib := _kenney_library()
	if lib == null or lib.get_item_list().is_empty():
		push_warning("[MapBuilder] tuiles Kenney indisponibles, map3 sans reskin")
		gm.cell_size = Vector3(10, 1, 10)
		return
	gm.cell_size = Vector3(1, 1, 1)
	gm.mesh_library = lib
	gm.position.y = 0.16 ## dessus des boites (top 0.15), sous les pads
	var straight_ns := int(_kenney_ids.get("straight_ns", 1))
	var straight_ew := int(_kenney_ids.get("straight_ew", 1))
	var corner_se := int(_kenney_ids.get("corner_se", 1))
	var corner_en := int(_kenney_ids.get("corner_en", 1))
	var corner_nw := int(_kenney_ids.get("corner_nw", 1))
	var corner_ws := int(_kenney_ids.get("corner_ws", 1))
	var filler := int(_kenney_ids.get("filler", 1))
	for cx in range(-70, 71):
		for cz in range(-50, 51):
			var c := Vector3(float(cx) + 0.5, 0.0, float(cz) - 0.5)
			var zone := _road_zone(c)
			if zone == 0:
				continue
			var item := filler
			if zone == 1 or zone == 4:
				item = straight_ew ## lignes droites + raccourci : route selon X
			elif zone == 2:
				item = straight_ns ## cotes : route selon Z
			else:
				# Coudes : coins orientes par le masque, remplissage sinon.
				var e := is_on_road(c + Vector3(1, 0, 0))
				var w := is_on_road(c + Vector3(-1, 0, 0))
				var n := is_on_road(c + Vector3(0, 0, -1))
				var s := is_on_road(c + Vector3(0, 0, 1))
				if e and s and not n and not w:
					item = corner_se
				elif e and n and not w and not s:
					item = corner_en
				elif n and w and not e and not s:
					item = corner_nw
				elif w and s and not e and not n:
					item = corner_ws
			gm.set_cell_item(Vector3i(cx, 0, cz), item, 0)

## MeshLibrary partagee (cachee : survit aux rematchs). Rotations bakees dans
## le mesh autour du centre tuile (0.5, 0, -0.5) : toutes les cellules en
## orientation 0, footprint [0,1]x[-1,0] preserve.
static func _kenney_library() -> MeshLibrary:
	if _kenney_lib != null and is_instance_valid(_kenney_lib) and not _kenney_lib.get_item_list().is_empty():
		return _kenney_lib
	var lib := MeshLibrary.new()
	var next_id := 1
	for key in KENNEY_TILES:
		var spec: Array = KENNEY_TILES[key]
		var parts := _tile_parts(str(spec[0]))
		var src: ArrayMesh = parts[0]
		if src == null:
			push_warning("[MapBuilder] tuile illisible : " + str(spec[0]))
			continue
		var baked := _rot_tile_mesh(src, float(spec[1]), parts[1])
		if baked.get_surface_count() == 0:
			push_warning("[MapBuilder] bake vide : " + str(spec[0]))
			continue
		lib.create_item(next_id)
		lib.set_item_name(next_id, str(key))
		lib.set_item_mesh(next_id, baked)
		_kenney_ids[key] = next_id
		next_id += 1
	if lib.get_item_list().is_empty():
		return null
	_kenney_lib = lib
	return lib

## [mesh ArrayMesh, materiaux Array] depuis le .glb (materiaux actifs, pas devines).
static func _tile_parts(file: String) -> Array:
	var ps := load(KENNEY_DIR + file) as PackedScene
	if ps == null:
		return [null, []]
	var n := ps.instantiate() as Node3D
	if n == null:
		return [null, []]
	var mesh: ArrayMesh = null
	var mats: Array = []
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m is ArrayMesh:
			mesh = m as ArrayMesh
			for s in m.get_surface_count():
				mats.append((mi as MeshInstance3D).get_active_material(s))
			break
	n.free()
	return [mesh, mats]

static func _rot_tile_mesh(src: ArrayMesh, deg: float, mats: Array) -> ArrayMesh:
	var out := ArrayMesh.new()
	var b := Basis(Vector3.UP, deg_to_rad(deg))
	var c := Vector3(0.5, 0.0, -0.5)
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		if arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ok_n := arrays[Mesh.ARRAY_NORMAL] != null
		var ok_t := arrays[Mesh.ARRAY_TANGENT] != null
		var norms := PackedVector3Array()
		var tans := PackedFloat32Array()
		if ok_n:
			norms = arrays[Mesh.ARRAY_NORMAL]
		if ok_t:
			tans = arrays[Mesh.ARRAY_TANGENT]
		if norms.size() != verts.size() or (ok_t and tans.size() != verts.size() * 4):
			continue ## garde-fou : attributs incomplets, surface sautee
		var nv := PackedVector3Array()
		nv.resize(verts.size())
		var nn := PackedVector3Array()
		nn.resize(verts.size())
		var nt := PackedFloat32Array()
		nt.resize(tans.size())
		for i in verts.size():
			nv[i] = c + b * (verts[i] - c)
			if ok_n:
				nn[i] = b * norms[i]
			if ok_t:
				var t := Vector3(tans[i * 4], tans[i * 4 + 1], tans[i * 4 + 2])
				var rt := b * t
				nt[i * 4] = rt.x
				nt[i * 4 + 1] = rt.y
				nt[i * 4 + 2] = rt.z
				nt[i * 4 + 3] = tans[i * 4 + 3]
		arrays[Mesh.ARRAY_VERTEX] = nv
		if ok_n:
			arrays[Mesh.ARRAY_NORMAL] = nn
		if ok_t:
			arrays[Mesh.ARRAY_TANGENT] = nt
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat: Material = null
		if s < mats.size() and mats[s] is Material:
			mat = mats[s]
		if mat == null:
			mat = src.surface_get_material(s)
		if mat != null:
			out.surface_set_material(out.get_surface_count() - 1, mat)
	return out

# --- Environnement ---

func _build_env() -> void:
	_env = WorldEnvironment.new()
	var e := Environment.new()
	# Vrai ciel degrade par theme (ProceduralSkyMaterial).
	var sky := Sky.new()
	var smat := ProceduralSkyMaterial.new()
	match map_id:
		"map1_neon":
			smat.sky_top_color = Color(0.01, 0.02, 0.08)
			smat.sky_horizon_color = Color(0.35, 0.08, 0.35)
			smat.ground_bottom_color = Color(0.01, 0.01, 0.03)
			smat.ground_horizon_color = Color(0.15, 0.05, 0.2)
		"map2_swamp":
			smat.sky_top_color = Color(0.1, 0.3, 0.25)
			smat.sky_horizon_color = Color(0.55, 0.7, 0.4)
			smat.ground_bottom_color = Color(0.03, 0.08, 0.05)
			smat.ground_horizon_color = Color(0.2, 0.3, 0.15)
		"map3_ice":
			smat.sky_top_color = Color(0.25, 0.5, 0.85)
			smat.sky_horizon_color = Color(0.75, 0.88, 1.0)
			smat.ground_bottom_color = Color(0.5, 0.6, 0.7)
			smat.ground_horizon_color = Color(0.8, 0.9, 1.0)
		_:
			smat.sky_top_color = Color(0.25, 0.5, 0.9)
			smat.sky_horizon_color = Color(0.7, 0.85, 0.95)
			smat.ground_bottom_color = Color(0.2, 0.25, 0.12)
			smat.ground_horizon_color = Color(0.5, 0.6, 0.35)
	sky.sky_material = smat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.7)
	e.ambient_light_energy = 0.7
	if map_id == "map1_neon":
		e.glow_enabled = true
		e.fog_enabled = true
		e.fog_light_color = Color(1, 0.18, 0.53, 1)
		e.fog_density = 0.008
	elif map_id == "map3_ice":
		e.ambient_light_color = Color(0.8, 0.9, 1.0)
	elif map_id == "map2_swamp":
		e.fog_enabled = true
		e.fog_light_color = Color(0.4, 0.55, 0.35, 1)
		e.fog_density = 0.012
	_env.environment = e
	add_child(_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1 if map_id != "map1_neon" else 0.5
	sun.light_color = Color(1, 0.75, 0.6) if map_id == "map1_neon" else Color(1, 1, 1)
	sun.shadow_enabled = true
	add_child(sun)
	if map_id == "map1_neon":
		# Lune neon.
		var moon := DirectionalLight3D.new()
		moon.rotation_degrees = Vector3(-30, 150, 0)
		moon.light_color = Color(0.4, 0.7, 1.0)
		moon.light_energy = 0.5
		add_child(moon)

func set_gravity_visual(on: bool) -> void:
	# VFX gravity flip (06 §3) : teinte d'ambiance.
	if _env and _env.environment:
		_env.environment.ambient_light_color = Color(0.8, 0.5, 1.0) if on else Color(0.6, 0.6, 0.7)

# --- Piste : ovale 120x80, largeur 12 ---

func _road_piece(pos: Vector3, size: Vector3, col: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Road"
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.set_surface_override_material(0, _mat(col, 0.9))
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = pos
	add_child(body)
	return body

func _build_ground_and_track() -> void:
	# Sol infini visuel.
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var gmi := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(300, 1, 300)
	gmi.mesh = gm
	gmi.set_surface_override_material(0, _mat(map_data.theme_color_ground))
	ground.add_child(gmi)
	var gcs := CollisionShape3D.new()
	var gs := BoxShape3D.new()
	gs.size = Vector3(300, 1, 300)
	gcs.shape = gs
	ground.add_child(gcs)
	ground.position = Vector3(0, -0.6, 0)
	add_child(ground)
	# Anneau : 2 lignes droites + 2 virages (boites).
	var tc: Color = map_data.theme_color_track
	var y := 0.05
	_road_piece(Vector3(0, y, -40), Vector3(120, 0.2, 12), tc) ## sud (start)
	_road_piece(Vector3(0, y, 40), Vector3(120, 0.2, 12), tc) ## nord
	_road_piece(Vector3(-60, y, 0), Vector3(12, 0.2, 68), tc) ## ouest
	_road_piece(Vector3(60, y, 0), Vector3(12, 0.2, 68), tc) ## est
	# Coins arrondis visuels.
	for c in [Vector3(-60, y, -40), Vector3(60, y, -40), Vector3(-60, y, 40), Vector3(60, y, 40)]:
		_road_piece(c, Vector3(14, 0.2, 14), tc.lightened(0.1))

func is_on_road(p: Vector3) -> bool:
	# Anneau + raccourci central. Tout le reste = offroad (ralenti).
	return _road_zone(p) != 0

## Zone de piste : 0 hors-piste, 1 ligne droite (route selon X), 2 cote (selon Z),
## 3 coude (les deux bandes a la fois), 4 raccourci. Memes constantes que
## l'ancien test direct (semantique identique, verifiee en jeu).
func _road_zone(p: Vector3) -> int:
	var on_straight := absf(p.x) <= 67.0 and ((p.z >= -46.5 and p.z <= -33.5) or (p.z >= 33.5 and p.z <= 46.5))
	var on_side := absf(p.z) <= 46.5 and ((p.x >= 53.5 and p.x <= 66.5) or (p.x >= -66.5 and p.x <= -53.5))
	var on_shortcut := absf(p.z) <= 4.5 and absf(p.x) <= 51.0
	if on_straight and on_side:
		return 3
	if on_straight:
		return 1
	if on_side:
		return 2
	if on_shortcut:
		return 4
	return 0

func _build_road_lines() -> void:
	if map_id == "map3_ice":
		return ## marquages portes par les tuiles (pointilles clipperaient a y 0.15..0.19 vs 0.18)
	# Pointilles centraux facon Mario Kart.
	var mat := _mat(Color(1, 1, 1, 0.85), 0.6)
	for x in range(-56, 61, 8):
		for z in [-40.0, 40.0]:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(2.2, 0.04, 0.35)
			mi.mesh = bm
			mi.set_surface_override_material(0, mat)
			mi.position = Vector3(float(x), 0.17, z)
			add_child(mi)

func _build_gantry() -> void:
	# Portique de depart + banniere aux couleurs du theme.
	var col: Color = map_data.theme_color_wall
	for x in [-7.5, 7.5]:
		var pil := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.8, 6.0, 0.8)
		pil.mesh = pm
		pil.set_surface_override_material(0, _mat(col.darkened(0.2), 0.5))
		pil.position = Vector3(float(x), 3.0, -40.0)
		add_child(pil)
	var beam := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(16.0, 1.2, 1.0)
	beam.mesh = bm
	var bmat := _mat(col, 0.4)
	beam.set_surface_override_material(0, bmat)
	beam.position = Vector3(0, 6.2, -40.0)
	add_child(beam)

func _build_boost_pads() -> void:
	for pos in [Vector3(25, 0, -40), Vector3(-25, 0, 40)]:
		var a := Area3D.new()
		a.add_to_group("boost_pad")
		a.collision_layer = 1
		a.collision_mask = 0
		a.monitoring = false
		a.monitorable = true
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(4.0, 2.0, 4.0)
		cs.shape = bs
		a.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(4.0, 0.15, 4.0)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.9, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.9, 1.0)
		mat.emission_energy_multiplier = 2.0
		mi.set_surface_override_material(0, mat)
		mi.position = Vector3(0, 0.15, 0)
		a.add_child(mi)
		a.position = pos
		add_child(a)

func _build_coins() -> void:
	var spots: Array = []
	for x in range(-40, 41, 8):
		spots.append(Vector3(float(x), 0, -40))
		spots.append(Vector3(float(x), 0, 40))
	for x in range(-30, 31, 10):
		spots.append(Vector3(float(x), 0, 0))
	for s in spots:
		var c := CoinPickup.create()
		c.position = s
		add_child(c)

func _wall_run(pos: Vector3, size: Vector3, col: Color) -> void:
	var b := StaticBody3D.new()
	b.add_to_group("boundary_wall")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.set_surface_override_material(0, _mat(col, 0.6, 0.3 if map_id == "map1_neon" else 0.0))
	b.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	b.position = pos
	add_child(b)

func _build_walls() -> void:
	# Murs hauts/profonds : contiennent meme les extremes chaos (03 §5 + 07 §7.6.4).
	var wc: Color = map_data.theme_color_wall
	var h := 4.0
	# Exterieur.
	_wall_run(Vector3(0, h / 2.0, -49), Vector3(140, h, 1), wc)
	_wall_run(Vector3(0, h / 2.0, 49), Vector3(140, h, 1), wc)
	_wall_run(Vector3(-69, h / 2.0, 0), Vector3(1, h, 100), wc)
	_wall_run(Vector3(69, h / 2.0, 0), Vector3(1, h, 100), wc)
	# Interieur (ilot central) : empeche de couper tout droit.
	_wall_run(Vector3(0, h / 2.0, -31), Vector3(108, h, 1), wc.darkened(0.2))
	_wall_run(Vector3(0, h / 2.0, 31), Vector3(108, h, 1), wc.darkened(0.2))
	_wall_run(Vector3(-51, h / 2.0, 0), Vector3(1, h, 64), wc.darkened(0.2))
	_wall_run(Vector3(51, h / 2.0, 0), Vector3(1, h, 64), wc.darkened(0.2))

func _mk_checkpoint(pos: Vector3, index: int, w: float = 12.0) -> void:
	var a := Area3D.new()
	a.add_to_group("checkpoint")
	a.set_meta("index", index)
	a.name = "StartFinishLine" if index == 0 else "Checkpoint%d" % index
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, 4, 6)
	cs.shape = bs
	a.add_child(cs)
	# Visuel : arche.
	var arch := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 0.4, 0.6)
	arch.mesh = bm
	var c := Color(1, 0.88, 0.2) if index == 0 else Color(0.3, 1, 0.5)
	arch.set_surface_override_material(0, _mat(c, 0.4, 0.6))
	arch.position = Vector3(0, 3.2, 0)
	a.add_child(arch)
	for x in [-w / 2.0, w / 2.0]:
		var pillar := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.5, 3.2, 0.5)
		pillar.mesh = pm
		pillar.set_surface_override_material(0, _mat(c, 0.5))
		pillar.position = Vector3(x, 1.6, 0)
		a.add_child(pillar)
	a.position = pos
	add_child(a)
	# Detection vehicule : chaque vehicule a son Area detector qui capte ces zones.
	a.monitoring = true
	a.body_entered.connect(_on_cp_body.bind(index))

func _on_cp_body(_b: Node3D, _index: int) -> void:
	pass ## la vraie detection se fait via l'Area du vehicule (vehicle_controller._on_detect_area)

func _build_checkpoints() -> void:
	# 4-5 selon map, ordre strict (03 §4).
	match map_id:
		"map2_swamp":
			_mk_checkpoint(Vector3(0, 1.5, -40), 0) ## start/finish
			_mk_checkpoint(Vector3(-60, 1.5, -20), 1) ## pont 1
			_mk_checkpoint(Vector3(-60, 1.5, 20), 2) ## pont 2
			_mk_checkpoint(Vector3(0, 1.5, 40), 3) ## sommet
			_mk_checkpoint(Vector3(60, 1.5, 0), 4, 6.0) ## descente (virage est)
		_:
			_mk_checkpoint(Vector3(0, 1.5, -40), 0)
			_mk_checkpoint(Vector3(-60, 1.5, 0), 1, 6.0)
			_mk_checkpoint(Vector3(0, 1.5, 40), 2)
			_mk_checkpoint(Vector3(60, 1.5, 0), 3, 6.0)

func _build_spawns() -> void:
	# Grille 8x2 derriere la ligne (sud, face au nord = -Z ? on roule vers +X ; orientation simple).
	for i in 16:
		var m := Marker3D.new()
		m.add_to_group("spawn_point")
		m.name = "Spawn%02d" % i
		var row: int = int(i / 8)
		var col: int = i % 8
		m.position = Vector3(-14.0 + col * 4.0, 0.6, -40.0 + 4.0 + row * 4.0)
		m.rotation_degrees = Vector3(0, 90, 0)
		add_child(m)

func _build_item_boxes() -> void:
	if GameManager.mode == "tt":
		return ## contre-la-montre : pas de boites (pieces et pads conserves)
	var spots := [
		Vector3(-30, 0, -40), Vector3(30, 0, -40),
		Vector3(-60, 0, -10), Vector3(-60, 0, 15),
		Vector3(-20, 0, 40), Vector3(25, 0, 40),
		Vector3(60, 0, -12), Vector3(60, 0, 12),
	]
	var packed: PackedScene = load("res://scenes/items/item_box.tscn") as PackedScene
	for i in spots.size():
		var mk := Marker3D.new()
		mk.add_to_group("item_box_spawn")
		mk.position = spots[i]
		add_child(mk)
		if packed:
			var b := packed.instantiate() as Area3D
			b.position = spots[i]
			add_child(b)

func _build_chaos_zones() -> void:
	var zones := [Vector3(-30, 0, -40), Vector3(30, 0, 40), Vector3(0, 0, 40), Vector3(-60, 0, 0)]
	for i in zones.size():
		var z := Marker3D.new()
		z.add_to_group("chaos_zone")
		z.name = "ChaosEventZone%d" % i
		z.position = zones[i]
		add_child(z)

func _build_shortcut() -> void:
	# Raccourci central avec risque, thematique par map (03 §3).
	var mid := Vector3(0, 0.6, 0)
	var zone := Area3D.new()
	zone.add_to_group("shortcut_zone")
	zone.name = "ShortcutZone"
	var zc := CollisionShape3D.new()
	var zs := BoxShape3D.new()
	zs.size = Vector3(100, 3, 8)
	zc.shape = zs
	zone.add_child(zc)
	zone.position = mid
	add_child(zone)
	# Visuel pont/route central.
	var desc := "pont"
	var col := Color(0.5, 0.5, 0.6)
	match map_id:
		"map1_neon": col = Color(0.2, 0.9, 1.0)
		"map2_swamp": col = Color(0.45, 0.3, 0.15)
		"map3_ice":
			col = Color(0.8, 0.92, 1.0)
			zone.add_to_group("thin_ice")
		"map4_farm": col = Color(0.85, 0.7, 0.3)
	var bridge := _road_piece(Vector3(0, 0.4, 0), Vector3(100, 0.2, 6), col)
	bridge.name = "ShortcutBridge"
	_shortcut_meshes.append(bridge)
	# Bloqueur active quand effondre (collision swap 03 §3.1).
	_shortcut_blocker = StaticBody3D.new()
	_shortcut_blocker.name = "ShortcutBlocker"
	var bc := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6, 4, 8)
	bc.shape = bs
	_shortcut_blocker.add_child(bc)
	var bm := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(6, 4, 8)
	bm.mesh = bx
	bm.set_surface_override_material(0, _mat(Color(1, 0.3, 0.1), 0.7))
	_shortcut_blocker.add_child(bm)
	_shortcut_blocker.position = Vector3(0, 1.5, 0)
	_shortcut_blocker.visible = false
	_shortcut_blocker.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	add_child(_shortcut_blocker)
	_set_blocker_active(false)
	# Map3 : lac basse friction.
	if map_id == "map3_ice":
		var pm := PhysicsMaterial.new()
		pm.friction = 0.15
		pm.rough = false
		bridge.physics_material_override = pm

func _set_blocker_active(on: bool) -> void:
	if _shortcut_blocker == null:
		return
	_shortcut_blocker.visible = on
	_shortcut_blocker.get_child(0).set_deferred("disabled", not on)

func set_shortcut_collapsed(on: bool) -> void:
	shortcut_collapsed = on
	for m in _shortcut_meshes:
		if is_instance_valid(m):
			# Etat "casse" : on enfonce + teinte sombre.
			m.position.y = 0.4 if not on else -1.2
	_set_blocker_active(on)
	if on:
		VfxFactory.burst(self, "collapse")

func _build_drivable_area() -> void:
	# Volume conduisible : sortie = timer off-track (BoundaryManager).
	var a := Area3D.new()
	a.name = "DrivableArea"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(170, 60, 130)
	cs.shape = bs
	a.add_child(cs)
	a.position = Vector3(0, 20, 0)
	add_child(a)
	a.body_exited.connect(func(b: Node3D) -> void:
		if b.is_in_group("vehicles"):
			BoundaryManager.set_in_bounds(b, false)
	)
	a.body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group("vehicles"):
			BoundaryManager.set_in_bounds(b, true)
	)

func _build_soft_zones() -> void:
	# Zones douces thematiques : bank de neige / ballots / bacs a sable (vitesse *0.5).
	var spots: Array = []
	var col := Color(1, 1, 1, 0.5)
	match map_id:
		"map3_ice":
			spots = [Vector3(-40, 0, -40), Vector3(40, 0, 40)]
			col = Color(0.9, 0.95, 1, 0.5)
		"map4_farm":
			spots = [Vector3(0, 0, 0)]
			col = Color(0.9, 0.8, 0.4, 0.5)
		"map2_swamp":
			spots = [Vector3(-20, 0, 40)]
			col = Color(0.3, 0.4, 0.2, 0.5)
		_:
			spots = [Vector3(20, 0, -40)]
			col = Color(0.4, 0.4, 0.5, 0.5)
	for s in spots:
		var a := Area3D.new()
		a.add_to_group("boundary_soft")
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(10, 3, 10)
		cs.shape = bs
		a.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(10, 0.3, 10)
		mi.mesh = bm
		var mt := StandardMaterial3D.new()
		mt.albedo_color = col
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.set_surface_override_material(0, mt)
		a.add_child(mi)
		a.position = s
		add_child(a)
		a.body_entered.connect(func(b: Node3D) -> void:
			if b.is_in_group("vehicles"):
				BoundaryManager.apply_soft_zone(b, true, 0.5)
				VfxFactory.burst(b, "collapse")
		)
		a.body_exited.connect(func(b: Node3D) -> void:
			if b.is_in_group("vehicles"):
				BoundaryManager.apply_soft_zone(b, false)
		)

func _build_dressing() -> void:
	# Habillage dense par theme (07) : ville neon / marais / banquise / ferme.
	match map_id:
		"map1_neon":
			_dress_neon()
		"map2_swamp":
			_dress_swamp()
		"map3_ice":
			_dress_ice()
		_:
			_dress_farm()

var _windmill: Node3D = null
var _dino_active: bool = false

func _tower(pos: Vector3, w: float, h: float, d: float, col: Color, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	mi.mesh = bm
	var m := _mat(col, 0.7)
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	mi.set_surface_override_material(0, m)
	mi.position = pos
	add_child(mi)
	return mi

func _dress_neon() -> void:
	# Gratte-ciel sombres + bandes neon + lampadaires + panneaux.
	var neons := [Color(1, 0.18, 0.53), Color(0.15, 0.9, 1), Color(1, 0.88, 0.2), Color(0.6, 0.3, 1)]
	for i in 26:
		var ang := TAU * float(i) / 26.0
		var h: float = _rng.randf_range(8.0, 26.0)
		var px := cos(ang) * _rng.randf_range(88.0, 110.0)
		var pz := sin(ang) * _rng.randf_range(66.0, 84.0)
		_tower(Vector3(px, h / 2.0 - 0.5, pz), _rng.randf_range(5, 9), h, _rng.randf_range(5, 9), Color(0.05, 0.06, 0.12))
		# Bandeau neon au sommet.
		_tower(Vector3(px, h - 0.8, pz), 5.5, 0.5, 0.3, neons[i % neons.size()], 2.5)
	# Lampadaires le long des lignes droites.
	for x in range(-56, 57, 14):
		for z in [-49.5, 49.5]:
			_tower(Vector3(float(x), 2.5, z), 0.3, 5.0, 0.3, Color(0.1, 0.1, 0.15))
			_tower(Vector3(float(x), 5.1, z), 1.2, 0.4, 1.2, Color(0.4, 0.9, 1.0), 3.0)
	# Arche d'entree lumineuse au nord.
	_tower(Vector3(-8, 4, 40), 1.0, 8.0, 1.0, Color(1, 0.18, 0.53), 2.0)
	_tower(Vector3(8, 4, 40), 1.0, 8.0, 1.0, Color(0.15, 0.9, 1.0), 2.0)
	_tower(Vector3(0, 8.2, 40), 17.0, 1.0, 1.0, Color(1, 0.88, 0.2), 2.0)
	# Parking central : vraies voitures (Quaternius CC0).
	_place_model("res://assets/models/cars/Cop.fbx", Vector3(15, 0, 14), 1.0, 1.5708, [])
	_place_model("res://assets/models/cars/NormalCar1.fbx", Vector3(22, 0, 14), 1.0, 1.5708, [])
	_place_model("res://assets/models/cars/NormalCar2.fbx", Vector3(29, 0, 14), 1.0, 1.5708, [])
	_place_model("res://assets/models/cars/SportsCar.fbx", Vector3(22, 0, 21), 1.0, -1.5708, [])

func _tree(pos: Vector3, trunk_h: float, leaf_c: Color, leaf_r: float) -> void:
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.25
	tm.bottom_radius = 0.4
	tm.height = trunk_h
	trunk.mesh = tm
	trunk.set_surface_override_material(0, _mat(Color(0.3, 0.2, 0.12), 0.9))
	trunk.position = pos + Vector3(0, trunk_h / 2.0, 0)
	add_child(trunk)
	for o in [Vector3(0, trunk_h + leaf_r * 0.5, 0), Vector3(leaf_r * 0.5, trunk_h, 0), Vector3(-leaf_r * 0.5, trunk_h, 0)]:
		var leaf := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = leaf_r
		sm.height = leaf_r * 1.6
		leaf.mesh = sm
		leaf.set_surface_override_material(0, _mat(leaf_c, 0.85))
		leaf.position = pos + o
		add_child(leaf)

func _dress_swamp() -> void:
	# Eau centrale + nénuphars + jungle dense + lianes-ponts.
	var water := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(96, 0.1, 56)
	water.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.1, 0.35, 0.25, 0.85)
	wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wmat.roughness = 0.15
	wmat.metallic = 0.4
	water.set_surface_override_material(0, wmat)
	water.position = Vector3(0, -0.25, 0)
	add_child(water)
	for i in 14:
		var a := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = _rng.randf_range(0.5, 1.1)
		cm.bottom_radius = cm.top_radius
		cm.height = 0.06
		a.mesh = cm
		a.set_surface_override_material(0, _mat(Color(0.25, 0.6, 0.25), 0.8))
		a.position = Vector3(_rng.randf_range(-44, 44), -0.18, _rng.randf_range(-24, 24))
		add_child(a)
	var leaf_cols := [Color(0.08, 0.35, 0.12), Color(0.12, 0.45, 0.16), Color(0.2, 0.5, 0.18)]
	for i in 40:
		var ang := TAU * float(i) / 40.0
		var px := cos(ang) * _rng.randf_range(76.0, 100.0)
		var pz := sin(ang) * _rng.randf_range(58.0, 76.0)
		_tree(Vector3(px, 0, pz), _rng.randf_range(2.5, 5.0), leaf_cols[i % leaf_cols.size()], _rng.randf_range(1.4, 2.6))
	# Huttes sur pilotis au centre (sous le pont).
	for x in [-20.0, 0.0, 20.0]:
		_tower(Vector3(x, 0.8, 12), 4.0, 0.4, 4.0, Color(0.35, 0.25, 0.15))
		_tower(Vector3(x, 2.6, 12), 3.4, 3.0, 3.0, Color(0.45, 0.32, 0.18))
		_tower(Vector3(x, 4.6, 12), 4.2, 1.2, 4.2, Color(0.25, 0.4, 0.15))
	# Geants du marais (vrais modeles animes).
	_place_model("res://assets/models/dino/Trex.fbx", Vector3(30, 0, -12), 0.28, 2.2, ["Idle"])
	_place_model("res://assets/models/dino/Apatosaurus.fbx", Vector3(-24, 0, 16), 0.30, -0.7, ["Idle", "Walk"])
	_place_model("res://assets/models/dino/Parasaurolophus.fbx", Vector3(5, 0, -18), 0.35, 0.4, ["Idle"])

func _dress_ice() -> void:
	# Pics de glace translucides + igloos + aurore boreale.
	for i in 22:
		var ang := TAU * float(i) / 22.0
		var px := cos(ang) * _rng.randf_range(80.0, 105.0)
		var pz := sin(ang) * _rng.randf_range(60.0, 80.0)
		var h: float = _rng.randf_range(3.0, 9.0)
		var spike := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.05
		cm.bottom_radius = _rng.randf_range(0.8, 1.6)
		cm.height = h
		spike.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.7, 0.88, 1.0, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.1
		spike.set_surface_override_material(0, m)
		spike.position = Vector3(px, h / 2.0 - 0.5, pz)
		add_child(spike)
	for pos in [Vector3(-30, 0, 18), Vector3(28, 0, -16), Vector3(10, 0, 20)]:
		var ig := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 3.0
		sm.height = 3.2
		ig.mesh = sm
		ig.set_surface_override_material(0, _mat(Color(0.92, 0.96, 1.0), 0.5))
		ig.position = pos + Vector3(0, 0.4, 0)
		add_child(ig)
		_tower(pos + Vector3(0, 0.7, -2.6), 1.4, 1.4, 0.6, Color(0.1, 0.12, 0.18))
	# Aurore : grand voile vert translucide.
	var aur := MeshInstance3D.new()
	var ab := BoxMesh.new()
	ab.size = Vector3(180, 14, 6)
	aur.mesh = ab
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.2, 1.0, 0.5, 0.16)
	amat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aur.set_surface_override_material(0, amat)
	aur.position = Vector3(0, 42, -60)
	aur.rotation.x = 0.25
	add_child(aur)

func _dress_farm() -> void:
	# Grange + silo + moulin (helice animee) + clotures + bottes + champ laboure.
	_tower(Vector3(-40, 3, 58), 14.0, 6.0, 10.0, Color(0.65, 0.15, 0.12)) # grange
	_tower(Vector3(-40, 7.2, 58), 15.0, 2.5, 11.0, Color(0.5, 0.1, 0.1))
	_tower(Vector3(-40, 2.2, 52.6), 5.0, 4.0, 0.4, Color(0.9, 0.9, 0.9)) # porte
	_tower(Vector3(-24, 5, 58), 5.0, 10.0, 5.0, Color(0.7, 0.72, 0.75)) # silo
	# Moulin.
	_tower(Vector3(35, 5, 55), 1.2, 10.0, 1.2, Color(0.8, 0.8, 0.82))
	var rotor := Node3D.new()
	rotor.name = "WindmillRotor"
	rotor.position = Vector3(35, 10.5, 54.2)
	add_child(rotor)
	_windmill = rotor
	for k in 4:
		var blade := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.5, 5.0, 0.12)
		blade.mesh = bb
		blade.set_surface_override_material(0, _mat(Color(0.9, 0.9, 0.92), 0.5))
		blade.position = Vector3(0, 2.5, 0)
		var pivot := Node3D.new()
		pivot.rotation.z = TAU * float(k) / 4.0
		pivot.add_child(blade)
		rotor.add_child(pivot)
	# Clotures le long des lignes droites.
	for x in range(-60, 61, 6):
		for z in [-49.5, 49.5]:
			_tower(Vector3(float(x), 0.6, z), 0.25, 1.2, 0.25, Color(0.5, 0.35, 0.2))
	for z in [-49.5, 49.5]:
		_tower(Vector3(0, 0.9, z), 124.0, 0.15, 0.15, Color(0.55, 0.4, 0.22))
	# Bottes de foin.
	for pos in [Vector3(-20, 0, -20), Vector3(15, 0, 22), Vector3(40, 0, -10), Vector3(-45, 0, 10)]:
		var hay := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 1.1
		hm.bottom_radius = 1.1
		hm.height = 1.6
		hay.mesh = hm
		hay.set_surface_override_material(0, _mat(Color(0.9, 0.75, 0.3), 0.9))
		hay.rotation.z = 1.5708
		hay.position = pos + Vector3(0, 1.1, 0)
		add_child(hay)
	# Rangs de ble au centre.
	for ix in range(-44, 45, 4):
		for iz in range(-22, 23, 4):
			if absf(float(iz)) < 5.0:
				continue # laisse le raccourci libre
			var crop := MeshInstance3D.new()
			var qb := BoxMesh.new()
			qb.size = Vector3(0.7, _rng.randf_range(0.7, 1.2), 0.7)
			crop.mesh = qb
			crop.set_surface_override_material(0, _mat(Color(0.85, 0.7, 0.3), 0.9))
			crop.position = Vector3(float(ix), 0.4, float(iz))
			add_child(crop)
	# Betail au pre (vrais modeles animes).
	_place_model("res://assets/models/farm/Cow.fbx", Vector3(10, 0, 14), 0.30, 0.6, ["Idle", "Eat"])
	_place_model("res://assets/models/farm/Cow.fbx", Vector3(-18, 0, -15), 0.28, 2.8, ["Idle"])
	_place_model("res://assets/models/farm/Sheep.fbx", Vector3(5, 0, -16), 0.32, 1.2, ["Idle"])
	_place_model("res://assets/models/farm/Sheep.fbx", Vector3(-8, 0, 18), 0.30, -0.9, ["Idle"])
	_place_model("res://assets/models/farm/Pig.fbx", Vector3(32, 0, 12), 0.30, 2.0, ["Idle"])

func _process(_delta: float) -> void:
	# Moulin + pulsation des pads (le reste est statique).
	if is_instance_valid(_windmill):
		_windmill.rotation.z += _delta * 0.8

# --- Stampede de dinos (event chaos) : traversent les lignes droites ---

func start_dino_stampede(duration: float) -> void:
	_dino_active = true
	_dino_loop(duration)

func stop_dino_stampede() -> void:
	_dino_active = false

func _dino_loop(duration: float) -> void:
	await get_tree().create_timer(0.5).timeout
	var t := 0.0
	while _dino_active and t < duration:
		_spawn_runner()
		t += 3.0
		await get_tree().create_timer(3.0).timeout

func _spawn_runner() -> void:
	var kinds := [["Triceratops", 0.35], ["Velociraptor", 0.42], ["Stegosaurus", 0.30]]
	var pick: Array = kinds[_rng.randi() % kinds.size()]
	var m := ModelFactory.instance("res://assets/models/dino/%s.fbx" % str(pick[0]))
	if m == null:
		return
	ModelFactory.scale_to(m, float(pick[1]))
	var lane: float = [-40.0, 40.0][_rng.randi() % 2]
	var dir := 1.0 if _rng.randf() < 0.5 else -1.0
	add_child(m)
	m.position = Vector3(-85.0 * dir, 0, lane)
	m.rotation.y = atan2(dir, 0.0)
	ModelFactory.play_anim(m, ["Run", "Walk"])
	VfxFactory.burst(m, "collapse")
	var hit := Area3D.new()
	hit.collision_layer = 0
	hit.collision_mask = 1
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = 2.4
	cs.shape = ss
	cs.position = Vector3(0, 1.6, 0)
	hit.add_child(cs)
	m.add_child(hit)
	hit.body_entered.connect(func(b: Node3D) -> void:
		if b.is_in_group("vehicles") and b.has_method("apply_shell_hit"):
			b.call("apply_shell_hit", m.global_position)
			Audio.play("hit")
			hit.set_deferred("monitoring", false)
			await get_tree().create_timer(1.0).timeout
			if is_instance_valid(hit):
				hit.set_deferred("monitoring", true)
	)
	var tw := create_tween()
	tw.tween_property(m, "position:x", 85.0 * dir, 9.0)
	tw.tween_callback(m.queue_free)

# --- Decor vivant (modeles reels) ---

func _place_model(path: String, pos: Vector3, scl: float, rot_y: float, anims: Array) -> void:
	var m := ModelFactory.instance(path)
	if m == null:
		return
	add_child(m)
	m.position = pos
	m.rotation.y = rot_y
	ModelFactory.scale_to(m, scl)
	ModelFactory.play_anim(m, anims)

# --- Meteores (03 §3.2 + 06 §3 : telegraph + impact) ---

func start_meteor_shower(duration: float) -> void:
	_meteor_active = true
	_meteor_loop(duration)

func stop_meteor_shower() -> void:
	_meteor_active = false

func _meteor_loop(duration: float) -> void:
	await get_tree().create_timer(0.1).timeout
	var t := 0.0
	while _meteor_active and t < duration:
		_spawn_meteor()
		t += 1.2
		await get_tree().create_timer(1.2).timeout

func _spawn_meteor() -> void:
	var zones := get_tree().get_nodes_in_group("chaos_zone")
	if zones.is_empty():
		return
	var z: Node3D = zones[_rng.randi() % zones.size()]
	var target: Vector3 = z.global_transform.origin
	# Telegraph : reticule d'ombre.
	var tele := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 1.5
	tm.bottom_radius = 1.5
	tm.height = 0.1
	tele.mesh = tm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(1, 0.2, 0.2, 0.6)
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tele.set_surface_override_material(0, tmat)
	add_child(tele)
	tele.global_position = target + Vector3(0, 0.2, 0)
	VfxFactory.burst(tele, "meteor")
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(tele):
		tele.queue_free()
	if not _meteor_active:
		return
	# Obstacle temporaire serveur-autoritaire.
	var rock := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.2
	sm.height = 2.4
	mi.mesh = sm
	mi.set_surface_override_material(0, _mat(Color(0.25, 0.2, 0.18), 0.9))
	rock.add_child(mi)
	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = 1.2
	cs.shape = ss
	rock.add_child(cs)
	add_child(rock)
	rock.global_position = target + Vector3(0, 12, 0)
	_meteor_nodes.append(rock)
	VfxFactory.burst(rock, "meteor")
	# Chute animee.
	var tw := create_tween()
	tw.tween_property(rock, "global_position", target + Vector3(0, 0.8, 0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	VfxFactory.burst(rock, "collapse")
	# Hit knockback aux proches.
	for v in get_tree().get_nodes_in_group("vehicles"):
		if (v as Node3D).global_position.distance_to(target) < 4.0 and v.has_method("apply_knockback"):
			v.call("apply_knockback", target, 10.0)
	# Nettoyage apres 8s.
	await get_tree().create_timer(8.0).timeout
	if is_instance_valid(rock):
		rock.queue_free()
	_meteor_nodes.erase(rock)
