extends Control
## Ecran compte (phase AUTH) : gate / inscription / OTP / connexion / mot de passe oublie.
## Meme pattern code-built que les autres ecrans. Invite intact : aucune requete
## reseau sans action explicite, et l'absence de config n'empeche jamais de jouer.

const SUB_GATE := 0
const SUB_SIGNUP := 1
const SUB_VERIFY := 2
const SUB_SIGNIN := 3
const SUB_FORGOT := 4

var _sub: int = SUB_GATE
var _client: SupaAuth = null
var _has_config := false
var _busy := false
var _pending_email := ""
var _resend_cd := 0.0
var _resend_btn: Button = null
var _done_lbl: Label = null
var _err_lbl: Label = null
var _center: CenterContainer = null
var _box: VBoxContainer = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_client = SupaAuth.new()
	add_child(_client)
	_has_config = _client.configure()
	_client.auth_ok.connect(_on_ok)
	_client.auth_fail.connect(_on_fail)
	_client.signed_out.connect(_on_signed_out)
	_build_chrome()
	_show_sub(SUB_GATE)

func _build_chrome() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.14, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var back := Button.new()
	back.text = "← Retour"
	back.custom_minimum_size = Vector2(140, 48)
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.position = Vector2(12, 12)
	back.pressed.connect(func() -> void:
		if _sub == SUB_GATE:
			GameManager.change_phase(GameManager.MatchPhase.MENU)
		else:
			_show_sub(SUB_GATE)
	)
	add_child(back)
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_center)

func _show_sub(n: int) -> void:
	_sub = n
	_resend_cd = 0.0
	_set_busy(false)
	if is_instance_valid(_box):
		_center.remove_child(_box)
		_box.queue_free()
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 10)
	_center.add_child(_box)
	match _sub:
		SUB_GATE:
			_build_gate(_box)
		SUB_SIGNUP:
			_build_signup(_box)
		SUB_VERIFY:
			_build_verify(_box)
		SUB_SIGNIN:
			_build_signin(_box)
		SUB_FORGOT:
			_build_forgot(_box)
	_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_box, "modulate:a", 1.0, 0.25)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _sub == SUB_GATE:
			GameManager.change_phase(GameManager.MatchPhase.MENU)
		else:
			_show_sub(SUB_GATE)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _resend_cd > 0.0:
		_resend_cd = maxf(0.0, _resend_cd - delta)
		if is_instance_valid(_resend_btn):
			if _resend_cd > 0.0:
				_resend_btn.disabled = true
				_resend_btn.text = "Renvoyer dans %ds" % int(ceil(_resend_cd))
			else:
				_resend_btn.disabled = false
				_resend_btn.text = "RENVOYER LE CODE"

func _exit_tree() -> void:
	if _client != null:
		_client.cancel_oauth()

## --- Construction ---

func _title(vb: VBoxContainer, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", Palette.GOLD)
	vb.add_child(l)

func _field(vb: VBoxContainer, hint: String, secret: bool) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = hint
	le.custom_minimum_size = Vector2(320, 48)
	le.secret = secret
	le.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(le)
	return le

func _button(vb: VBoxContainer, t: String, wide: float = 260.0) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(wide, 56)
	b.add_theme_font_size_override("font_size", 22)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(b)
	vb.add_child(row)
	return b

func _error_label(vb: VBoxContainer) -> Label:
	_err_lbl = Label.new()
	_err_lbl.text = ""
	_err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_err_lbl.add_theme_font_size_override("font_size", 16)
	_err_lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	_err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_err_lbl.custom_minimum_size = Vector2(420, 24)
	vb.add_child(_err_lbl)
	return _err_lbl

func _social_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PANEL
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Palette.MUTED
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_right = 12
	sb.corner_radius_bottom_left = 12
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb

func _build_gate(vb: VBoxContainer) -> void:
	_title(vb, "COMPTE")
	if SupaAuth.is_signed_in():
		var info := Label.new()
		info.text = "Connecté : " + SupaAuth.session_email()
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.add_theme_font_size_override("font_size", 20)
		vb.add_child(info)
		if SupaAuth.has_linked_identities():
			var link := Label.new()
			link.text = "Comptes liés ✓"
			link.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			link.add_theme_color_override("font_color", Palette.GOLD)
			vb.add_child(link)
		var out := _button(vb, "SE DÉCONNECTER")
		out.pressed.connect(func() -> void:
			_set_busy(true)
			_client.sign_out()
		)
		var go := _button(vb, "CONTINUER")
		go.pressed.connect(func() -> void: GameManager.change_phase(GameManager.MatchPhase.MENU))
	else:
		var login := _button(vb, "SE CONNECTER")
		login.pressed.connect(func() -> void: _show_sub(SUB_SIGNIN))
		var reg := _button(vb, "CRÉER UN COMPTE")
		reg.pressed.connect(func() -> void: _show_sub(SUB_SIGNUP))
		var guest := _button(vb, "CONTINUER SANS COMPTE")
		guest.pressed.connect(func() -> void: GameManager.change_phase(GameManager.MatchPhase.MENU))
	if not _has_config:
		_notice(vb, "Configuration Supabase absente — jeu hors-ligne uniquement.")

func _build_signup(vb: VBoxContainer) -> void:
	_title(vb, "CRÉER UN COMPTE")
	var mail := _field(vb, "Email", false)
	var pwd := _field(vb, "Mot de passe", true)
	_error_label(vb)
	var go := _button(vb, "S'INSCRIRE")
	go.pressed.connect(func() -> void:
		if not _guard_config():
			return
		_pending_email = mail.text.strip_edges()
		_set_busy(true)
		_client.sign_up(_pending_email, pwd.text)
	)
	_guard_notice(vb)

func _build_verify(vb: VBoxContainer) -> void:
	_title(vb, "VÉRIFICATION")
	var info := Label.new()
	info.text = "Code envoyé à " + _pending_email
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(info)
	var code := _field(vb, "Code à 6 chiffres", false)
	code.max_length = 6
	_error_label(vb)
	var go := _button(vb, "VALIDER")
	go.pressed.connect(func() -> void:
		if not _guard_config():
			return
		_set_busy(true)
		_client.verify_email_otp(_pending_email, code.text)
	)
	_resend_btn = Button.new()
	_resend_btn.text = "RENVOYER LE CODE"
	_resend_btn.custom_minimum_size = Vector2(260, 48)
	_resend_btn.pressed.connect(func() -> void:
		if not _guard_config():
			return
		_set_busy(true)
		_client.sign_up(_pending_email, "")
		_resend_cd = 60.0
	)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_resend_btn)
	vb.add_child(row)
	_guard_notice(vb)

