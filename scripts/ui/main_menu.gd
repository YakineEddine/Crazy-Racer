extends Control
## Menu principal en 4 etapes progressives (UI_UX §1) : titre -> mode -> format+circuit -> salon.
## Meme racine Control codee, pas d'enfants .tscn. Transitions : fondu modulate:a 0.25s.

var _format: String = "ffa"
var _map_id: String = "map1_neon"
var _mode: String = "single" ## "single" | "gp" | "tt"
var _step: int = 1
var _fmt_btns: Dictionary = {}
var _map_btns: Dictionary = {}
var _center: CenterContainer = null
var _step_box: VBoxContainer = null
var _dots: Array = []
var _back_btn: Button = null
var _box_norm: StyleBoxFlat = null ## toggle eteint : meme rendu que le theme
var _box_sel: StyleBoxFlat = null ## toggle allume : navy + liseret or (UI_UX §2)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_box_norm = _mk_toggle_box(Palette.PANEL, false)
	_box_sel = _mk_toggle_box(Palette.PANEL, true)
	_build()

func _mk_toggle_box(bg: Color, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_right = 12
	sb.corner_radius_bottom_left = 12
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	if selected:
		sb.border_width_left = 3
		sb.border_width_top = 3
		sb.border_width_right = 3
		sb.border_width_bottom = 3
		sb.border_color = Palette.GOLD
	return sb

func _build() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	var gt := GradientTexture2D.new()
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var grad := Gradient.new()
	grad.set_color(0, Palette.NAVY_TOP)
	grad.set_color(1, Palette.NAVY_BOTTOM)
	gt.gradient = grad
	bg.texture = gt
	add_child(bg)
	# Chrome persistant : retour haut-gauche (cache etape 1).
	_back_btn = Button.new()
	_back_btn.text = "← Retour"
	_back_btn.custom_minimum_size = Vector2(140, 48)
	_back_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_back_btn.position = Vector2(12, 12)
	_back_btn.pressed.connect(func() -> void: _show_step(_step - 1))
	add_child(_back_btn)
	# Indicateur d'etape : 4 pastilles, or = active.
	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 8)
	dots.set_anchors_preset(Control.PRESET_CENTER_TOP)
	dots.position = Vector2(-40, 16)
	add_child(dots)
	_dots.clear()
	for i in 4:
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(14, 14)
		dots.add_child(d)
		_dots.append(d)
	# Musique haut-droite (persistant, meme logique qu'avant).
	var mute := Button.new()
	mute.text = "♪ Musique : ON" if GameManager.settings_music else "♪ Musique : OFF"
	mute.custom_minimum_size = Vector2(200, 40)
	mute.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mute.position = Vector2(-212, 12)
	mute.pressed.connect(func() -> void:
		GameManager.set_music_enabled(not GameManager.settings_music)
		mute.text = "♪ Musique : ON" if GameManager.settings_music else "♪ Musique : OFF"
	)
	add_child(mute)
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_center)
	_show_step(1)

func _show_step(n: int) -> void:
	_step = clampi(n, 1, 4)
	if is_instance_valid(_step_box):
		_center.remove_child(_step_box)
		_step_box.queue_free()
	_step_box = VBoxContainer.new()
	_step_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_step_box.add_theme_constant_override("separation", 8)
	_center.add_child(_step_box)
	match _step:
		1:
			_build_step1(_step_box)
		2:
			_build_step2(_step_box)
		3:
			_build_step3(_step_box)
		4:
			_build_step4(_step_box)
	_back_btn.visible = (_step > 1)
	for i in _dots.size():
		(_dots[i] as ColorRect).color = Palette.GOLD if (i + 1 == _step) else Palette.MUTED
	_step_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_step_box, "modulate:a", 1.0, 0.25)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _step > 1:
		_show_step(_step - 1)
		get_viewport().set_input_as_handled()

