extends Control
## Countdown 3-2-1-GO (04 §4). Controles verrouilles jusqu'au GO.

var _lbl: Label = null
var _t: float = 3.5

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.35)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_lbl = Label.new()
	_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl.add_theme_font_size_override("font_size", 160)
	_lbl.add_theme_color_override("font_color", Color(1, 0.88, 0.3))
	_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_lbl.add_theme_constant_override("outline_size", 12)
	add_child(_lbl)
	var hint := Label.new()
	hint.text = "Maintiens ↑ (ou DRIFT) pour un depart turbo !"
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-260, -90)
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	add_child(hint)
	get_tree().call_group("vehicles", "set_controls_locked", true)
	set_process(true)

func _process(delta: float) -> void:
	_t -= delta
	var txt := "GO !"
	var col := Color(0.3, 1, 0.4)
	if _t > 2.5:
		txt = "3"
		col = Color(1, 0.4, 0.4)
	elif _t > 1.5:
		txt = "2"
		col = Color(1, 0.7, 0.2)
	elif _t > 0.5:
		txt = "1"
		col = Color(1, 0.88, 0.3)
	if _lbl.text != txt:
		_lbl.text = txt
		Audio.play("go" if txt == "GO !" else "beep")
		_lbl.add_theme_color_override("font_color", col)
		_lbl.scale = Vector2(1.4, 1.4)
		_lbl.pivot_offset = size / 2.0
		var tw := create_tween()
		tw.tween_property(_lbl, "scale", Vector2.ONE, 0.3)
