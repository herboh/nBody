extends StaticBody2D

@export var mass: float = 900.0
@export var radius: float = 50.0

func _ready():
	add_to_group("planets")
	
func get_radius() -> float:
	return radius

func get_mass() -> float:
	return mass
