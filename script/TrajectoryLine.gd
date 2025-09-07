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
	
	# Get planets from physics world
	var planets = physics_world.get_planets() if physics_world.has_method("get_planets") else []

	# Check if we're in stable orbit
	var is_stable_orbit = OrbitalPhysics.is_trajectory_stable_orbit(pos, vel, planets)
	
	# Set up gradient based on orbit type
	setup_gradient(is_stable_orbit)
	
	# Use global physics for trajectory prediction
	var trajectory_points = OrbitalPhysics.predict_trajectory(
		pos, vel, planets, prediction_time, prediction_steps
	)
	
	# Add points to line
	for point in trajectory_points:
		add_point(point)
		
		# For stable orbits, check if we've completed the orbit
		if is_stable_orbit and get_point_count() > 20:
			if (point - start_pos).length() < 30:  # Close to start position
				break

func setup_gradient(is_stable: bool):
	var grad = Gradient.new()
	var color = escape_color if not is_stable else orbit_color
	var end_alpha = 0.4 if not is_stable else 0.1  # Escape fades faster
	
	grad.add_point(0.0, Color(color.r, color.g, color.b, line_alpha))
	grad.add_point(1.0, Color(color.r, color.g, color.b, end_alpha))
	gradient = grad
