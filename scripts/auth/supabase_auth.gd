class_name SupaAuth
extends Node
## Client Auth Supabase natif Godot 4 (sans addon) : inscription/connexion
## email+password, OTP email 6 chiffres (type "signup"), reset, OAuth PKCE
## (Google/Discord) via navigateur + callback localhost.
## Config lue dans res://supabase_config.json (NON commite, voir .example.json).
## Aucun appel reseau tant qu'une methode n'est pas appelee (invite hors-ligne safe).
## Session en memoire seule (effacee a la fermeture du jeu).

signal auth_ok(user: Dictionary)
signal auth_fail(message: String)
signal signed_out()
signal db_ok(tag: String, data: Variant)
signal db_fail(tag: String, message: String)

const CONFIG_PATH := "res://supabase_config.json"
const OAUTH_PORT := 3000
const OAUTH_TIMEOUT := 300.0
const OAUTH_PROVIDERS := ["google", "discord"]

## Session partagee (survit aux ecrans, meurt avec le processus).
static var session := {}

var supabase_url := ""
var anon_key := ""
var configured := false

var _busy := false
var _op := ""
var _op_email := ""
var _http: HTTPRequest = null
var _oauth_server: TCPServer = null
var _oauth_poll := false
var _oauth_elapsed := 0.0
var _oauth_verifier := ""

## --- Session statique ---

static func is_signed_in() -> bool:
	return session.has("access_token") and str(session.get("access_token", "")) != ""

static func session_email() -> String:
	return str(session.get("email", ""))

static func has_linked_identities() -> bool:
	var ids: Array = session.get("identities", [])
	var kinds := {}
	for entry in ids:
		if entry is Dictionary:
			kinds[str(entry.get("provider", ""))] = true
	return kinds.has("email") and ids.size() > 1

static func clear_session() -> void:
	session = {}

## --- Config ---

func configure() -> bool:
	supabase_url = ""
	anon_key = ""
	configured = false
	if not FileAccess.file_exists(CONFIG_PATH):
		return false
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		return false
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return false
	supabase_url = str(data.get("supabaseUrl", "")).trim_suffix("/")
	anon_key = str(data.get("supabaseKey", ""))
	configured = supabase_url.begins_with("http") and anon_key != ""
	return configured

func _headers(token: String = "") -> PackedStringArray:
	var h := PackedStringArray(["Content-Type: application/json", "apikey: " + anon_key])
	if token != "":
		h.append("Authorization: Bearer " + token)
	return h

## --- API publique (une requete a la fois, boutons a desactiver pendant) ---

func is_busy() -> bool:
	return _busy

func sign_up(email: String, password: String) -> void:
	_send("SIGNUP", HTTPClient.METHOD_POST, "/auth/v1/signup", {"email": email, "password": password}, email)

func verify_email_otp(email: String, token: String) -> void:
	_send("VERIFY", HTTPClient.METHOD_POST, "/auth/v1/verify", {"email": email, "token": token.strip_edges(), "type": "signup"}, email)

func sign_in(email: String, password: String) -> void:
	_send("SIGNIN", HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {"email": email, "password": password}, email)

func reset_password(email: String) -> void:
	_send("RECOVER", HTTPClient.METHOD_POST, "/auth/v1/recover", {"email": email}, email)

func sign_out() -> void:
	var token := str(session.get("access_token", ""))
	if token == "":
		clear_session()
		signed_out.emit()
		return
	_send("LOGOUT", HTTPClient.METHOD_POST, "/auth/v1/logout", {}, "")

## --- Tables REST generiques (classement, etc.) ---
## Requetes independantes (pas de _busy) : plusieurs GET peuvent se chevaucher.

func db_get(path: String, tag: String, extra_headers: PackedStringArray = []) -> void:
	if not configured:
		db_fail.emit(tag, "Configuration Supabase absente — jeu hors-ligne uniquement.")
		return
	_db_send("DB_GET", HTTPClient.METHOD_GET, path, {}, extra_headers, tag)

func db_post(path: String, payload: Dictionary, tag: String) -> void:
	if not configured:
		db_fail.emit(tag, "Configuration Supabase absente — jeu hors-ligne uniquement.")
		return
	_db_send("DB_POST", HTTPClient.METHOD_POST, path, payload, [], tag)

func _db_send(op: String, method: int, path: String, payload: Dictionary, extra: PackedStringArray, tag: String) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	var h := _headers()
	for e in extra:
		h.append(e)
	req.request_completed.connect(_on_db_done.bind(op, tag, req))
	if method == HTTPClient.METHOD_GET:
		req.request(supabase_url + path, h, method)
	else:
		req.request(supabase_url + path, h, method, JSON.stringify(payload))

