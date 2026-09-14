extends Control
## Resultats : Course (podium+XP), Grand Prix (manches+champion), Contre-la-montre (chronos+record).

var _xp: int = 0
var _xp_target: int = 0
var _xp_lbl: Label = null
var _board_client: SupaAuth = null
var _rank_lbl: Label = null
var _submit_total: int = 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameManager.mode == "tt":
		_build_tt()
	elif GameManager.mode == "gp":
		if GameManager.gp_final:
			_build_champion()
		else:
			_build_gp_manche()
	else:
		_build_single()
	_submit_and_rank()
	_play_anims()

## Classement en ligne (UI_UX §6) : soumission unique par course + rang perso.
## Invites : rang seul, jamais de top public. Hors-ligne : rien ne change.

func _with_board(defs: Array) -> Array:
	if SupaAuth.is_signed_in():
		var out := defs.duplicate()
		out.append(["🏆 CLASSEMENT", func() -> void:
			GameManager.board_return = GameManager.MatchPhase.RESULTS
			GameManager.board_map_id = GameManager.current_map_id
			GameManager.change_phase(GameManager.MatchPhase.BOARD)
		])
		return out
	return defs

func _local_total_ms() -> int:
	return maxi(1, int(GameManager.race_timer * 1000.0))

func _submit_and_rank() -> void:
	# Pas de soumission sur l'ecran champion (aucune course courue pour lui).
	if GameManager.mode == "gp" and GameManager.gp_final:
		return
	if GameManager.results.is_empty():
		return
	_board_client = SupaAuth.new()
	add_child(_board_client)
	if not _board_client.configure():
		_board_client.queue_free()
		_board_client = null
		return
	_board_client.db_ok.connect(_on_board)
	_board_client.db_fail.connect(_on_board_fail)
	if not GameManager.results_submitted:
		GameManager.results_submitted = true
		_submit_total = _local_total_ms()
		_board_client.db_post("/rest/v1/race_results", _submit_row(_submit_total), "submit")
	else:
		_submit_total = _local_total_ms()
		_fetch_rank()

func _submit_row(total_ms: int) -> Dictionary:
	var uid := multiplayer.get_unique_id()
	var user_id := ""
	if SupaAuth.is_signed_in():
		user_id = str(SupaAuth.session.get("user_id", ""))
	var members := ""
	var tid := TeamManager.team_of(uid)
	if tid != -1:
		var mates: Array = TeamManager.teams.get(tid, [])
		if mates.size() > 1:
			var parts := PackedStringArray()
			for pid in mates:
				parts.append(GameManager.get_display_name(int(pid)))
			members = " | ".join(parts)
	return BoardClient.build_submit_row(user_id, GameManager.get_display_name(uid),
		GameManager.current_map_id, GameManager.mode, total_ms, "", members)

func _fetch_rank() -> void:
	if _board_client == null:
		return
	_board_client.db_get(BoardClient.rank_path(GameManager.current_map_id, _submit_total),
		"rank", ["Prefer: count=exact"])

func _on_board(tag: String, data: Variant) -> void:
	if tag == "submit":
		_fetch_rank()
	elif tag == "rank" and data is Dictionary:
		_show_rank(int(data.get("total", 0)) + 1)

func _on_board_fail(_tag: String, _message: String) -> void:
	if is_instance_valid(_rank_lbl):
		_rank_lbl.queue_free()
		_rank_lbl = null

func _show_rank(rank: int) -> void:
	if rank <= 0 or not is_instance_valid(_rank_lbl):
		return
	_rank_lbl.text = "Votre rang : %d" % rank

func _root() -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.14)
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
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)
	return vb

func _title(vb: VBoxContainer, t: String) -> void:
	var title := Label.new()
	title.text = t
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.88, 0.3))
	vb.add_child(title)

func _buttons(vb: VBoxContainer, defs: Array) -> void:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 14)
	vb.add_child(hb)
	for d in defs:
		var b := Button.new()
		b.text = str(d[0])
		b.custom_minimum_size = Vector2(210, 56)
		b.pressed.connect(d[1])
		hb.add_child(b)

# --- Course simple ---

