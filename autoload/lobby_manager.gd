extends Node
## LobbyManager — cycle de vie des rooms (01 §2).
## players: { peer_id: { name, vehicle_class, character_id, ready, is_bot } }

signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal all_players_ready()
signal lobby_updated()

var room_code: String = ""
var players: Dictionary = {}
var max_players: int = 16
var is_host: bool = true

const FORMAT_SLOTS := {"1v1": 2, "duo": 2, "squad": 4, "ffa": 1}

func _ready() -> void:
	var self_id := multiplayer.get_unique_id()
	# En mode hors-ligne get_unique_id() vaut 1 : on s'enregistre en local.
	if not players.has(self_id):
		players[self_id] = {"name": "Joueur", "vehicle_class": "kart", "character_id": "human", "ready": false, "is_bot": false}

func create_room(format: String) -> String:
	room_code = _gen_code()
	is_host = true
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_sync_lobby.rpc(room_code, players)
	lobby_updated.emit()
	return room_code

func _gen_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var code := ""
	for i in 4:
		code += str(rng.randi_range(0, 9))
	# Collision check simplifie (hote local).
	return code

func join_room(code: String) -> bool:
	if code.length() != 4:
		return false
	if players.size() >= max_players:
		return false
	var self_id := multiplayer.get_unique_id()
	players[self_id] = {"name": "Joueur", "vehicle_class": "kart", "character_id": "human", "ready": false, "is_bot": false}
	room_code = code
	player_joined.emit(self_id)
	lobby_updated.emit()
	return true

func set_ready(peer_id: int, ready: bool) -> void:
	if players.has(peer_id):
		players[peer_id]["ready"] = ready
		lobby_updated.emit()
		if can_start():
			all_players_ready.emit()

func set_vehicle(peer_id: int, vehicle_class: String) -> void:
	if players.has(peer_id):
		players[peer_id]["vehicle_class"] = vehicle_class
		lobby_updated.emit()

func set_character(peer_id: int, character_id: String) -> void:
	if players.has(peer_id):
		players[peer_id]["character_id"] = character_id
		lobby_updated.emit()

func can_start() -> bool:
	if players.is_empty():
		return false
	for pid in players:
		if not bool(players[pid].get("ready", false)):
			return false
	return _slots_valid_for_format()

func _slots_valid_for_format() -> bool:
	var n := players.size()
	var fmt: String = GameManager.current_format
	match fmt:
		"1v1":
			return n == 2
		"duo":
			return n >= 2 and n % 2 == 0 and n <= 16
		"squad":
			return n >= 4 and n % 4 == 0 and n <= 16
		"ffa":
			return n >= 1 and n <= 16
	return false

## Remplissage bots (flag design ouvert : tolere is_bot, remplit en solo/room privee).
func ensure_bot_fill() -> void:
	var fmt: String = GameManager.current_format
	var target := 4
	if fmt == "1v1":
		target = 2
	elif fmt == "ffa":
		target = 6
	var bot_names := ["Bot Croco", "Bot Pingouin", "Bot Poulet", "Bot Turbo", "Bot Banane", "Bot Fusee"]
	var bot_classes := ["kart", "car", "truck", "motorcycle", "bicycle", "sport", "taxi", "suv"]
	var bot_chars := ["crocodile", "penguin", "chicken", "human", "cow", "pig", "sheep", "horse"]
	var i := 0
	while players.size() < target:
		var bid := -(100 + i) ## ids negatifs = bots locaux
		players[bid] = {
			"name": bot_names[i % bot_names.size()],
			"vehicle_class": bot_classes[i % bot_classes.size()],
			"character_id": bot_chars[i % bot_chars.size()],
			"ready": true,
			"is_bot": true,
		}
		i += 1
	lobby_updated.emit()

func get_all_peer_ids() -> Array:
	return players.keys()

func remove_player(peer_id: int) -> void:
	if players.has(peer_id):
		players.erase(peer_id)
		player_left.emit(peer_id)
		# Promotion hote : le prochain peer devient hote (simplifie).
		if peer_id == multiplayer.get_unique_id():
			is_host = false
		lobby_updated.emit()

func leave_all() -> void:
	var self_id := multiplayer.get_unique_id()
	players.clear()
	room_code = ""
	players[self_id] = {"name": "Joueur", "vehicle_class": "kart", "character_id": "human", "ready": false, "is_bot": false}
	lobby_updated.emit()

@rpc("authority", "call_local", "reliable")
func _sync_lobby(code: String, data: Dictionary) -> void:
	if multiplayer.is_server():
		return
	room_code = code
	players = data
	lobby_updated.emit()
