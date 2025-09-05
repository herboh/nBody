extends Node2D

@onready var ui = $"../UI"
@onready var fuel_bar = ui.get_node("Fuel")
@onready var speed_label = ui.get_node("Speed")
@onready var trajectory_line = $TrajectoryLine
@onready var ship = $Ship

const GRAVITY_CONSTANT: float = 100.0
const MIN_DISTANCE: float = 10.0

var planets: Array[Planet] = []
var game_over: bool = false

func _ready():
	for child in get_children():
		if child is Planet:
			planets.append(child)
	fuel_bar.max_value = ship.max_fuel
	#Disable built in gravity, but still leverage the rest of Godot Physics
	ship.set_gravity_scale(0)

func _physics_process(delta):
	if game_over:
		return
		
	apply_gravity(delta)
	update_ui()
	
func apply_gravity(delta):
	#gone back and forth on if this should calc force or accel
	var total_force = Vector2.ZERO
	
	for planet in planets:
		var direction = planet.global_position - ship.global_position
		var distance = max(direction.length(), MIN_DISTANCE)
		
		# F = GMm/r² (force)
		var force_magnitude = GRAVITY_CONSTANT * planet.mass * ship.mass / (distance * distance)
		var force = direction.normalized() * force_magnitude
		total_force += force
		
	ship.apply_central_force(total_force)
	
#This is my idea calculate default value for ship position at runtime
#Goal is to simplify tweaking values, so that the ship always spawns with stable pos + velocity
#could maybe also be done with radius + tangent
func setup_stable_orbit(target_planet: Planet, orbital_distance: float):
	var orbital_velocity = sqrt(GRAVITY_CONSTANT * target_planet.mass / orbital_distance)
	
	# Position ship to the left of planet
	var planet_pos = target_planet.global_position
	ship.global_position = planet_pos + Vector2(-orbital_distance, 0)
	ship.linear_velocity = Vector2(0, orbital_velocity)
	ship.rotation = PI / 2  # Face downward
	
	print("Orbit setup - Distance: %d, Velocity: %.1f" % [orbital_distance, orbital_velocity])
	

func update_ui():
	fuel_bar.value = ship.current_fuel
	speed_label.text = "Speed: %.0f px/s" % ship.linear_velocity.length()
