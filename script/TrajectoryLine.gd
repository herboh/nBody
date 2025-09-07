# TrajectoryLine.gd - Simplified with looser coupling
extends Line2D

@export var prediction_time_fallback: float = 12.0
@export var max_points: int = 600
@export var adaptive_time_step: bool = true
@export var update_interval: float = 0.04  # Made configurable

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
	_update_timer += delta
	if _update_timer < update_interval:
		return
	_update_timer = 0.0
	update_trajectory()

func should_update_trajectory() -> bool:
	if not ship:
		return false
	
	var pos_delta = (ship.global_position - _last_ship_position).length()
	var vel_delta = (ship.linear_velocity - _last_ship_velocity).length()
	
	return pos_delta > MOVEMENT_THRESHOLD or vel_delta > VELOCITY_THRESHOLD

func update_trajectory():
	if not should_update_trajectory():
		return
	
	clear_points()
	
	var planets = get_planets_safely()
	if planets.is_empty():
		return
	
	var path = calculate_trajectory_path(planets)
	if path.size() < 2:
		return
	
	_last_ship_position = ship.global_position
	_last_ship_velocity = ship.linear_velocity
	_cached_path = path
	
	for point in path:
		add_point(point)

func get_planets_safely() -> Array:
	"""Safely get planets from physics world"""
	if physics_world and physics_world.has_method("get_planets"):
		return physics_world.get_planets()
	return []

func calculate_trajectory_path(planets: Array) -> PackedVector2Array:
	var horizon = calculate_prediction_horizon(planets)
	var steps = calculate_optimal_steps(horizon)
	
	return OrbitalPhysics.predict_trajectory_verlet(
		ship.global_position,
		ship.linear_velocity,
		planets,
		horizon,
		steps
	)

func calculate_prediction_horizon(planets: Array) -> float:
	if not physics_world or not physics_world.has_method("get_current_orbital_data"):
		return prediction_time_fallback
	
	var orbital_data = physics_world.get_current_orbital_data()
	if orbital_data and orbital_data.primary and orbital_data.period > 0.0:
		return clamp(orbital_data.period * 1.5, 5.0, 60.0)
	
	return prediction_time_fallback

func calculate_optimal_steps(horizon: float) -> int:
	var dt = 1.0 / float(Engine.physics_ticks_per_second)
	return int(clamp(horizon / dt, 50, max_points))

func get_minimum_planet_distance() -> float:
	var planets = get_planets_safely()
	var min_distance = INF
	for planet in planets:
		var distance = (ship.global_position - planet.global_position).length()
		min_distance = min(min_distance, distance)
	return min_distance

# Optional: Force immediate update (useful for sudden velocity changes)
func force_update():
	"""Force immediate trajectory recalculation"""
	_last_ship_position = Vector2.ZERO
	_last_ship_velocity = Vector2.ZERO
	update_trajectory()
