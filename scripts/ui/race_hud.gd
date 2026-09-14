extends Control
## HUD course (04 §5) : position/tour, minimap, joystick, bouton item, banniere chaos, flash, equipe, gravity overlay.

var _pos_lbl: Label = null
var _banner: PanelContainer = null
var _banner_lbl: Label = null
var _banner_t: float = 0.0
var _flash: ColorRect = null
var _flash_t: float = 0.0
var _item_btn: Button = null
var _team_lbl: Label = null
var _minimap: Control = null
var _gravity_fx: ColorRect = null
var _time_lbl: Label = null
var _lap_lbl: Label = null
var _coin_lbl: Label = null
var _boost_bar: ProgressBar = null
var _stand_box: VBoxContainer = null
var _stand_t: float = 0.0
var _auto_btn: Button = null
var _had_effect: bool = false

const ITEM_NAMES := {"reverse_gun": "🔫 Inverseur", "shrink_ray": "🔬 Reducteur", "chicken_storm": "🐔 Poulets", "banana_boost": "🍌 Boost", "rocket": "🚀 Pingouin", "banana": "🍌 Banane", "triple_banana": "🍌 Bananes", "mushroom": "🍄 Champi", "triple_mushroom": "🍄 Champis", "shell_green": "🐢 Carapace", "shell_red": "🔴 Rouge", "shield": "🛡️ Bouclier", "star": "⭐ Etoile", "lightning": "⚡ Foudre"}
const ROULETTE := ["🍌", "🍄", "🐢", "🔴", "⭐", "⚡", "🔫", "🔬", "🐔", "🚀", "🛡️"]
const ITEM_COLORS := {"reverse_gun": Color(1, 0.2, 0.2), "shrink_ray": Color(0.4, 0.6, 1), "chicken_storm": Color(1, 1, 1), "banana_boost": Color(1, 0.9, 0.2), "rocket": Color(0.3, 0.9, 1)}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	ChaosEventSystem.chaos_event_triggered.connect(_on_chaos)
	ChaosEventSystem.chaos_event_ended.connect(_on_chaos_end)
	TeamManager.team_score_updated.connect(func(_a, _b) -> void: _refresh_team())
	_refresh_team()