func _build_single() -> void:
	var vb := _root()
	_title(vb, "🏁  RESULTATS")
	var res: Array = GameManager.results
	var pod := HBoxContainer.new()
	pod.alignment = BoxContainer.ALIGNMENT_CENTER
	pod.add_theme_constant_override("separation", 16)
	vb.add_child(pod)
	for i in mini(3, res.size()):
		pod.add_child(_podium_card(res[i], i))
	if res.is_empty():
		vb.add_child(_centered("Course terminee !"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 150)
	vb.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for i in res.size():
		var r: Dictionary = res[i]
		var extra := "  😭" if (i == res.size() - 1 and res.size() > 1) else ""
		var row := Label.new()
		row.text = "#%d  %s%s" % [i + 1, GameManager.get_display_name(int(r.get("peer_id", 0))), extra]
		if i < 3:
			row.add_theme_color_override("font_color", Color(1, 0.88, 0.3))
		list.add_child(row)
	if GameManager.current_format == "duo" or GameManager.current_format == "squad":
		var t := Label.new()
		t.text = _team_breakdown()
		t.add_theme_font_size_override("font_size", 18)
		vb.add_child(t)
	_xp_target = 100 + res.size() * 10
	_xp_lbl = Label.new()
	_xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_lbl.add_theme_font_size_override("font_size", 24)
	vb.add_child(_xp_lbl)
	_rank_lbl = Label.new()
	_rank_lbl.text = ""
	_rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_lbl.add_theme_font_size_override("font_size", 20)
	_rank_lbl.add_theme_color_override("font_color", Color(1, 0.88, 0.3))
	vb.add_child(_rank_lbl)
	set_process(true)
	_confetti()
	_buttons(vb, _with_board([["REMATCH 🔁", func() -> void: GameManager.rematch()], ["Menu", func() -> void: GameManager.back_to_menu()]]))

func _podium_card(r: Dictionary, i: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(200, 130 if i > 0 else 150)
	var v := VBoxContainer.new()
	p.add_child(v)
	var medals := ["🥇", "🥈", "🥉"]
	var l := Label.new()
	l.text = "%s  #%d" % [medals[i], i + 1]
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	v.add_child(l)
	var n := Label.new()
	n.text = "%s 🎉" % GameManager.get_display_name(int(r.get("peer_id", 0)))
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	return p

func _team_breakdown() -> String:
	var txt := ""
	for tid in TeamManager.get_team_ranking():
		var members: Array = TeamManager.teams.get(tid, [])
		var parts := PackedStringArray()
		for pid in members:
			parts.append("#%d" % int(TeamManager._finishes.get(pid, 99)))
		txt += "Equipe %d : %s = %.0f pts\n" % [int(tid) + 1, " + ".join(parts), float(TeamManager.team_scores.get(tid, 0.0))]
	return txt

func _centered(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _confetti() -> void:
	var p := CPUParticles2D.new()
	p.amount = 160
	p.lifetime = 2.5
	p.preprocess = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(640, 10)
	p.direction = Vector2(0, 1)
	p.spread = 25.0
	p.gravity = Vector2(0, 220)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = Color(1, 0.85, 0.25)
	p.position = get_viewport_rect().size * Vector2(0.5, 0.05)
	add_child(p)

func _process(delta: float) -> void:
	if _xp_lbl and _xp < _xp_target:
		_xp = mini(_xp_target, _xp + int(240.0 * delta) + 1)
		_xp_lbl.text = "+%d XP  •  +%d 🪙" % [_xp, _xp / 2]

# --- Grand Prix ---

func _build_gp_manche() -> void:
	var vb := _root()
	_title(vb, "🏆  GP — Manche %d/4 : %s" % [GameManager.gp_index + 1, GameManager.map_name(GameManager.current_map_id)])
	var res: Array = GameManager.results
	for i in res.size():
		var r: Dictionary = res[i]
		var pts: int = GameManager.GP_TABLE[mini(i, GameManager.GP_TABLE.size() - 1)]
		var row := Label.new()
		row.text = "#%d  %s  +%d pts" % [i + 1, GameManager.get_display_name(int(r.get("peer_id", 0))), pts]
		if i == 0:
			row.add_theme_color_override("font_color", Color(1, 0.88, 0.3))
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 22)
		vb.add_child(row)
	vb.add_child(_centered("— Classement general —"))
	for s in GameManager.gp_standings():
		var l := Label.new()
		l.text = "%s : %d pts" % [str(s["name"]), int(s["pts"])]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 20)
		vb.add_child(l)
	_rank_lbl = Label.new()
	_rank_lbl.text = ""
	_rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_lbl.add_theme_font_size_override("font_size", 20)
	_rank_lbl.add_theme_color_override("font_color", Color(1, 0.88, 0.3))
	vb.add_child(_rank_lbl)
	_buttons(vb, _with_board([["Manche suivante ▶", func() -> void: GameManager.gp_next()], ["Abandonner", func() -> void: GameManager.back_to_menu()]]))

func _build_champion() -> void:
	var vb := _root()
	_title(vb, "🏆  CHAMPION DU GRAND PRIX  🏆")
	var champ: Array = GameManager.gp_standings()
	for i in champ.size():
		var s: Dictionary = champ[i]
		var medal := "🥇" if i == 0 else ("🥈" if i == 1 else ("🥉" if i == 2 else "  "))
		var l := Label.new()
		l.text = "%s #%d  %s : %d pts" % [medal, i + 1, str(s["name"]), int(s["pts"])]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 26 if i == 0 else 20)
		if i == 0:
			l.add_theme_color_override("font_color", Color(1, 0.88, 0.3))
		vb.add_child(l)
	Audio.play("star")
	_confetti()
	_buttons(vb, _with_board([["Nouveau GP 🔁", func() -> void: GameManager.start_gp_lobby(GameManager.current_format)], ["Menu", func() -> void: GameManager.back_to_menu()]]))

