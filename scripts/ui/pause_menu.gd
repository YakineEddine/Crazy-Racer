extends Control
## Pause (phase PAUSED, arbre gelee) : reprendre / reglages / quitter.
## process_mode ALWAYS : les boutons doivent repondre pendant get_tree().paused.

var _music_btn: Button = null
var _vol_slider: HSlider = null
var _vol_lbl: Label = null
var _q_btns: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_refresh()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.14, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)
	var title := Label.new()
	title.text = "❚❚  PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.88, 0.3))
	vb.add_child(title)
	var resume := Button.new()
	resume.text = "▶ Reprendre"
	resume.custom_minimum_size = Vector2(260, 56)
	resume.pressed.connect(func() -> void: GameManager.resume_race())
	var rc := HBoxContainer.new()
	rc.alignment = BoxContainer.ALIGNMENT_CENTER
	rc.add_child(resume)
	vb.add_child(rc)
	# --- Reglages (persistants, section "settings" du cfg) ---
	var st := Label.new()
	st.text = "— Réglages —"
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.add_theme_font_size_override("font_size", 24)
	vb.add_child(st)
	_music_btn = Button.new()
	_music_btn.custom_minimum_size = Vector2(260, 48)
	_music_btn.pressed.connect(func() -> void:
		GameManager.set_music_enabled(not GameManager.settings_music)
		_refresh()
	)
	var mc := HBoxContainer.new()
	mc.alignment = BoxContainer.ALIGNMENT_CENTER
	mc.add_child(_music_btn)
	vb.add_child(mc)
	var volrow := HBoxContainer.new()
	volrow.alignment = BoxContainer.ALIGNMENT_CENTER
	volrow.add_theme_constant_override("separation", 10)
	vb.add_child(volrow)
	_vol_lbl = Label.new()
	_vol_lbl.custom_minimum_size = Vector2(150, 40)
	_vol_lbl.add_theme_font_size_override("font_size", 18)
	volrow.add_child(_vol_lbl)
	_vol_slider = HSlider.new()
	_vol_slider.min_value = 0.0
	_vol_slider.max_value = 100.0
	_vol_slider.step = 1.0
	_vol_slider.custom_minimum_size = Vector2(300, 40)
	_vol_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_vol_slider.value_changed.connect(func(v: float) -> void:
		GameManager.settings_volume = clampf(v / 100.0, 0.0, 1.0)
		GameManager.apply_settings()
		_refresh_vol()
	)
	_vol_slider.drag_ended.connect(func(_changed: bool) -> void: GameManager.save_settings())
	volrow.add_child(_vol_slider)
	var qrow := HBoxContainer.new()
	qrow.alignment = BoxContainer.ALIGNMENT_CENTER
	qrow.add_theme_constant_override("separation", 10)
	vb.add_child(qrow)
	for q in [["high", "Graphismes : Haute"], ["low", "Graphismes : Basse"]]:
		var b := Button.new()
		b.text = str(q[1])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(220, 48)
		b.pressed.connect(_on_quality.bind(str(q[0])))
		qrow.add_child(b)
		_q_btns[str(q[0])] = b
	var quit := Button.new()
	quit.text = "Quitter vers le menu"
	quit.custom_minimum_size = Vector2(260, 56)
	quit.pressed.connect(func() -> void: GameManager.back_to_menu())
	var qc := HBoxContainer.new()
	qc.alignment = BoxContainer.ALIGNMENT_CENTER
	qc.add_child(quit)
	vb.add_child(qc)
	var hint := Label.new()
	hint.text = "Echap / Start : reprendre"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vb.add_child(hint)

func _on_quality(q: String) -> void:
	GameManager.set_quality(q)
	_refresh()

func _refresh() -> void:
	_music_btn.text = "♪ Musique : ON" if GameManager.settings_music else "♪ Musique : OFF"
	_vol_slider.set_value_no_signal(GameManager.settings_volume * 100.0)
	_refresh_vol()
	for q in _q_btns:
		(_q_btns[q] as Button).button_pressed = (q == GameManager.settings_quality)

func _refresh_vol() -> void:
	_vol_lbl.text = "Volume : %d %%" % int(GameManager.settings_volume * 100.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameManager.resume_race()
		get_viewport().set_input_as_handled()
