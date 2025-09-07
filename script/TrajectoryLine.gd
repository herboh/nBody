extends Line2D

@export var prediction_time: float = 12.0
@export var prediction_steps: int = 150
@export var orbit_color: Color = Color.WHITE
@export var escape_color: Color = Color.ORANGE

var ship: RigidBody2D
var physics_world: Node

func _ready():
	width = 2.0
	joint_mode = Line2D.LINE_JOINT_ROUND

func _process(_delta):
	if not ship or not physics_world: return
	
	clear_points()
	
	var planets = physics_world.get_planets() if physics_world.has_method("get_planets") else []
	var data = OrbitalPhysics.analyze_orbit(ship.global_position, ship.linear_velocity, planets)
	
	# Set gradient based on orbit type
	var grad = Gradient.new()
	var color = orbit_color if data.is_stable else escape_color
	grad.add_point(0.0, Color(color.r, color.g, color.b, 0.8))
	grad.add_point(1.0, Color(color.r, color.g, color.b, 0.1))
	gradient = grad
	
	# Add trajectory points
	var trajectory = OrbitalPhysics.predict_trajectory(
		ship.global_position, ship.linear_velocity, planets, prediction_time, prediction_steps
	)
	
	for point in trajectory:
		add_point(point)
		# For stable orbits, stop if we complete the orbit
		if data.is_stable and get_point_count() > 20:
			if (point - ship.global_position).length() < 30:
				break