# --- Contre-la-montre ---

func _build_tt() -> void:
	var vb := _root()
	_title(vb, "⏱  CONTRE-LA-MONTRE : %s" % GameManager.map_name(GameManager.current_map_id))
	var t: Dictionary = GameManager.tt_last
	var total := float(t.get("total", 0.0))
	var best := float(t.get("best", total))
	var tl := Label.new()
	tl.text = "Total : %s" % GameManager.fmt_time(total)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_font_size_override("font_size", 34)
	vb.add_child(tl)
	var bl := Label.new()
	bl.text = "Meilleur tour : %s" % GameManager.fmt_time(best)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.add_theme_font_size_override("font_size", 24)
	vb.add_child(bl)
	if bool(t.get("is_record", false)):
		var rec := Label.new()
		rec.text = "🎉 NOUVEAU RECORD ! 🎉"
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rec.add_theme_font_size_override("font_size", 30)
		rec.add_theme_color_override("font_color", Color(0.4, 1, 0.5))
		vb.add_child(rec)
		Audio.play("star")
	else:
		var prev: Dictionary = GameManager.get_tt_best(str(t.get("map", GameManager.current_map_id)))
		if prev.has("total"):
			var rl := Label.new()
			rl.text = "Record : %s" % GameManager.fmt_time(float(prev.get("total", 0.0)))
			rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			rl.add_theme_font_size_override("font_size", 22)
			vb.add_child(rl)
	_rank_lbl = Label.new()
	_rank_lbl.text = ""
	_rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_lbl.add_theme_font_size_override("font_size", 20)
	_rank_lbl.add_theme_color_override("font_color", Color(1, 0.88, 0.3))
	vb.add_child(_rank_lbl)
	_buttons(vb, _with_board([["Recommencer 🔁", func() -> void: GameManager.start_tt(GameManager.current_map_id)], ["Menu", func() -> void: GameManager.back_to_menu()]]))

func _play_anims() -> void:
	var vehicles := get_tree().get_nodes_in_group("vehicles")
	for i in mini(3, vehicles.size()):
		if vehicles[i].has_method("play_celebration"):
			vehicles[i].call("play_celebration")
	if vehicles.size() > 1 and vehicles[vehicles.size() - 1].has_method("play_humiliation"):
		vehicles[vehicles.size() - 1].call("play_humiliation")
