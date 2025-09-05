extends Node2D

@onready var ship = $Ship
var planets: Array[Planet] = []

func _ready():
	# Find all planets in the scene
	for child in get_children():
		if child is Planet:
			planets.append(child)

func _physics_process(delta):
	apply_gravity_to_ship()

func apply_gravity_to_ship():
	for planet in planets:
		var gravity_force = planet.get_gravity_force(ship.global_position, ship.mass)
		ship.apply_central_force(gravity_force)
