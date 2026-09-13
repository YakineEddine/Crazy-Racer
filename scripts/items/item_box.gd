extends Area3D
## Boite a item (02 §5) : groupe item_box, respawn apres N secondes.

@export var respawn_delay: float = 5.0
var _active: bool = true
var _mesh: MeshInstance3D = null
var _t: float = 0.0

func _ready() -> void:
	add_to_group("item_box")
	body_entered.connect(_on_body)
	_mesh = get_node_or_null("Mesh") as MeshInstance3D
	# Tourne en permanence (spec asset).
	set_process(true)

func _process(delta: float) -> void:
	_t += delta
	if _mesh and _active:
		_mesh.rotation.y += delta * 2.0
		_mesh.position.y = 1.0 + sin(_t * 3.0) * 0.15

func try_pickup(vehicle: Node) -> String:
	if not _active:
		return ""
	if GameManager.mode == "tt":
		return "" ## contre-la-montre : pas d'objets
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		var sys := get_tree().get_first_node_in_group("item_system")
		var id := "mushroom"
		if sys and sys.has_method("roll_item"):
			id = str(sys.call("roll_item"))
		_hide_and_respawn()
		if multiplayer.has_multiplayer_peer():
			_notify_pickup.rpc(vehicle.get_path(), id)
		# Hors-ligne : tout vehicule simule (bots inclus) recoit l'objet.
		return id if (_is_local_vehicle(vehicle) or not multiplayer.has_multiplayer_peer()) else ""
	return ""

func _is_local_vehicle(v: Node) -> bool:
	return v.is_in_group("local_player") or not multiplayer.has_multiplayer_peer()

func _on_body(b: Node3D) -> void:
	if b.is_in_group("vehicles") and b.has_method("start_roulette"):
		var got: String = try_pickup(b)
		if got != "" and (b.is_in_group("local_player") or not multiplayer.has_multiplayer_peer()):
			b.call("start_roulette", got)

@rpc("authority", "call_local", "reliable")
func _notify_pickup(vehicle_path: NodePath, item_id: String) -> void:
	if multiplayer.is_server():
		return
	var v := get_node_or_null(vehicle_path)
	if v and v.has_method("start_roulette") and v.is_in_group("local_player"):
		v.call("start_roulette", item_id)

func _hide_and_respawn() -> void:
	_active = false
	visible = false
	monitoring = false
	await get_tree().create_timer(respawn_delay).timeout
	_active = true
	visible = true
	monitoring = true
