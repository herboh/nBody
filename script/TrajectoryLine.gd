extends Line2D

@export var prediction_time_fallback: float = 12.0
@export var max_points: int = 600
@export var use_primary_only: bool = false
@export var adaptive_time_step: bool = true

var ship: RigidBody2D
var physics_world: Node
var _grad := Gradient.new()
var _update_timer: float = 0.0

func _ready():
	width = 2.0
	joint_mode = Line2D.LINE_JOINT_ROUND
	_grad.add_point(0.0, Color(1,1,1,0.8))
	_grad.add_point(0.7, Color(0.8,0.8,1,0.4))
	_grad.add_point(1.0, Color(1,1,1,0.1))
	gradient = _grad
	
func _process(delta: float):
	if not ship or not physics_world:
		return
	
	# Update every 3 frames instead of every frame for performance
	_update_timer += delta
	if _update_timer < 0.04:
		return
	_update_timer = 0.0
	
	clear_points()

	var planets: Array = physics_world.get_planets()
	if planets.is_empty():
		return

	# Analyze current orbit to get primary + period
	var data: OrbitalPhysics.OrbitalData = OrbitalPhysics.analyze_orbit(ship.global_position, ship.linear_velocity, planets)
	var horizon: float = prediction_time_fallback
	if data and data.primary and data.period > 0.0:
		horizon = clamp(data.period, 2.0, 60.0)

	# Match physics tick for better agreement
	# Calculate adaptive time step
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	if adaptive_time_step:
		var speed: float = ship.linear_velocity.length()
		var min_distance_to_planet: float = INF
		
		for planet in planets:
			var dist: float = (ship.global_position - planet.global_position).length()
			min_distance_to_planet = min(min_distance_to_planet, dist)
		
		# Smaller time steps when moving fast or close to planets
		var speed_factor: float = clamp(speed / 200.0, 0.5, 2.0)
		var proximity_factor: float = clamp(300.0 / min_distance_to_planet, 0.5, 3.0)
		dt = dt / (speed_factor * proximity_factor)
	
	var steps: int = int(clamp(horizon / dt, 50, max_points))
	
	var path: PackedVector2Array = OrbitalPhysics.predict_trajectory_verlet(
		ship.global_position, 
		ship.linear_velocity, 
		planets, 
		horizon, 
		steps
	)
	
	if path.size() < 2:
		return

	for p: Vector2 in path:
		add_point(p)
