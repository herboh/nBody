extends StaticBody2D
class_name Planet

@export var mass: float = 1000.0
@export var radius: float = 50.0
@onready var collision_shape = $CollisionShape2D
@onready var sprite = $Sprite2D 

func _ready():
	return

func get_radius() -> float:
	return radius
