class_name KartStats
extends Resource
## Stats par classe de vehicule (02_VEHICLES_AND_ITEMS.md §2).
## Un .tres par classe dans assets/resources/. Les skins reutilisent le meme stats.

@export var display_name: String = "Kart"
@export var top_speed: float = 22.0
@export var acceleration: float = 14.0
@export var turning_radius: float = 0.6 ## multiplicateur de braquage (plus petit = plus large)
@export var mass: float = 1.0
@export var drift_boost_curve: Curve
@export var collision_shape_scale: Vector3 = Vector3(1.0, 1.0, 1.6)
@export var is_plow_class: bool = false ## true pour Truck
@export var knockback_multiplier: float = 1.0 ## >1 pour Motorcycle
@export var ignores_size_hazards: bool = false ## true pour Bicycle
@export var body_color: Color = Color(0.2, 0.7, 1.0)
@export var boost_power: float = 12.0
