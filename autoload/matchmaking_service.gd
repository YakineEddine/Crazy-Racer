extends Node
## MatchmakingService — file aleatoire par format (01 §4).
## En prototype local : forme un lobby des que le quota est atteint.

signal lobby_formed(room_code: String)

var _queues: Dictionary = {} ## { format: [peer_id,...] }

func enqueue(peer_id: int, format: String) -> void:
	if not _queues.has(format):
		_queues[format] = []
	if not peer_id in _queues[format]:
		_queues[format].append(peer_id)
	_try_form_lobby(format)

func dequeue(peer_id: int) -> void:
	for fmt in _queues:
		_queues[fmt].erase(peer_id)

func _score_player(_peer_id: int) -> float:
	# Stub equilibrage skill/ping (stretch goal) — signature reservee.
	return 0.0

func _required_count(format: String) -> int:
	match format:
		"1v1":
			return 2
		"duo":
			return 4
		"squad":
			return 8
		"ffa":
			return 4
	return 2

func _try_form_lobby(format: String) -> void:
	var q: Array = _queues.get(format, [])
	var need := _required_count(format)
	if q.size() < need:
		return
	# En local : on transfere la file dans LobbyManager.
	GameManager.current_format = format
	LobbyManager.create_room(format)
	for pid in q:
		if not LobbyManager.players.has(pid):
			LobbyManager.players[pid] = {"name": "Joueur%d" % pid, "vehicle_class": "kart", "character_id": "human", "ready": true, "is_bot": false}
	_queues[format] = []
	var code: String = LobbyManager.room_code
	lobby_formed.emit(code)