func _build() -> void:
	# Haut-gauche : position + tour + temps.
	_pos_lbl = Label.new()
	_pos_lbl.add_theme_font_size_override("font_size", 30)
	_pos_lbl.add_theme_color_override("font_color", Color.WHITE)
	_pos_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_pos_lbl.add_theme_constant_override("outline_size", 6)
	_pos_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_pos_lbl.position = Vector2(16, 12)
	add_child(_pos_lbl)
	_time_lbl = Label.new()
	_time_lbl.add_theme_font_size_override("font_size", 20)
	_time_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
	_time_lbl.position = Vector2(16, 52)
	add_child(_time_lbl)
	_lap_lbl = Label.new()
	_lap_lbl.add_theme_font_size_override("font_size", 17)
	_lap_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	_lap_lbl.position = Vector2(16, 78)
	add_child(_lap_lbl)
	_coin_lbl = Label.new()
	_coin_lbl.add_theme_font_size_override("font_size", 24)
	_coin_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	_coin_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	_coin_lbl.add_theme_constant_override("outline_size", 5)
	_coin_lbl.position = Vector2(16, 104)
	add_child(_coin_lbl)
	# Minimap haut-droite.
	_minimap = _Minimap.new()
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.position = Vector2(-236, 12)
	_minimap.custom_minimum_size = Vector2(220, 160)
	_minimap.size = Vector2(220, 160)
	add_child(_minimap)
	# Tour de classement live (top 8, facon Mario Kart).
	_stand_box = VBoxContainer.new()
	_stand_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_stand_box.position = Vector2(-236, 180)
	_stand_box.custom_minimum_size = Vector2(220, 200)
	_stand_box.add_theme_constant_override("separation", 2)
	add_child(_stand_box)
	# Banniere chaos centre-haut.
	_banner = PanelContainer.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-260, 12)
	_banner.custom_minimum_size = Vector2(520, 64)
	_banner.visible = false
	add_child(_banner)
	_banner_lbl = Label.new()
	_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_lbl.add_theme_font_size_override("font_size", 28)
	_banner.add_child(_banner_lbl)
	# Equipe (duo/squad).
	_team_lbl = Label.new()
	_team_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_team_lbl.position = Vector2(16, 134)
	_team_lbl.add_theme_font_size_override("font_size", 18)
	add_child(_team_lbl)
	# Joystick bas-gauche.
	var joy_script: Script = load("res://scripts/ui/touch_joystick.gd") as Script
	var joy: Control = Control.new()
	joy.set_script(joy_script)
	joy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joy.position = Vector2(24, -224)
	joy.size = Vector2(200, 200)
	joy.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(joy)
	# Drift tactile : bouton au-dessus du joystick.
	var drift := Button.new()
	drift.text = "DRIFT"
	drift.custom_minimum_size = Vector2(120, 56)
	drift.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	drift.position = Vector2(240, -120)
	drift.button_down.connect(func() -> void: _set_drift(true))
	drift.button_up.connect(func() -> void: _set_drift(false))
	add_child(drift)
	# Toggle auto-acceleration (spec 01 §7) : ON = tactile une-main, OFF = manuel.
	_auto_btn = Button.new()
	_auto_btn.text = "AUTO: ON"
	_auto_btn.custom_minimum_size = Vector2(140, 56)
	_auto_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_auto_btn.position = Vector2(240, -190)
	_auto_btn.pressed.connect(_on_auto_toggle)
	add_child(_auto_btn)
	# Jauge de charge drift (bleu -> orange -> violet).
	_boost_bar = ProgressBar.new()
	_boost_bar.min_value = 0.0
	_boost_bar.max_value = 1.0
	_boost_bar.custom_minimum_size = Vector2(300, 12)
	_boost_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boost_bar.position = Vector2(-150, -30)
	_boost_bar.show_percentage = false
	add_child(_boost_bar)
	# Bouton item bas-droite (gros, thumb).
	_item_btn = Button.new()
	_item_btn.text = "—"
	_item_btn.custom_minimum_size = Vector2(150, 150)
	_item_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_item_btn.position = Vector2(-174, -174)
	_item_btn.add_theme_font_size_override("font_size", 20)
	_item_btn.pressed.connect(func() -> void:
		var p := get_tree().get_first_node_in_group("local_player")
		if p and p.has_method("use_item"):
			p.call("use_item")
	)
	add_child(_item_btn)
	# Bouton pause haut-centre (tactile) : Echap / Start font pareil via l'action "pause".
	var pause_btn := Button.new()
	pause_btn.text = "❚❚"
	pause_btn.custom_minimum_size = Vector2(120, 44)
	pause_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pause_btn.position = Vector2(-60, 84)
	pause_btn.add_theme_font_size_override("font_size", 20)
	pause_btn.pressed.connect(func() -> void: GameManager.toggle_pause())
	add_child(pause_btn)
	# Flash hit + gravity overlay.
	_flash = ColorRect.new()
	_flash.color = Color(1, 0, 0, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_gravity_fx = ColorRect.new()
	_gravity_fx.color = Color(0.55, 0.3, 1.0, 0.18)
	_gravity_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gravity_fx.visible = false
	_gravity_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Shader gravity si dispo.
	if ResourceLoader.exists("res://shaders/gravity_flip.gdshader"):
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/gravity_flip.gdshader") as Shader
		_gravity_fx.material = sm
	add_child(_gravity_fx)

func _set_drift(on: bool) -> void:
	var p := get_tree().get_first_node_in_group("local_player")
	if p:
		p.set("touch_drift", on)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameManager.toggle_pause()
		get_viewport().set_input_as_handled()

func _on_auto_toggle() -> void:
	var p := get_tree().get_first_node_in_group("local_player")
	if p:
		p.set("auto_accelerate", not bool(p.get("auto_accelerate")))
		p.set("_keys_seen", false)

func _refresh_auto() -> void:
	if _auto_btn == null:
		return
	var p := get_tree().get_first_node_in_group("local_player")
	if p == null:
		return
	_auto_btn.text = "AUTO: ON" if bool(p.get("auto_accelerate")) else "AUTO: OFF"

func _process(delta: float) -> void:
	if GameManager.current_phase != GameManager.MatchPhase.RACING:
		return
	_refresh_pos()
	_refresh_item()
	_refresh_time()
	_refresh_auto()
	_refresh_meters()
	_poll_hit_flash(delta)
	_stand_t -= delta
	if _stand_t <= 0.0:
		_stand_t = 0.5
		_refresh_standings()
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			_banner.visible = false
	if _flash_t > 0.0:
		_flash_t -= delta
		_flash.color.a = maxf(0.0, _flash_t * 0.8)
	_minimap.queue_redraw()

func _local_vehicle() -> Node:
	return get_tree().get_first_node_in_group("local_player")

func _refresh_pos() -> void:
	var v := _local_vehicle()
	if v == null:
		_pos_lbl.text = "…"
		return
	var k: int = int(v.get("peer_id")) if v.get("peer_id") != null else 0
	var st: Dictionary = BoundaryManager.player_states.get(k, {})
	var lap: int = mini(int(st.get("lap", 1)), GameManager.lap_count)
	# Position : tri par lap puis next_checkpoint.
	var order: Array = []
	for key in BoundaryManager.player_states:
		var s: Dictionary = BoundaryManager.player_states[key]
		order.append({"k": key, "score": int(s.get("lap", 1)) * 100 + int(s.get("next_checkpoint", 1))})
	order.sort_custom(func(a, b) -> bool: return int(a["score"]) > int(b["score"]))
	var pos := 1
	for i in order.size():
		if int(order[i]["k"]) == k:
			pos = i + 1
			break
	_pos_lbl.text = "%d/%d   •   Tour %d/%d" % [pos, order.size(), lap, GameManager.lap_count]

func _refresh_time() -> void:
	var t: float = GameManager.race_timer
	_time_lbl.text = "%02d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]
	var v := _local_vehicle()
	if v != null and _lap_lbl != null:
		var k: int = int(v.get("peer_id")) if v.get("peer_id") != null else 0
		var txt := ""
		if BoundaryManager.last_lap.has(k):
			txt += "Dernier %s  " % GameManager.fmt_time(float(BoundaryManager.last_lap[k]))
		if BoundaryManager.best_lap.has(k):
			txt += "Best %s" % GameManager.fmt_time(float(BoundaryManager.best_lap[k]))
		_lap_lbl.text = txt

func _refresh_item() -> void:
	var v := _local_vehicle()
	if v == null:
		return
	var pend: String = str(v.get("pending_item"))
	if pend != "":
		# Roulette : icones qui defilent avant le resultat.
		_item_btn.text = ROULETTE[int(Time.get_ticks_msec() / 90) % ROULETTE.size()] + " ?"
		_item_btn.disabled = true
		return
	var id: String = str(v.get("held_item"))
	if id == "":
		if float(v.get("star_timer")) > 0.0:
			_item_btn.text = "⭐"
			_item_btn.disabled = true
		elif bool(v.get("shield")):
			_item_btn.text = "🛡️"
			_item_btn.disabled = true
		else:
			_item_btn.text = "—"
			_item_btn.disabled = true
		return
	var n: int = int(v.get("held_charges"))
	_item_btn.text = str(ITEM_NAMES.get(id, id)) + (" x%d" % n if n > 1 else "")
	_item_btn.disabled = false
	var c: Color = ITEM_COLORS.get(id, Color.WHITE)
	_item_btn.add_theme_color_override("font_color", c)

func _refresh_meters() -> void:
	var v := _local_vehicle()
	if v == null:
		return
	_coin_lbl.text = "🪙 %d/10" % int(v.get("coins"))
	if _boost_bar:
		_boost_bar.value = clampf(float(v.get("boost_charge")), 0.0, 1.0)

func _order_scores() -> Array:
	var order: Array = []
	for key in BoundaryManager.player_states:
		var s: Dictionary = BoundaryManager.player_states[key]
		order.append({"k": key, "score": int(s.get("lap", 1)) * 100 + int(s.get("next_checkpoint", 1))})
	order.sort_custom(func(a, b) -> bool: return int(a["score"]) > int(b["score"]))
	return order

func _refresh_standings() -> void:
	if _stand_box == null:
		return
	for c in _stand_box.get_children():
		c.queue_free()
	var me := _local_vehicle()
	var my_key := -99999
	if me:
		my_key = int(me.get("peer_id")) if me.get("peer_id") != null else -99999
	var order := _order_scores()
	for i in mini(order.size(), 8):
		var pid: int = int(order[i]["k"])
		var l := Label.new()
		l.text = "#%d %s" % [i + 1, GameManager.get_display_name(pid)]
		l.add_theme_font_size_override("font_size", 16)
		if pid == my_key:
			l.add_theme_color_override("font_color", Color(1, 0.88, 0.2))
		else:
			l.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		_stand_box.add_child(l)

func _poll_hit_flash(delta: float) -> void:
	var v := _local_vehicle()
	if v == null:
		return
	var eff := float(v.get("reverse_timer")) + float(v.get("shrink_timer")) + float(v.get("chicken_timer")) + float(v.get("penguin_timer"))
	var has := eff > 0.0
	if has and not _had_effect:
		# Flash couleur par item dominant.
		var c := Color(1, 0.2, 0.2)
		if float(v.get("penguin_timer")) > 0.0:
			c = Color(0.3, 0.9, 1)
		elif float(v.get("shrink_timer")) > 0.0:
			c = Color(0.4, 0.6, 1)
		_flash.color = Color(c.r, c.g, c.b, 0.45)
		_flash_t = 0.6
	_had_effect = has

func _on_chaos(e: ChaosEventData) -> void:
	_banner_lbl.text = "⚠ " + e.display_name
	_banner.visible = true
	_banner_t = 2.5
	# Petit slide-in.
	_banner.position.y = -70
	var tw := create_tween()
	tw.tween_property(_banner, "position:y", 12, 0.3).set_trans(Tween.TRANS_BACK)
	if e.id == "gravity_inversion":
		_gravity_fx.visible = true

func _on_chaos_end(e: ChaosEventData) -> void:
	if e.id == "gravity_inversion":
		_gravity_fx.visible = false

func _refresh_team() -> void:
	if GameManager.current_format == "duo" or GameManager.current_format == "squad":
		var txt := ""
		for tid in TeamManager.get_team_ranking():
			txt += "Equipe %d : %.0f pts   " % [int(tid) + 1, float(TeamManager.team_scores.get(tid, 0.0))]
		_team_lbl.text = txt
	else:
		_team_lbl.text = ""

# Minimap interne : ovale + dots colores par equipe.
class _Minimap extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.4), false, 2.0)
		# Piste schematique : rectangle arrondi.
		var r := Rect2(Vector2(20, 20), size - Vector2(40, 40))
		draw_rect(r, Color(0.3, 0.3, 0.4), false, 6.0)
		# Raccourci central.
		draw_line(Vector2(r.position.x, r.position.y + r.size.y / 2.0), Vector2(r.end.x, r.position.y + r.size.y / 2.0), Color(0.6, 0.6, 0.7, 0.6), 2.0)
		var vehicles := get_tree().get_nodes_in_group("vehicles")
		for v in vehicles:
			if not (v is Node3D):
				continue
			var p: Vector3 = (v as Node3D).global_position
			var nx: float = clampf((p.x + 70.0) / 140.0, 0.0, 1.0)
			var nz: float = clampf((p.z + 50.0) / 100.0, 0.0, 1.0)
			var dpos := Vector2(r.position.x + nx * r.size.x, r.position.y + nz * r.size.y)
			var c := Color.WHITE
			if (v as Node).is_in_group("local_player"):
				c = Color(1, 0.88, 0.2)
			elif TeamManager.teams.size() > 1:
				var tid := TeamManager.team_of(int((v as Node).get("peer_id")))
				var palette := [Color(0.3, 0.7, 1), Color(1, 0.3, 0.3), Color(0.3, 1, 0.4), Color(1, 0.6, 0.2)]
				c = palette[abs(tid) % palette.size()]
			draw_circle(dpos, 6.0 if (v as Node).is_in_group("local_player") else 4.0, c)
