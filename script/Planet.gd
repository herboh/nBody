extends StaticBody2D

@export var mass: float = 900.0
@export var radius: float = 50.0

func _ready():
	pass

# Consistent interface - always use these methods
func get_radius() -> float:
	return radius

func get_mass() -> float:
	return mass
