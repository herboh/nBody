# OrbitalPhysics.gd - Streamlined physics + orbital analysis
extends Node

# === CORE PHYSICS CONSTANTS ===
const GRAVITY_CONSTANT: float = 200.0
const MIN_DISTANCE: float = 2.0

# Gravity influence system
const INFLUENCE_RADIUS_MULTIPLIER: float = 3.5
const GRAVITY_FALLOFF_RATE: float = 0.8

# Orbital classification thresholds
const STABLE_ECCENTRICITY_THRESHOLD: float = 0.2
const ELLIPTICAL_ECCENTRICITY_THRESHOLD: float = 0.8
const CRASH_RADIUS_MULTIPLIER: float = 1.5
const STABLE_DISTANCE_MULTIPLIER: float = 3.0
const SAFE_PERIAPSIS_MULTIPLIER: float = 2.0

# Analysis caching
const POSITION_THRESHOLD: float = 5.0
const VELOCITY_THRESHOLD: float = 10.0
const MIN_ANALYSIS_INTERVAL: float = 0.1
const MAX_ANALYSIS_INTERVAL: float = 1.0

# === DATA STRUCTURES ===
enum OrbitalState { UNKNOWN, STABLE, ELLIPTICAL, DECAY, ESCAPE }

class OrbitalData:
	var state: OrbitalState = OrbitalState.UNKNOWN
	var eccentricity: float = 0.0
	var energy: float = 0.0
	var period: float = 0.0
	var primary: Node2D = null
	var is_stable: bool = false

# === ORBITAL ANALYSIS CACHE ===
var _cached_orbital_data: OrbitalData
var _last_analysis_position: Vector2
var _last_analysis_velocity: Vector2
var _last_analysis_time: float = 0.0
var _game_time_accumulator: float = 0.0

func _ready():
	_cached_orbital_data = OrbitalData.new()

func _process(delta: float) -> void:
	"""Accumulate game time for analysis timing"""
	_game_time_accumulator += delta

# === CORE PHYSICS FUNCTIONS ===

func get_gravity_at(pos: Vector2, sources: Array) -> Vector2:
	"""Calculate gravitational acceleration at position"""
	var accel := Vector2.ZERO
	
	for source in sources:
		if not source or not source.has_method("get_global_position"):
			continue
			
		var delta: Vector2 = source.global_position - pos
		var dist: float = max(delta.length(), MIN_DISTANCE)
		
		var planet_radius: float = source.get_radius()
		var planet_mass: float = source.get_mass()
		var influence_radius: float = planet_radius * INFLUENCE_RADIUS_MULTIPLIER
		
		# Base gravity with smooth falloff
		var base_acceleration: float = GRAVITY_CONSTANT * planet_mass / (dist * dist)
		var influence_factor: float = 1.0
		
		if dist > influence_radius:
			var excess_distance: float = dist - influence_radius
			influence_factor = exp(-GRAVITY_FALLOFF_RATE * excess_distance)
		
		accel += delta.normalized() * base_acceleration * influence_factor
	
	return accel

func predict_trajectory_verlet(pos: Vector2, vel: Vector2, sources: Array, total_time: float, steps: int) -> PackedVector2Array:
	"""Predict trajectory using Velocity-Verlet integration"""
	var points: PackedVector2Array = PackedVector2Array()
	points.append(pos)
	
	if steps <= 0 or total_time <= 0:
		return points
	
	var dt: float = total_time / float(steps)
	var current_pos: Vector2 = pos
	var current_vel: Vector2 = vel
	var current_accel: Vector2 = get_gravity_at(current_pos, sources)

	for i in range(steps):
		# Velocity-Verlet step
		current_pos += current_vel * dt + 0.5 * current_accel * dt * dt
		var new_accel: Vector2 = get_gravity_at(current_pos, sources)
		current_vel += 0.5 * (current_accel + new_accel) * dt
		current_accel = new_accel
		
		points.append(current_pos)

		# Check for collisions
		for source in sources:
			if not source:
				continue
			var collision_radius: float = source.get_radius() * 0.5
			if (current_pos - source.global_position).length() < collision_radius:
				return points

	return points

func place_in_orbit(body: RigidBody2D, planet: Node2D, radius: float) -> void:
	"""Place body in circular orbit around planet"""
	body.global_position = planet.global_position + Vector2.LEFT * radius
	var speed: float = sqrt(GRAVITY_CONSTANT * planet.get_mass() / radius)
	body.linear_velocity = Vector2.UP * speed

# === ORBITAL ANALYSIS WITH CACHING ===

