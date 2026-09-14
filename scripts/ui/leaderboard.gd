extends Control
## Classement en ligne (UI_UX §6) : top 10 par map + rang perso hors top 10.
## Invites : pas de top public ici (seulement leur rang, sur l'ecran resultats).

var _client: SupaAuth = null
var _has_config := false
var _list: VBoxContainer = null
var _info: Label = null
var _top: Array = []
var _own_rank := 0
var _own_name := ""
var _map := "map1_neon"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_map = GameManager.board_map_id
	_client = SupaAuth.new()
	add_child(_client)
	_has_config = _client.configure()
	_client.db_ok.connect(_on_db)
	_client.db_fail.connect(_on_fail)
	_build()
	if not _has_config or not SupaAuth.is_signed_in():
		_info.text = "Connectez-vous pour voir le classement."
		return
	_info.text = "Chargement…"
	_client.db_get(BoardClient.top_path(_map), "top")
	_client.db_get(BoardClient.mine_path(_map, str(SupaAuth.session.get("user_id", ""))), "mine")

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.14, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var back := Button.new()
	back.text = "← Retour"
	back.custom_minimum_size = Vector2(140, 48)
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.position = Vector2(12, 12)
	back.pressed.connect(func() -> void: GameManager.change_phase(GameManager.board_return))
	add_child(back)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 6)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(vb)
	add_child(center)
	var title := Label.new()
	title.text = "🏆 CLASSEMENT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Palette.GOLD)
	vb.add_child(title)
	var map_lbl := Label.new()
	map_lbl.text = GameManager.map_name(_map)
	map_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_lbl.add_theme_font_size_override("font_size", 22)
	map_lbl.add_theme_color_override("font_color", Palette.SKY)
	vb.add_child(map_lbl)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 330)
	vb.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	_info = Label.new()
	_info.text = ""
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 16)
	_info.add_theme_color_override("font_color", Palette.MUTED)
	vb.add_child(_info)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameManager.change_phase(GameManager.board_return)
		get_viewport().set_input_as_handled()

func _on_db(tag: String, data: Variant) -> void:
	if tag == "top":
		_top = BoardClient.parse_top_rows(data)
		_render()
	elif tag == "mine":
		var mine := BoardClient.parse_mine(data)
		if mine.is_empty():
			_own_rank = 0
			_render()
		else:
			_own_name = str(mine.get("name", ""))
			_client.db_get(BoardClient.rank_path(_map, int(mine.get("total_ms", 0))), "rank", ["Prefer: count=exact"])
	elif tag == "rank":
		var total := 0
		if data is Dictionary:
			total = int(data.get("total", 0))
		_own_rank = total + 1
		_render()

func _on_fail(tag: String, _message: String) -> void:
	if tag == "top" and _list != null and _list.get_child_count() == 0:
		_info.text = "Classement indisponible hors-ligne."
	# Rang perso manquant : simplement pas de ligne (comportement invite).

func _render() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var lines: Array = BoardClient.format_board(_top, _own_rank, _own_name)
	if lines.is_empty():
		if _own_rank <= 0:
			_info.text = "Aucun temps sur ce circuit pour l'instant."
		return
	for line in lines:
		if str(line) == "":
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 12)
			_list.add_child(gap)
			continue
		var l := Label.new()
		l.text = str(line)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 22)
		if _own_rank > 0 and str(line) == BoardClient.format_row(_own_rank, _own_name):
			l.add_theme_color_override("font_color", Palette.GOLD)
		_list.add_child(l)
	if not lines.is_empty():
		_info.text = ""