func _on_db_done(result: int, code: int, resp_headers: PackedStringArray, body: PackedByteArray, op: String, tag: String, req: HTTPRequest) -> void:
	var payload_json: Variant = {}
	var raw := body.get_string_from_utf8()
	if raw != "":
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary or parsed is Array:
			payload_json = parsed
	if is_instance_valid(req):
		req.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		var msg := {}
		if payload_json is Dictionary:
			msg = payload_json
		db_fail.emit(tag, _fr_error(msg, result, code))
		return
	if op == "DB_RANK":
		db_ok.emit(tag, {"total": _parse_count(resp_headers)})
	else:
		db_ok.emit(tag, payload_json)

func _parse_count(headers: PackedStringArray) -> int:
	for h in headers:
		var parts := h.split(":", true, 1)
		if parts.size() == 2 and parts[0].strip_edges().to_lower() == "content-range":
			var segs := parts[1].strip_edges().split("/")
			if segs.size() == 2:
				return maxi(0, int(segs[1]))
	return 0

func sign_in_oauth(provider: String) -> void:
	var p := provider.to_lower()
	if not (p in OAUTH_PROVIDERS):
		auth_fail.emit("Fournisseur non pris en charge.")
		return
	if not configured:
		auth_fail.emit("Configuration Supabase absente — jeu hors-ligne uniquement.")
		return
	if _busy:
		auth_fail.emit("Patientez — requête déjà en cours.")
		return
	cancel_oauth()
	var pair: Array = SupaAuth.pkce_pair()
	_oauth_verifier = str(pair[0])
	_oauth_server = TCPServer.new()
	var err := _oauth_server.listen(OAUTH_PORT, "127.0.0.1")
	if err != OK:
		_oauth_server = null
		auth_fail.emit("Port local %d occupé — fermez l'autre instance." % OAUTH_PORT)
		return
	var url := supabase_url + "/auth/v1/authorize?provider=" + p \
		+ "&redirect_to=http://localhost:" + str(OAUTH_PORT) + "/" \
		+ "&response_type=code&code_challenge=" + str(pair[1]) + "&code_challenge_method=S256"
	_oauth_poll = true
	_oauth_elapsed = 0.0
	OS.shell_open(url)

func cancel_oauth() -> void:
	_oauth_poll = false
	_oauth_elapsed = 0.0
	if _oauth_server != null:
		_oauth_server.stop()
		_oauth_server = null

func _exit_tree() -> void:
	cancel_oauth()

func _process(delta: float) -> void:
	if not _oauth_poll or _oauth_server == null:
		return
	_oauth_elapsed += delta
	if _oauth_elapsed > OAUTH_TIMEOUT:
		cancel_oauth()
		auth_fail.emit("Délai dépassé — relancez la connexion.")
		return
	var peer := _oauth_server.take_connection()
	if peer == null:
		return
	var text := ""
	var guard := 0
	while peer.get_available_bytes() > 0 and guard < 32:
		var chunk: Array = peer.get_data(peer.get_available_bytes())
		if int(chunk[0]) != OK:
			break
		text += (chunk[1] as PackedByteArray).get_string_from_utf8()
		guard += 1
	var params := SupaAuth.parse_oauth_callback(text)
	if params.has("code"):
		_respond_browser(peer, true)
		var code := str(params["code"])
		cancel_oauth()
		_send("PKCE", HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=pkce",
			{"auth_code": code, "code_verifier": _oauth_verifier}, "")
	elif params.has("error"):
		_respond_browser(peer, false)
		var desc := str(params.get("error_description", params.get("error", "")))
		cancel_oauth()
		if desc == "":
			desc = "Connexion annulée."
		auth_fail.emit(desc)
	# Sinon (favicon, etc.) : on ignore et on continue d'ecouter.

func _respond_browser(peer: StreamPeer, ok: bool) -> void:
	var msg := "Connexion réussie — retournez dans le jeu."
	if not ok:
		msg = "Connexion annulée — retournez dans le jeu."
	var html := "<html><body><h2>" + msg + "</h2></body></html>"
	var body := html.to_utf8_buffer()
	var head := "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % body.size()
	peer.put_data((head + html).to_utf8_buffer())
	peer.disconnect_from_host()

## --- Requetes ---

