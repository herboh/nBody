extends Line2D

class_name TrajectoryPredictor

@export var prediction_time: float = 12.0
@export var prediction_steps: int = 150
@export var orbit_color: Color = Color.WHITE
@export var escape_color: Color = Color.ORANGE
@export var line_alpha: float = 0.8

var ship: RigidBody2D
var physics_world: Node

func _ready():
	width = 2.0
	joint_mode = Line2D.LINE_JOINT_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND

func initialize(tracked_ship: RigidBody2D, physics_node: Node):
	ship = tracked_ship
	physics_world = physics_node

func _process(_delta):
	if ship and physics_world:
		update_trajectory()

func update_trajectory():
	clear_points()
	
	var pos = ship.global_position
	var vel = ship.linear_velocity
	var start_pos = pos
	
	# Check if we're in stable orbit or escaping
	var is_stable_orbit = check_stable_orbit(pos, vel)
	
	# Set up gradient based on orbit type
	setup_gradient(is_stable_orbit)
	
	var dt = prediction_time / prediction_steps
	var max_steps = prediction_steps
	
	# For stable orbits, try to complete one full orbit
	if is_stable_orbit:
		max_steps = prediction_steps * 2  # Allow longer prediction for full orbit
	
	for i in max_steps:
		add_point(pos)
		
		# Simple physics integration
		var accel = physics_world.calculate_gravity_acceleration_at(pos)
		vel += accel * dt
		pos += vel * dt
		
		# Stop if we hit a planet
		if physics_world.get_min_distance_to_gravity_source(pos) < 50:
			break
			
		# For stable orbits, stop when we complete the orbit
		if is_stable_orbit and i > 20:  # Don't check too early
			if (pos - start_pos).length() < 30:  # Close to start position
				break

func check_stable_orbit(pos: Vector2, vel: Vector2) -> bool:
	# Find closest planet (assumes it's the primary body we're orbiting)
	var closest_planet = null
	var min_distance = INF
	
	for planet in physics_world.planets:
		var dist = (pos - planet.global_position).length()
		if dist < min_distance:
			min_distance = dist
			closest_planet = planet
	
	if not closest_planet:
		return false
	
	# Calculate orbital energy
	var r = min_distance
	var v = vel.length()
	var mu = physics_world.GRAVITY_CONSTANT * closest_planet.mass
	
	var kinetic_energy = 0.5 * v * v
	var potential_energy = -mu / r
	var total_energy = kinetic_energy + potential_energy
	
	# Negative energy = bound orbit, positive = escape
	return total_energy < 0

func setup_gradient(is_stable: bool):
	var grad = Gradient.new()
	var color = escape_color if not is_stable else orbit_color
	var end_alpha = 0.4 if not is_stable else 0.1  # Escape fades faster
	
	grad.add_point(0.0, Color(color.r, color.g, color.b, line_alpha))
	grad.add_point(1.0, Color(color.r, color.g, color.b, end_alpha))
	gradient = grad
