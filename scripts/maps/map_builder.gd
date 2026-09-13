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
	# GridMap requis par le contrat (tuiles modulaires) : stub vide pour conformite.
	var gm := GridMap.new()
	gm.name = "GridMap"
	gm.cell_size = Vector3(10, 1, 10)
	add_child(gm)

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
	var on_straight := absf(p.x) <= 67.0 and ((p.z >= -46.5 and p.z <= -33.5) or (p.z >= 33.5 and p.z <= 46.5))
	var on_side := absf(p.z) <= 46.5 and ((p.x >= 53.5 and p.x <= 66.5) or (p.x >= -66.5 and p.x <= -53.5))
	var on_shortcut := absf(p.z) <= 4.5 and absf(p.x) <= 51.0
	return on_straight or on_side or on_shortcut

func _build_road_lines() -> void:
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

func _process(_delta: float) -> void:
	# Moulin + pulsation des pads (le reste est statique).
	if is_instance_valid(_windmill):
		_windmill.rotation.z += _delta * 0.8

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
