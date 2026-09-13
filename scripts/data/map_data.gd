class_name MapData
extends Resource
## Metadata par map (03 §1). Poids des chaos events par map.

@export var map_id: String = "map1_neon"
@export var display_name: String = "Neon Circuit City"
@export var checkpoint_count: int = 4
@export var shortcut_description: String = ""
@export var weighted_events: Dictionary = {} ## { event_id(String): weight(float) }
@export var scene_path: String = "res://scenes/maps/map1_neon_circuit_city.tscn"
@export var theme_color_ground: Color = Color(0.08, 0.08, 0.16)
@export var theme_color_track: Color = Color(0.15, 0.15, 0.28)
@export var theme_color_wall: Color = Color(1.0, 0.18, 0.53)
@export var laps_to_win: int = 3
