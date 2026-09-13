extends Control
## Lobby (04 §3) : code, 16 slots, format host, carousels, ready/start, leave.

var _list: VBoxContainer = null
var _start_btn: Button = null
var _code_lbl: Label = null
var _veh_idx: int = 0
var _char_idx: int = 0
var _veh_lbl: Label = null
var _char_lbl: Label = null
var _stat_bars: Dictionary = {}

const VEHICLES := ["kart", "car", "truck", "motorcycle", "bicycle"]
const VEH_NAMES := {"kart": "Kart", "car": "Car", "truck": "Camion", "motorcycle": "Moto", "bicycle": "Velo"}
const VEH_STATS := {
	"kart": "res://assets/resources/kart_stats.tres",
	"car": "res://assets/resources/car_stats.tres",
	"truck": "res://assets/resources/truck_stats.tres",
	"motorcycle": "res://assets/resources/motorcycle_stats.tres",
	"bicycle": "res://assets/resources/bicycle_stats.tres",
}
const CHARS := ["human", "crocodile", "penguin", "chicken"]
const CHAR_NAMES := {"human": "Humain", "crocodile": "Croco", "penguin": "Pingouin", "chicken": "Poulet"}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	LobbyManager.lobby_updated.connect(_refresh)
	_refresh()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)
	_code_lbl = Label.new()
	_code_lbl.add_theme_font_size_override("font_size", 36)
	_code_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_code_lbl)
	# Format (host).
	var fh := HBoxContainer.new()
	fh.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(fh)
	for f in ["1v1", "duo", "squad", "ffa"]:
		var b := Button.new()
		b.text = f.to_upper()
		b.custom_minimum_size = Vector2(90, 48)
		b.pressed.connect(func() -> void:
			GameManager.current_format = f
			LobbyManager.lobby_updated.emit()
		)
		b.name = "Fmt_" + f
		fh.add_child(b)
	# Liste joueurs.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	# Customisation.
	var ch := HBoxContainer.new()
	ch.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.add_theme_constant_override("separation", 10)
	vb.add_child(ch)
	var pv := Button.new()
	pv.text = "◀"
	pv.custom_minimum_size = Vector2(56, 56)
	pv.pressed.connect(func() -> void: _veh_idx = (_veh_idx - 1 + VEHICLES.size()) % VEHICLES.size(); _apply_custom())
	ch.add_child(pv)
	_veh_lbl = Label.new()
	_veh_lbl.custom_minimum_size = Vector2(170, 56)
	_veh_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_veh_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ch.add_child(_veh_lbl)
	var nv := Button.new()
	nv.text = "▶"
	nv.custom_minimum_size = Vector2(56, 56)
	nv.pressed.connect(func() -> void: _veh_idx = (_veh_idx + 1) % VEHICLES.size(); _apply_custom())
	ch.add_child(nv)
	var pc := Button.new()
	pc.text = "◀"
	pc.custom_minimum_size = Vector2(56, 56)
	pc.pressed.connect(func() -> void: _char_idx = (_char_idx - 1 + CHARS.size()) % CHARS.size(); _apply_custom())
	ch.add_child(pc)
	_char_lbl = Label.new()
	_char_lbl.custom_minimum_size = Vector2(170, 56)
	_char_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ch.add_child(_char_lbl)
	var nc := Button.new()
	nc.text = "▶"
	nc.custom_minimum_size = Vector2(56, 56)
	nc.pressed.connect(func() -> void: _char_idx = (_char_idx + 1) % CHARS.size(); _apply_custom())
	ch.add_child(nc)
	# Barres de stats du vehicule choisi (facon Mario Kart).
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 14)
	vb.add_child(stats)
	_stat_bars.clear()
	for s in [["VTS", "top_speed", 26.0], ["ACC", "acceleration", 19.0], ["VIR", "turning_radius", 1.0]]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		stats.add_child(col)
		var lab := Label.new()
		lab.text = str(s[0])
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 14)
		col.add_child(lab)
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.custom_minimum_size = Vector2(120, 12)
		bar.show_percentage = false
		col.add_child(bar)
		_stat_bars[str(s[0])] = [bar, str(s[1]), float(s[2])]
	# Bas.
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	vb.add_child(bottom)
	var leave := Button.new()
	leave.text = "Quitter"
	leave.custom_minimum_size = Vector2(140, 56)
	leave.pressed.connect(func() -> void: GameManager.back_to_menu())
	bottom.add_child(leave)
	var ready := Button.new()
	ready.text = "PRET ✓"
	ready.toggle_mode = true
	ready.custom_minimum_size = Vector2(160, 56)
	ready.toggled.connect(func(on: bool) -> void:
		LobbyManager.set_ready(multiplayer.get_unique_id(), on)
		_refresh()
	)
	bottom.add_child(ready)
	_start_btn = Button.new()
	_start_btn.text = "START RACE"
	_start_btn.custom_minimum_size = Vector2(220, 56)
	_start_btn.pressed.connect(func() -> void:
		if LobbyManager.can_start():
			GameManager.start_countdown()
	)
	bottom.add_child(_start_btn)

