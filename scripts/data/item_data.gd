class_name ItemData
extends Resource
## Donnees par item (02 §4). Pipeline generique : jamais de switch hardcode sur les ids.

@export var id: String = "banana_boost"
@export var display_name: String = "Banana Super Boost"
@export var description: String = ""
@export var pickup_rarity: float = 1.0
@export var effect_duration: float = 4.0
@export var cooldown: float = 1.0
@export var icon_color: Color = Color(1.0, 0.9, 0.2)
@export var is_self_target: bool = false ## true = boost, false = offensif (nearest-ahead)
