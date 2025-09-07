extends Line2D

class_name TrajectoryPredictor

@export var prediction_time: float = 20.0
@export var prediction_steps: int = 100
@export var line_color: Color = Color.GRAY
@export var line_alpha: float = 0.6

var ship: RigidBody2D
var physics_world: Node

func _ready():
	width = 2.0
	# Set up gradient for fading effect
	var grad = Gradient.new()
	grad.add_point(0.0, Color(line_color.r, line_color.g, line_color.b, line_alpha))
	grad.add_point(1.0, Color(line_color.r, line_color.g, line_color.b, 0.1))
	gradient = grad
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
	var dt = prediction_time / prediction_steps
	
	for i in prediction_steps:
		add_point(pos)
		
		# Simple physics integration
		var accel = physics_world.calculate_gravity_acceleration_at(pos)
		vel += accel * dt
		pos += vel * dt
		
		# Stop if we hit a planet
		if physics_world.get_min_distance_to_gravity_source(pos) < 50:
			break
