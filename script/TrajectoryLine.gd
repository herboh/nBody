# TrajectoryLine.gd - Simplified with looser coupling
extends Line2D

@export var prediction_time_fallback: float = 12.0
@export var max_points: int = 600
@export var adaptive_time_step: bool = true
@export var update_interval: float = 0.002  # Made configurable

const MAX_TRAJECTORY_DISTANCE: float = 1500.0
const MAX_TRAJECTORY_TIME: float = 20.0

var ship: RigidBody2D
var physics_world: Node
var _update_timer: float = 0.0

var _last_ship_position: Vector2
var _last_ship_velocity: Vector2
var _cached_path: PackedVector2Array

const MOVEMENT_THRESHOLD: float = 3.0
const VELOCITY_THRESHOLD: float = 15.0

func _ready():
	width = 2.0
	joint_mode = Line2D.LINE_JOINT_ROUND
	
	var grad = Gradient.new()
	grad.add_point(0.0, Color(1, 1, 1, 0.8))      # Bright start
	grad.add_point(0.7, Color(0.3, 0.3, 1, 0.4))   # Blue middle
	grad.add_point(1.0, Color(0.8, 0.1, 0.1, 0.1)) # Red fade end
	gradient = grad
	
func _process(delta: float):
	if not ship or not physics_world:
		return
	
	# Simple timer - update every 0.04 seconds regardless
	_update_timer += delta
	if _update_timer < 0.04:  # Or even 0.02 for more responsive
		return
	_update_timer = 0.0
	
	clear_points()
	
	var planets: Array = physics_world.get_planets()
	if planets.is_empty():
		return
	
	var data: OrbitalPhysics.OrbitalData = OrbitalPhysics.analyze_orbit(
		ship.global_position, 
		ship.linear_velocity, 
		planets
	)
	
	var horizon: float = min(prediction_time_fallback, MAX_TRAJECTORY_TIME)
	if data and data.primary and data.period > 0.0:
		horizon = clamp(data.period * 1.5, 2.0, MAX_TRAJECTORY_TIME)
	
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
		
	for point in path:
		var distance_from_start = (point - ship.global_position).length()
		if distance_from_start > MAX_TRAJECTORY_DISTANCE:
			break
		add_point(point)
# Optional: Force immediate update (useful for sudden velocity changes)
func force_update():
	"""Force immediate trajectory recalculation"""
	_update_timer = update_interval  # Trigger update on next frame
