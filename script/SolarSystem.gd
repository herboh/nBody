extends Node2D

@onready var ui = $"../UI"
@onready var fuel_bar = ui.get_node("Fuel")
@onready var speed_label = ui.get_node("Speed")
@onready var trajectory_line = $TrajectoryLine
@onready var ship = $Ship

# Simplified constants
const GRAVITY_CONSTANT: float = 100.0
const MIN_DISTANCE: float = 10.0

var planets: Array[Planet] = []
var game_over: bool = false

func _ready():
	for child in get_children():
		if child is Planet:
			planets.append(child)
	fuel_bar.max_value = ship.max_fuel
	
	# Disable Godot's built-in gravity
	ship.set_gravity_scale(0)

func _physics_process(delta):
	if game_over:
		return
		
	apply_gravity(delta)
	update_ui()
	
func apply_gravity(delta):
	# Calculate total gravitational acceleration (not force)
	var total_acceleration = Vector2.ZERO
	
	for planet in planets:
		var direction = planet.global_position - ship.global_position
		var distance = max(direction.length(), MIN_DISTANCE)
		
		# a = GM/r² (acceleration, not force)
		var acceleration_magnitude = GRAVITY_CONSTANT * planet.mass / (distance * distance)
		var acceleration = direction.normalized() * acceleration_magnitude
		total_acceleration += acceleration	
	
	ship.apply_central_impulse(total_acceleration * ship.mass * delta)
	
func setup_stable_orbit(target_planet: Planet, orbital_distance: float):
	"""Calculate and set up a stable circular orbit"""
	# Calculate required orbital velocity: v = sqrt(GM/r)
	var orbital_velocity = sqrt(GRAVITY_CONSTANT * target_planet.mass / orbital_distance)
	
	# Position ship to the left of planet
	var planet_pos = target_planet.global_position
	ship.global_position = planet_pos + Vector2(-orbital_distance, 0)
	
	# Set velocity for counterclockwise orbit (downward when left of planet)
	ship.linear_velocity = Vector2(0, orbital_velocity)
	
	# Face the ship in direction of travel
	ship.rotation = PI / 2  # Face downward
	
	print("Orbit setup - Distance: %d, Velocity: %.1f" % [orbital_distance, orbital_velocity])
	

func update_ui():
	fuel_bar.value = ship.current_fuel
	speed_label.text = "Speed: %.0f px/s" % ship.linear_velocity.length()
