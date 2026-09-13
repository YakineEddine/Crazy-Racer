extends Control
## Menu principal : Course / Grand Prix / Contre-la-montre + records persistants.

var _format: String = "ffa"
var _map_id: String = "map1_neon"
var _fmt_btns: Dictionary = {}
var _map_btns: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	var gt := GradientTexture2D.new()
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.1, 0.06, 0.24))
	grad.set_color(1, Color(0.02, 0.02, 0.08))
	gt.gradient = grad
	bg.texture = gt
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	center.add_child(vb)
	var title := Label.new()
	title.text = "CRAZY RACER"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(1, 0.88, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "Party kart • chaos global • 3 tours"
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.7, 0.9, 1))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	vb.add_child(_mk_label("Format :"))
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 8)
	vb.add_child(hb)
	for f in ["1v1", "duo", "squad", "ffa"]:
		var b := Button.new()
		b.text = f.to_upper()
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(90, 50)
		b.pressed.connect(_on_format.bind(f))
		hb.add_child(b)
		_fmt_btns[f] = b
	vb.add_child(_mk_label("Circuit :"))
	var hb2 := HBoxContainer.new()
	hb2.alignment = BoxContainer.ALIGNMENT_CENTER
	hb2.add_theme_constant_override("separation", 8)
	vb.add_child(hb2)
	var maps := {"map1_neon": "Neon", "map2_swamp": "Swamp", "map3_ice": "Glace", "map4_farm": "Ferme"}
	for id in maps:
		var b := Button.new()
		b.text = maps[id]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(90, 50)
		b.pressed.connect(_on_map.bind(id))
		hb2.add_child(b)
		_map_btns[id] = b
	_refresh_toggles()
	# 3 modes.
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 10)
	vb.add_child(modes)
	var course := Button.new()
	course.text = "🏁 COURSE"
	course.custom_minimum_size = Vector2(170, 60)
	course.add_theme_font_size_override("font_size", 22)
	course.pressed.connect(func() -> void: GameManager.request_quick_play(_format, _map_id))
	modes.add_child(course)
	var gp := Button.new()
	gp.text = "🏆 GRAND PRIX"
	gp.custom_minimum_size = Vector2(190, 60)
	gp.add_theme_font_size_override("font_size", 22)
	gp.pressed.connect(func() -> void: GameManager.start_gp_lobby(_format))
	modes.add_child(gp)
	var tt := Button.new()
	tt.text = "⏱ CONTRE-LA-MONTRE"
	tt.custom_minimum_size = Vector2(240, 60)
	tt.add_theme_font_size_override("font_size", 22)
	tt.pressed.connect(func() -> void: GameManager.start_tt(_map_id))
	modes.add_child(tt)
	# Salon prive.
	var hb3 := HBoxContainer.new()
	hb3.alignment = BoxContainer.ALIGNMENT_CENTER
	hb3.add_theme_constant_override("separation", 8)
	vb.add_child(hb3)
	var create := Button.new()
	create.text = "Creer salon prive"
	create.custom_minimum_size = Vector2(190, 48)
	create.pressed.connect(_on_create)
	hb3.add_child(create)
	var code_edit := LineEdit.new()
	code_edit.placeholder_text = "Code 4 chiffres"
	code_edit.max_length = 4
	code_edit.custom_minimum_size = Vector2(150, 48)
	code_edit.name = "CodeEdit"
	hb3.add_child(code_edit)
	var join := Button.new()
	join.text = "Rejoindre"
	join.custom_minimum_size = Vector2(120, 48)
	join.pressed.connect(func() -> void:
		var le: LineEdit = hb3.get_node("CodeEdit")
		if LobbyManager.join_room(le.text):
			GameManager.mode = "single"
			GameManager.current_format = _format
			GameManager.change_phase(GameManager.MatchPhase.LOBBY)
	)
	hb3.add_child(join)
	# Records.
	var rec := Label.new()
	rec.text = _records_text()
	rec.add_theme_font_size_override("font_size", 16)
	rec.add_theme_color_override("font_color", Color(1, 0.88, 0.3))
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rec)
	var hint := Label.new()
	hint.text = "Clavier : ↑ accelerer • ↓ freiner • ←/→ diriger • Espace drift • E item  |  Tactile : joystick + AUTO + bouton"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	var mute := Button.new()
	mute.text = "♪ Musique : ON" if Audio.music_on else "♪ Musique : OFF"
	mute.custom_minimum_size = Vector2(200, 40)
	mute.pressed.connect(func() -> void:
		Audio.toggle_music()
		mute.text = "♪ Musique : ON" if Audio.music_on else "♪ Musique : OFF"
	)
	var mc := HBoxContainer.new()
	mc.alignment = BoxContainer.ALIGNMENT_CENTER
	mc.add_child(mute)
	vb.add_child(mc)

func _records_text() -> String:
	var parts: Array = []
	var bests: Dictionary = GameManager.get_tt_bests()
	for m in ["map1_neon", "map2_swamp", "map3_ice", "map4_farm"]:
		if bests.has(m):
			var b: Dictionary = bests[m]
			parts.append("%s %s" % [str(GameManager.MAP_SHORT.get(m, m)), GameManager.fmt_time(float(b.get("total", 0.0)))])
	var txt := "⏱ Records : " + (" • ".join(PackedStringArray(parts)) if not parts.is_empty() else "—")
	txt += "   🏆 GP gagnes : %d" % GameManager.get_gp_wins()
	return txt

func _mk_label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _on_format(f: String) -> void:
	_format = f
	_refresh_toggles()

func _on_map(id: String) -> void:
	_map_id = id
	_refresh_toggles()

func _refresh_toggles() -> void:
	for f in _fmt_btns:
		(_fmt_btns[f] as Button).button_pressed = (f == _format)
	for id in _map_btns:
		(_map_btns[id] as Button).button_pressed = (id == _map_id)

func _on_create() -> void:
	GameManager.mode = "single"
	GameManager.current_format = _format
	GameManager.current_map_id = _map_id
	LobbyManager.create_room(_format)
	LobbyManager.ensure_bot_fill()
	GameManager.change_phase(GameManager.MatchPhase.LOBBY)
