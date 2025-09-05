extends StaticBody2D
class_name Planet

@export var mass: float = 1000.0
@export var radius: float = 50.0

func get_gravity_force(pos: Vector2, body_mass: float) -> Vector2:
	var direction = global_position - pos
	var distance = direction.length()
	
	if distance < radius:
		return Vector2.ZERO  # Inside planet
	
	var force_magnitude = (mass * body_mass) / (distance * distance)
	return direction.normalized() * force_magnitude
