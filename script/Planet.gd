extends StaticBody2D
class_name Planet

@export var mass: float = 1000.0
@export var radius: float = 50.0

func _ready():
	$CollisionShape2D.shape.radius = radius