func _send(op: String, method: int, path: String, payload: Dictionary, email: String) -> void:
	if not configured:
		auth_fail.emit("Configuration Supabase absente — jeu hors-ligne uniquement.")
		return
	if _busy:
		auth_fail.emit("Patientez — requête déjà en cours.")
		return
	_busy = true
	_op = op
	_op_email = email
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_done.bind(op))
	_http.request(supabase_url + path, _headers(), method, JSON.stringify(payload))

func _on_done(_result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, op: String) -> void:
	var result: int = _result
	var data := {}
	var raw := body.get_string_from_utf8()
	if raw != "":
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary:
			data = parsed
	var ok_code := code >= 200 and code < 300
	if _http != null:
		_http.queue_free()
		_http = null
	if result != HTTPRequest.RESULT_SUCCESS or not ok_code:
		_busy = false
		auth_fail.emit(_fr_error(data, result, code))
		return
	match op:
		"SIGNUP":
			if str(data.get("access_token", "")) != "":
				_store_session(data)
				_chain_user()
			else:
				_busy = false
				auth_ok.emit({"email": _op_email, "needs_confirm": true})
		"VERIFY", "SIGNIN", "PKCE":
			_store_session(data)
			_chain_user()
		"RECOVER":
			_busy = false
			auth_ok.emit({"email": _op_email, "email_sent": true})
		"GET_USER":
			_merge_user(data)
			_busy = false
			auth_ok.emit({"id": str(session.get("user_id", "")), "email": str(session.get("email", "")),
				"linked": has_linked_identities(), "needs_confirm": false})
		"LOGOUT":
			clear_session()
			_busy = false
			signed_out.emit()
		_:
			_busy = false

func _chain_user() -> void:
	# _busy reste vrai jusqu'au GET_USER final (boutons desactives entre-temps).
	var token := str(session.get("access_token", ""))
	var req := HTTPRequest.new()
	add_child(req)
	_http = req
	req.request_completed.connect(_on_done.bind("GET_USER"))
	req.request(supabase_url + "/auth/v1/user", _headers(token), HTTPClient.METHOD_GET)

func _store_session(data: Dictionary) -> void:
	session["access_token"] = str(data.get("access_token", ""))
	session["refresh_token"] = str(data.get("refresh_token", ""))
	session["expires_in"] = float(data.get("expires_in", 0.0))

func _merge_user(data: Dictionary) -> void:
	session["user_id"] = str(data.get("id", ""))
	session["email"] = str(data.get("email", ""))
	var ids: Array = data.get("identities", [])
	session["identities"] = ids
	session["linked"] = has_linked_identities()

func _fr_error(data: Dictionary, result: int, code: int) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		return "Pas de connexion réseau — vérifiez votre connexion."
	var raw := str(data.get("msg", data.get("message", data.get("error_description", data.get("error", "")))))
	var low := raw.to_lower()
	if low.contains("user already registered") or low.contains("already exists") or low.contains("already been registered"):
		return "Un compte existe déjà avec cet email — connectez-vous."
	if low.contains("invalid login credentials"):
		return "Email ou mot de passe incorrect."
	if low.contains("email rate limit"):
		return "Trop de tentatives — réessayez dans une minute."
	if low.contains("expired") or (low.contains("invalid") and low.contains("token")):
		return "Code expiré ou invalide — demandez-en un nouveau."
	if raw == "":
		return "Erreur réseau (%d)." % code
	return raw

## --- Helpers purs (testables sans instance) ---

static func pkce_pair() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pool := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
	var v := ""
	for i in 64:
		v += pool.substr(rng.randi_range(0, pool.length() - 1), 1)
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(v.to_utf8_buffer())
	return [v, SupaAuth.b64url(h.finish())]

static func b64url(data: PackedByteArray) -> String:
	var s := Marshalls.raw_to_base64(data)
	s = s.replace("+", "-").replace("/", "_")
	while s.ends_with("="):
		s = s.trim_suffix("=")
	return s

static func parse_oauth_callback(request_text: String) -> Dictionary:
	var out := {}
	var lines := request_text.split("\r\n")
	if lines.is_empty():
		return out
	var parts := lines[0].split(" ")
	if parts.size() < 2:
		return out
	var target: String = parts[1]
	var qi := target.find("?")
	if qi == -1:
		return out
	for kv in target.substr(qi + 1).split("&"):
		var epos := kv.find("=")
		if epos == -1:
			continue
		out[kv.substr(0, epos)] = kv.substr(epos + 1).uri_decode()
	return out
