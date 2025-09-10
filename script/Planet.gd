extends StaticBody2D

@export var mass: float = 900.0
@export var radius: float = 50.0
@onready var collision_shape : CollisionShape2D = $CollisionShape2D

func _ready():
	add_to_group("planets")
#	We can set radius from collision shape rather than in code, just grabbing it from the scene
# 	Idk it seems more intuitive but up2u
	#set_radius()
	
func get_radius() -> float:
	return radius

func get_mass() -> float:
	return mass

func set_radius():
	radius = collision_shape.shape.radius
