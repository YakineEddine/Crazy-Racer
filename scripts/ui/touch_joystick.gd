extends Control
## Joystick tactile une main (04 §5) : ecrit directement dans le vehicule local.
## Thumb zones : joystick bas-gauche, bouton item bas-droite (dans race_hud).

signal steered(value: float)

var radius: float = 90.0
var knob_radius: float = 34.0
var value: float = 0.0 ## -1..1
var _touch_id: int = -1
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(200, 200)
	_center = size / 2.0
	_knob = _center
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1:
			_touch_id = event.index
			_center = event.position
			_knob = event.position
			queue_redraw()
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -1
			value = 0.0
			_knob = size / 2.0
			steered.emit(0.0)
			_push_to_vehicle(0.0)
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == _touch_id:
		var d: Vector2 = event.position - _center
		d.x = clampf(d.x, -radius, radius)
		d.y = clampf(d.y, -radius, radius)
		_knob = _center + d
		value = clampf(d.x / radius, -1.0, 1.0)
		steered.emit(value)
		_push_to_vehicle(value)
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_center = event.position
			_knob = event.position
		else:
			value = 0.0
			_knob = size / 2.0
			_push_to_vehicle(0.0)
		queue_redraw()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var d: Vector2 = event.position - _center
		d.x = clampf(d.x, -radius, radius)
		_knob = _center + Vector2(d.x, clampf(d.y, -radius, radius))
		value = clampf(d.x / radius, -1.0, 1.0)
		_push_to_vehicle(value)
		queue_redraw()

func _push_to_vehicle(v: float) -> void:
	var p := get_tree().get_first_node_in_group("local_player")
	if p and p.get("touch_steer") != null:
		p.set("touch_steer", v)

func _draw() -> void:
	var c := size / 2.0 if _touch_id == -1 else _center
	# Base.
	draw_circle(c, radius, Color(1, 1, 1, 0.15))
	draw_arc(c, radius, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
	# Knob.
	var k := _knob if _touch_id != -1 else c + Vector2(value * radius, 0)
	draw_circle(k, knob_radius, Color(1, 0.18, 0.53, 0.8))
	draw_arc(k, knob_radius, 0, TAU, 32, Color.WHITE, 2.0)