func should_update_analysis(ship_pos: Vector2, ship_vel: Vector2) -> bool:
	"""Check if orbital analysis needs updating"""
	var time_elapsed = _game_time_accumulator - _last_analysis_time
	
	# Force update after max interval
	if time_elapsed > MAX_ANALYSIS_INTERVAL:
		return true
	
	# Skip if minimum interval hasn't passed
	if time_elapsed < MIN_ANALYSIS_INTERVAL:
		return false
	
	# Check for significant movement
	var pos_delta = (ship_pos - _last_analysis_position).length()
	var vel_delta = (ship_vel - _last_analysis_velocity).length()
	
	return pos_delta > POSITION_THRESHOLD or vel_delta > VELOCITY_THRESHOLD

func update_orbital_analysis(ship: RigidBody2D, planets: Array) -> OrbitalData:
	"""Update orbital analysis with smart caching"""
	if not should_update_analysis(ship.global_position, ship.linear_velocity):
		return _cached_orbital_data
	
	print("updating")
	# Perform new analysis
	_cached_orbital_data = analyze_orbit(ship.global_position, ship.linear_velocity, planets)
	
	# Update cache tracking
	_last_analysis_position = ship.global_position
	_last_analysis_velocity = ship.linear_velocity
	_last_analysis_time = _game_time_accumulator
	
	return _cached_orbital_data

func get_cached_orbital_data() -> OrbitalData:
	"""Get cached orbital data without triggering analysis"""
	return _cached_orbital_data

func analyze_orbit(pos: Vector2, vel: Vector2, sources: Array) -> OrbitalData:
	"""Analyze orbital characteristics relative to primary body"""
	var data := OrbitalData.new()
	
	# Find primary body (strongest gravitational influence)
	var max_influence: float = 0.0
	for body in sources:
		if not body or not body.has_method("get_global_position"):
			continue
			
		var dist: float = (pos - body.global_position).length()
		var influence: float = body.get_mass() / (dist * dist)
		if influence > max_influence:
			max_influence = influence
			data.primary = body
	
	if not data.primary:
		return data
	
	# Calculate orbital parameters
	var r: Vector2 = pos - data.primary.global_position
	var dist: float = r.length()
	var mu: float = GRAVITY_CONSTANT * data.primary.get_mass()
	
	# Specific orbital energy
	data.energy = 0.5 * vel.length_squared() - mu / dist
	
	# Eccentricity calculation
	var v_squared: float = vel.length_squared()
	var r_dot_v: float = r.dot(vel)
	var e_vec: Vector2 = ((v_squared - mu/dist) * r - r_dot_v * vel) / mu
	data.eccentricity = e_vec.length()
	
	var body_radius: float = data.primary.get_radius()
	
	# Calculate periapsis for bound orbits
	var periapsis: float = INF
	if data.energy < 0 and data.eccentricity < 1.0:
		var a: float = -mu / (2.0 * data.energy)
		periapsis = a * (1.0 - data.eccentricity)
	
	# Classify orbital state
	if data.energy >= 0:
		data.state = OrbitalState.ESCAPE
	elif periapsis < body_radius * CRASH_RADIUS_MULTIPLIER:
		data.state = OrbitalState.DECAY
	elif data.eccentricity < STABLE_ECCENTRICITY_THRESHOLD and dist > body_radius * STABLE_DISTANCE_MULTIPLIER:
		data.state = OrbitalState.STABLE
		data.is_stable = true
	elif data.eccentricity < ELLIPTICAL_ECCENTRICITY_THRESHOLD and periapsis > body_radius * SAFE_PERIAPSIS_MULTIPLIER:
		data.state = OrbitalState.ELLIPTICAL
		data.is_stable = true
	else:
		data.state = OrbitalState.DECAY
		
	# Calculate orbital period for bound orbits
	if data.energy < 0 and data.eccentricity < 1.0:
		var a: float = -mu / (2.0 * data.energy)
		data.period = 2.0 * PI * sqrt(pow(a, 3) / mu)
	
	return data

func get_status_text(data: OrbitalData) -> String:
	"""Generate orbital status display text"""
	var status: String
	match data.state:
		OrbitalState.STABLE: 
			status = "STABLE ORBIT"
		OrbitalState.ELLIPTICAL: 
			status = "ELLIPTICAL ORBIT"
		OrbitalState.DECAY: 
			status = "ORBITAL DECAY - DANGER!"
		OrbitalState.ESCAPE: 
			status = "ESCAPE TRAJECTORY"
		_: 
			status = "ANALYZING..."
	
	if data.primary:
		status += "\nPrimary: %s" % data.primary.get_name()
		if data.period > 0:
			status += "\nPeriod: %.1fs" % data.period
		status += "\nEccentricity: %.3f" % data.eccentricity
	
	return status