func _apply_custom() -> void:
	var me := multiplayer.get_unique_id()
	LobbyManager.set_vehicle(me, VEHICLES[_veh_idx])
	LobbyManager.set_character(me, CHARS[_char_idx])
	_refresh()

func _refresh() -> void:
	_code_lbl.text = "SALON  " + (LobbyManager.room_code if LobbyManager.room_code != "" else "----") + "   •   " + GameManager.current_format.to_upper()
	# Slots.
	for c in _list.get_children():
		c.queue_free()
	var ids: Array = LobbyManager.get_all_peer_ids()
	for pid in ids:
		var info: Dictionary = LobbyManager.players[pid]
		var row := HBoxContainer.new()
		var dot := ColorRect.new()
		dot.color = Color(0.3, 1, 0.4) if bool(info.get("ready", false)) else Color(0.5, 0.5, 0.55)
		dot.custom_minimum_size = Vector2(18, 18)
		row.add_child(dot)
		var l := Label.new()
		var nm: String = str(info.get("name", "Joueur")) + (" [BOT]" if bool(info.get("is_bot", false)) else "")
		l.text = "%s  •  %s  •  %s  %s" % [nm, str(VEH_NAMES.get(info.get("vehicle_class", "kart"), "?")), str(CHAR_NAMES.get(info.get("character_id", "human"), "?")), "✓" if bool(info.get("ready", false)) else "…"]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		_list.add_child(row)
	for i in range(ids.size(), 16):
		var l := Label.new()
		l.text = "— En attente d'un joueur…"
		l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_list.add_child(l)
	# Perso local.
	var me := multiplayer.get_unique_id()
	if LobbyManager.players.has(me):
		var v: String = str(LobbyManager.players[me].get("vehicle_class", "kart"))
		var c: String = str(LobbyManager.players[me].get("character_id", "human"))
		_veh_idx = maxi(0, VEHICLES.find(v))
		_char_idx = maxi(0, CHARS.find(c))
	_veh_lbl.text = "🚗 " + str(VEH_NAMES.get(VEHICLES[_veh_idx], "?"))
	_char_lbl.text = "🦆 " + str(CHAR_NAMES.get(CHARS[_char_idx], "?"))
	_refresh_stat_bars()
	_start_btn.disabled = not LobbyManager.can_start()
	_start_btn.text = "START RACE" if LobbyManager.can_start() else "En attente…"

func _refresh_stat_bars() -> void:
	var st: KartStats = null
	var p: String = VEH_STATS.get(VEHICLES[_veh_idx], "")
	if ResourceLoader.exists(p):
		st = load(p) as KartStats
	for key in _stat_bars:
		var e: Array = _stat_bars[key]
		var bar := e[0] as ProgressBar
		if bar == null:
			continue
		var val := 0.5
		if st:
			val = clampf(float(st.get(str(e[1]))) / float(e[2]), 0.05, 1.0)
		bar.value = val