func _build_signin(vb: VBoxContainer) -> void:
	_title(vb, "SE CONNECTER")
	var mail := _field(vb, "Email", false)
	var pwd := _field(vb, "Mot de passe", true)
	_error_label(vb)
	var go := _button(vb, "SE CONNECTER")
	go.pressed.connect(func() -> void:
		if not _guard_config():
			return
		_set_busy(true)
		_client.sign_in(mail.text.strip_edges(), pwd.text)
	)
	for entry in [["google", "Continuer avec Google"], ["discord", "Continuer avec Discord"]]:
		var prov: String = entry[0]
		var b := Button.new()
		b.text = str(entry[1])
		b.custom_minimum_size = Vector2(320, 56)
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_stylebox_override("normal", _social_box())
		b.pressed.connect(_on_social.bind(prov))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(b)
		vb.add_child(row)
	var forgot := Button.new()
	forgot.text = "Mot de passe oublié ?"
	forgot.custom_minimum_size = Vector2(260, 40)
	forgot.pressed.connect(func() -> void: _show_sub(SUB_FORGOT))
	var frow := HBoxContainer.new()
	frow.alignment = BoxContainer.ALIGNMENT_CENTER
	frow.add_child(forgot)
	vb.add_child(frow)
	_guard_notice(vb)

func _build_forgot(vb: VBoxContainer) -> void:
	_title(vb, "MOT DE PASSE OUBLIÉ")
	var mail := _field(vb, "Email", false)
	_error_label(vb)
	var done := Label.new()
	done.text = ""
	done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done.add_theme_color_override("font_color", Palette.GOLD)
	vb.add_child(done)
	_done_lbl = done
	var go := _button(vb, "ENVOYER")
	go.pressed.connect(func() -> void:
		if not _guard_config():
			return
		_set_busy(true)
		done.text = ""
		_client.reset_password(mail.text.strip_edges())
	)
	_guard_notice(vb)

## --- Logique ---

func _on_social(provider: String) -> void:
	if not _guard_config():
		return
	_set_busy(true)
	_client.sign_in_oauth(provider)

func _guard_config() -> bool:
	if _has_config:
		return true
	_show_error("Configuration Supabase absente — jeu hors-ligne uniquement.")
	return false

func _guard_notice(vb: VBoxContainer) -> void:
	if not _has_config:
		_notice(vb, "Configuration Supabase absente — jeu hors-ligne uniquement.")

func _notice(vb: VBoxContainer, t: String) -> void:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Palette.MUTED)
	vb.add_child(l)

func _show_error(t: String) -> void:
	if is_instance_valid(_err_lbl):
		_err_lbl.text = t

func _set_busy(on: bool) -> void:
	_busy = on
	if not is_instance_valid(_box):
		return
	for b in _box.find_children("*", "Button", true, false):
		(b as Button).disabled = on

func _on_ok(user: Dictionary) -> void:
	_set_busy(false)
	if bool(user.get("email_sent", false)):
		if is_instance_valid(_done_lbl):
			_done_lbl.text = "Email envoyé — vérifiez votre boîte."
		return
	if bool(user.get("needs_confirm", false)):
		_resend_cd = 60.0
		_show_sub(SUB_VERIFY)
		return
	# Session établie (inscription auto-confirmée, connexion, OTP, OAuth).
	GameManager.change_phase(GameManager.MatchPhase.MENU)

func _on_fail(message: String) -> void:
	_set_busy(false)
	_show_error(message)

func _on_signed_out() -> void:
	_set_busy(false)
	_show_sub(SUB_GATE)