func _build_step1(vb: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "CRAZY RACER"
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Palette.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "Party kart • chaos global • 3 tours"
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Palette.SKY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)
	var jouer := Button.new()
	jouer.text = "JOUER"
	jouer.custom_minimum_size = Vector2(220, 60)
	jouer.add_theme_font_size_override("font_size", 22)
	jouer.pressed.connect(func() -> void: _show_step(2))
	hb.add_child(jouer)
	var compte := Button.new()
	compte.text = "SE CONNECTER"
	compte.custom_minimum_size = Vector2(220, 60)
	compte.add_theme_font_size_override("font_size", 22)
	compte.pressed.connect(func() -> void: GameManager.change_phase(GameManager.MatchPhase.AUTH))
	hb.add_child(compte)
	if SupaAuth.is_signed_in():
		var board := Button.new()
		board.text = "🏆 CLASSEMENT"
		board.custom_minimum_size = Vector2(220, 60)
		board.add_theme_font_size_override("font_size", 22)
		board.pressed.connect(func() -> void:
			GameManager.board_return = GameManager.MatchPhase.MENU
			GameManager.board_map_id = GameManager.current_map_id
			GameManager.change_phase(GameManager.MatchPhase.BOARD)
		)
		hb.add_child(board)
	var hint := Label.new()
	hint.text = "Clavier : ↑/W accelerer • ↓/S freiner • ←/A →/D diriger • Espace drift • E item  |  Tactile : joystick + AUTO + bouton"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Palette.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)

func _build_step2(vb: VBoxContainer) -> void:
	vb.add_child(_mk_label("Mode de jeu :"))
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 10)
	vb.add_child(modes)
	var course := Button.new()
	course.text = "🏁 COURSE"
	course.custom_minimum_size = Vector2(170, 60)
	course.add_theme_font_size_override("font_size", 22)
	course.pressed.connect(func() -> void:
		_mode = "single"
		_show_step(3)
	)
	modes.add_child(course)
	var gp := Button.new()
	gp.text = "🏆 GRAND PRIX"
	gp.custom_minimum_size = Vector2(190, 60)
	gp.add_theme_font_size_override("font_size", 22)
	gp.pressed.connect(func() -> void:
		_mode = "gp"
		_show_step(3)
	)
	modes.add_child(gp)
	var tt := Button.new()
	tt.text = "⏱ CONTRE-LA-MONTRE"
	tt.custom_minimum_size = Vector2(240, 60)
	tt.add_theme_font_size_override("font_size", 22)
	tt.pressed.connect(func() -> void:
		_mode = "tt"
		_show_step(3)
	)
	modes.add_child(tt)

func _build_step3(vb: VBoxContainer) -> void:
	_fmt_btns.clear()
	_map_btns.clear()
	if _mode != "tt":
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
	if _mode != "gp":
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
	var go := HBoxContainer.new()
	go.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(go)
	var next := Button.new()
	next.text = "SUIVANT →"
	next.custom_minimum_size = Vector2(220, 56)
	next.add_theme_font_size_override("font_size", 22)
	next.pressed.connect(func() -> void: _show_step(4))
	go.add_child(next)

func _build_step4(vb: VBoxContainer) -> void:
	if _mode != "tt":
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
	var rec := Label.new()
	rec.text = _records_text()
	rec.add_theme_font_size_override("font_size", 16)
	rec.add_theme_color_override("font_color", Palette.GOLD)
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rec)
	var go := HBoxContainer.new()
	go.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(go)
	if _mode == "gp":
		var gp := Button.new()
		gp.text = "🏆 GRAND PRIX"
		gp.custom_minimum_size = Vector2(190, 60)
		gp.add_theme_font_size_override("font_size", 22)
		gp.pressed.connect(func() -> void: GameManager.start_gp_lobby(_format))
		go.add_child(gp)
	elif _mode == "tt":
		var tt := Button.new()
		tt.text = "▶ PARTIR"
		tt.custom_minimum_size = Vector2(240, 60)
		tt.add_theme_font_size_override("font_size", 22)
		tt.pressed.connect(func() -> void: GameManager.start_tt(_map_id))
		go.add_child(tt)
	else:
		var course := Button.new()
		course.text = "🏁 COURSE"
		course.custom_minimum_size = Vector2(170, 60)
		course.add_theme_font_size_override("font_size", 22)
		course.pressed.connect(func() -> void: GameManager.request_quick_play(_format, _map_id))
		go.add_child(course)

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
		var b := _fmt_btns[f] as Button
		var sel: bool = (f == _format)
		b.button_pressed = sel
		b.add_theme_stylebox_override("normal", _box_sel if sel else _box_norm)
	for id in _map_btns:
		var b := _map_btns[id] as Button
		var sel: bool = (id == _map_id)
		b.button_pressed = sel
		b.add_theme_stylebox_override("normal", _box_sel if sel else _box_norm)

func _on_create() -> void:
	GameManager.mode = "single"
	GameManager.current_format = _format
	GameManager.current_map_id = _map_id
	LobbyManager.create_room(_format)
	LobbyManager.ensure_bot_fill()
	GameManager.change_phase(GameManager.MatchPhase.LOBBY)
