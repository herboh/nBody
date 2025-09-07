extends Node2D

@onready var ui = $"../UI"
@onready var fuel_bar = ui.get_node("Fuel")
@onready var speed_label = ui.get_node("Speed")
@onready var trajectory_line = $TrajectoryLine
@onready var ship = $Ship

const GRAVITY_CONSTANT: float = 50000.0
const MIN_DISTANCE: float = 10.0

var planets: Array[Planet] = []
var game_over: bool = false

func _ready():
	for child in get_children():
		if child is Planet:
			planets.append(child)
	fuel_bar.max_value = ship.max_fuel
	ship.set_gravity_scale(0)
	
	# Put ship in orbit around first planet
	if planets.size() > 0:
		put_ship_in_circular_orbit(planets[0], 200.0)

func _physics_process(delta):
	if game_over:
		return
		
	apply_gravity(delta)
	update_ui()
	
func apply_gravity(delta):
	var total_force = Vector2.ZERO
	
	for planet in planets:
		var direction = planet.global_position - ship.global_position
		var distance = max(direction.length(), MIN_DISTANCE)
		
		var force_magnitude = GRAVITY_CONSTANT * planet.mass / (distance * distance)
		var force = direction.normalized() * force_magnitude
		total_force += force
		
	ship.apply_central_force(total_force)

func put_ship_in_circular_orbit(planet: Node2D, radius: float):
	var center = planet.global_position
	var pos = center + Vector2.RIGHT * radius
	ship.global_position = pos
	var v_mag = sqrt(GRAVITY_CONSTANT * planet.mass / radius)
	var tangent = (pos - center).normalized().rotated(PI/2)
	ship.linear_velocity = tangent * v_mag
	
func update_ui():
	fuel_bar.value = ship.current_fuel
	speed_label.text = "Speed: %.0f px/s" % ship.linear_velocity.length()
