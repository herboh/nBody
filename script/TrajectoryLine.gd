extends Line2D

@export var prediction_time_fallback: float = 12.0
@export var max_points: int = 600
@export var use_primary_only: bool = false

var ship: RigidBody2D
var physics_world: Node
var _grad := Gradient.new()
var _update_timer: float = 0.0

func _ready():
	width = 2.0
	joint_mode = Line2D.LINE_JOINT_ROUND
	_grad.add_point(0.0, Color(1,1,1,0.8))
	_grad.add_point(1.0, Color(1,1,1,0.1))
	gradient = _grad

func _process(delta: float):
	if not ship or not physics_world:
		return
	
	# Update every 3 frames instead of every frame for performance
	_update_timer += delta
	if _update_timer < 0.05:
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
	var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
	var steps: int = int(clamp(horizon / dt, 32, max_points))

	var path: PackedVector2Array
	if use_primary_only and data.primary:
		path = OrbitalPhysics.predict_trajectory(ship.global_position, ship.linear_velocity, [data.primary], horizon, steps)
	else:
		path = OrbitalPhysics.predict_trajectory(ship.global_position, ship.linear_velocity, planets, horizon, steps)

	if path.size() < 2:
		return

	for p: Vector2 in path:
		add_point(p)
