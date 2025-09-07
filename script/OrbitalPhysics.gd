extends Node

# Global Orbital Physics System
# This autoload provides orbital mechanics calculations for any game object

const GRAVITY_CONSTANT: float = 1000.0
const MIN_DISTANCE: float = 10.0

# Orbital analysis constants
const ORBIT_ANALYSIS_RATE: float = 0.1
const APOAPSIS_PERIAPSIS_TOLERANCE: float = 5.0
const ESCAPE_VELOCITY_MARGIN: float = 1.1

enum OrbitalState {
	UNKNOWN,
	STABLE_ORBIT,
	ELLIPTICAL_ORBIT, 
	DECAY_ORBIT,
	ESCAPE_TRAJECTORY,
	HYPERBOLIC_TRAJECTORY
}

class OrbitalData:
	var apoapsis: float = 0.0
	var periapsis: float = 0.0
	var eccentricity: float = 0.0
	var orbital_period: float = 0.0
	var semi_major_axis: float = 0.0
	var specific_energy: float = 0.0
	var is_stable: bool = false
	var primary_body: Node2D = null

class OrbitalAnalysis:
	var orbital_state: OrbitalState = OrbitalState.UNKNOWN
	var orbital_data: OrbitalData = OrbitalData.new()
	var primary_body: Node2D = null

# === CORE PHYSICS CALCULATIONS ===

func calculate_gravity_force_between(body1_pos: Vector2, body1_mass: float, body2_pos: Vector2, body2_mass: float) -> Vector2:
	"""Calculate gravitational force between two bodies"""
	var direction = body2_pos - body1_pos
	var distance = max(direction.length(), MIN_DISTANCE)
	var force_magnitude = GRAVITY_CONSTANT * body1_mass * body2_mass / (distance * distance)
	return direction.normalized() * force_magnitude

func calculate_gravity_acceleration_at(position: Vector2, gravity_sources: Array) -> Vector2:
	"""Calculate total gravitational acceleration at a position from multiple sources"""
	var total_acceleration = Vector2.ZERO
	
	for source in gravity_sources:
		if not source.has_method("get_mass") or not source.has_method("get_global_position"):
			continue
			
		var direction = source.global_position - position
		var distance = max(direction.length(), MIN_DISTANCE)
		var accel_magnitude = GRAVITY_CONSTANT * source.mass / (distance * distance)
		total_acceleration += direction.normalized() * accel_magnitude
	
	return total_acceleration

func calculate_total_gravitational_force(body_pos: Vector2, body_mass: float, gravity_sources: Array) -> Vector2:
	"""Calculate total gravitational force on a body from multiple sources"""
	var total_force = Vector2.ZERO
	
	for source in gravity_sources:
		if not source.has_method("get_mass") or not source.has_method("get_global_position"):
			continue
			
		var force = calculate_gravity_force_between(body_pos, body_mass, source.global_position, source.mass)
		total_force += force
	
	return total_force

# === ORBITAL MECHANICS ===

func calculate_orbital_energy(position: Vector2, velocity: Vector2, primary_body: Node2D) -> float:
	"""Calculate specific orbital energy (energy per unit mass)"""
	var distance = max((position - primary_body.global_position).length(), MIN_DISTANCE)
	var speed = velocity.length()
	
	var kinetic_energy = 0.5 * speed * speed
	var potential_energy = -GRAVITY_CONSTANT * primary_body.mass / distance
	
	return kinetic_energy + potential_energy

func calculate_angular_momentum_scalar(position: Vector2, velocity: Vector2, primary_body: Node2D) -> float:
	"""Calculate angular momentum magnitude in 2D (scalar)"""
	var r = position - primary_body.global_position
	return r.cross(velocity)  # This gives the z-component in 2D

func calculate_eccentricity(position: Vector2, velocity: Vector2, primary_body: Node2D) -> float:
	"""Calculate orbital eccentricity"""
	var r = position - primary_body.global_position
	var v = velocity
	var distance = r.length()
	var mu = GRAVITY_CONSTANT * primary_body.mass
	var h = calculate_angular_momentum_scalar(position, velocity, primary_body)
	
	# Calculate eccentricity vector in 2D
	# e = (1/μ) * (v × h) - (r/|r|)
	# In 2D, v × h = (v.x * h, v.y * h) - rotating velocity by 90 degrees and scaling by h
	var v_cross_h = Vector2(-v.y * h, v.x * h)  # This is v rotated 90° scaled by h
	var e_vec = (v_cross_h / mu) - (r / distance)
	
	return e_vec.length()

func calculate_semi_major_axis(specific_energy: float, primary_body: Node2D) -> float:
	"""Calculate semi-major axis from specific energy"""
	if specific_energy >= 0:
		return INF  # Unbound orbit
	
	var mu = GRAVITY_CONSTANT * primary_body.mass
	return -mu / (2.0 * specific_energy)

func calculate_apoapsis_periapsis(position: Vector2, velocity: Vector2, primary_body: Node2D) -> Vector2:
	"""Calculate apoapsis and periapsis distances. Returns Vector2(periapsis, apoapsis)"""
	var h = abs(calculate_angular_momentum_scalar(position, velocity, primary_body))
	var mu = GRAVITY_CONSTANT * primary_body.mass
	var eccentricity = calculate_eccentricity(position, velocity, primary_body)
	
	var p = h * h / mu  # Semi-latus rectum
	var periapsis = p / (1.0 + eccentricity)
	var apoapsis = p / (1.0 - eccentricity)
	
	return Vector2(periapsis, apoapsis)

func calculate_orbital_period(semi_major_axis: float, primary_body: Node2D) -> float:
	"""Calculate orbital period using Kepler's third law"""
	var mu = GRAVITY_CONSTANT * primary_body.mass
	return 2.0 * PI * sqrt(pow(semi_major_axis, 3) / mu)

func calculate_circular_orbital_velocity(distance: float, primary_body: Node2D) -> float:
	"""Calculate velocity needed for circular orbit at given distance"""
	return sqrt(GRAVITY_CONSTANT * primary_body.mass / distance)

func calculate_escape_velocity(distance: float, primary_body: Node2D) -> float:
	"""Calculate escape velocity at given distance"""
	return sqrt(2.0 * GRAVITY_CONSTANT * primary_body.mass / distance)

# === ORBITAL ANALYSIS ===

func find_primary_gravitational_body(position: Vector2, gravity_sources: Array) -> Node2D:
	"""Find the body with the strongest gravitational influence at given position"""
	if gravity_sources.size() == 0:
		return null
	
	var strongest_body: Node2D = null
	var strongest_influence = 0.0
	
	for body in gravity_sources:
		if not body.has_method("get_mass") or not body.has_method("get_global_position"):
			continue
			
		var distance = (position - body.global_position).length()
		var influence = body.mass / (distance * distance)
		
		if influence > strongest_influence:
			strongest_influence = influence
			strongest_body = body
	
	return strongest_body

func analyze_orbit(position: Vector2, velocity: Vector2, gravity_sources: Array) -> OrbitalAnalysis:
	"""Comprehensive orbital analysis for a body at given position and velocity"""
	var analysis = OrbitalAnalysis.new()
	
	# Find primary body
	analysis.primary_body = find_primary_gravitational_body(position, gravity_sources)
	
	if not analysis.primary_body:
		analysis.orbital_state = OrbitalState.UNKNOWN
		return analysis
	
	var data = analysis.orbital_data
	data.primary_body = analysis.primary_body
	
	# Calculate orbital parameters
	data.specific_energy = calculate_orbital_energy(position, velocity, analysis.primary_body)
	data.eccentricity = calculate_eccentricity(position, velocity, analysis.primary_body)
	
	# Check if orbit is bound
	if data.specific_energy < 0:  # Bound orbit
		data.semi_major_axis = calculate_semi_major_axis(data.specific_energy, analysis.primary_body)
		
		var apsis = calculate_apoapsis_periapsis(position, velocity, analysis.primary_body)
		data.periapsis = apsis.x
		data.apoapsis = apsis.y
		
		data.orbital_period = calculate_orbital_period(data.semi_major_axis, analysis.primary_body)
		
		# Classify orbital state
		analysis.orbital_state = classify_orbital_state(data, analysis.primary_body)
		data.is_stable = is_orbit_stable_classification(analysis.orbital_state)
	else:  # Unbound trajectory
		analysis.orbital_state = OrbitalState.ESCAPE_TRAJECTORY
		data.is_stable = false
	
	return analysis

func classify_orbital_state(orbital_data: OrbitalData, primary_body: Node2D) -> OrbitalState:
	"""Classify orbital state based on orbital parameters"""
	# Check if orbit is decaying (periapsis too low)
	var surface_radius = 50.0  # Default radius
	if primary_body.has_method("get_radius"):
		surface_radius = primary_body.get_radius()
	elif primary_body.has_method("radius"):
		surface_radius = primary_body.radius
	
	if orbital_data.periapsis < surface_radius + 20.0:  # 20px safety margin
		return OrbitalState.DECAY_ORBIT
	
	# Classify based on eccentricity
	if orbital_data.eccentricity < 0.05:  # Nearly circular
		return OrbitalState.STABLE_ORBIT
	elif orbital_data.eccentricity < 0.3:  # Low eccentricity ellipse
		return OrbitalState.STABLE_ORBIT
	elif orbital_data.eccentricity < 1.0:  # Elliptical but stable
		return OrbitalState.ELLIPTICAL_ORBIT
	else:  # Should not happen for bound orbits
		return OrbitalState.ESCAPE_TRAJECTORY

func is_orbit_stable_classification(state: OrbitalState) -> bool:
	"""Check if orbital state represents a stable orbit"""
	return state in [OrbitalState.STABLE_ORBIT, OrbitalState.ELLIPTICAL_ORBIT]

# === TRAJECTORY PREDICTION ===

func predict_trajectory(start_pos: Vector2, start_vel: Vector2, gravity_sources: Array, 
					   prediction_time: float, steps: int) -> Array:
	"""Predict trajectory path for given time and steps"""
	var points = []
	var pos = start_pos
	var vel = start_vel
	var dt = prediction_time / steps
	
	points.append(pos)
	
	for i in steps:
		var accel = calculate_gravity_acceleration_at(pos, gravity_sources)
		vel += accel * dt
		pos += vel * dt
		points.append(pos)
		
		# Early exit if too close to any gravity source
		var min_distance = get_minimum_distance_to_sources(pos, gravity_sources)
		if min_distance < MIN_DISTANCE * 5:  # Safety margin
			break
	
	return points

func is_trajectory_stable_orbit(start_pos: Vector2, start_vel: Vector2, gravity_sources: Array) -> bool:
	"""Quick check if trajectory represents a stable orbit"""
	var primary = find_primary_gravitational_body(start_pos, gravity_sources)
	if not primary:
		return false
	
	var energy = calculate_orbital_energy(start_pos, start_vel, primary)
	return energy < 0  # Negative energy = bound orbit

func get_minimum_distance_to_sources(position: Vector2, gravity_sources: Array) -> float:
	"""Get minimum distance to any gravity source"""
	var min_distance = INF
	
	for source in gravity_sources:
		# Direct property access for Planet objects
		if not source.has_method("get_global_position"):
			continue
		var distance = (position - source.global_position).length()
		min_distance = min(min_distance, distance)
	
	return min_distance

# === ORBIT SETUP UTILITIES ===

func place_in_circular_orbit(body: RigidBody2D, planet: Node2D, radius: float):
	"""Place a rigid body in circular orbit around a planet"""
	var center = planet.global_position
	var pos = center + Vector2.LEFT * radius
	body.global_position = pos
	
	var orbital_velocity = calculate_circular_orbital_velocity(radius, planet)
	var tangent = (pos - center).normalized().rotated(PI/2)
	body.linear_velocity = tangent * orbital_velocity

func calculate_velocity_for_circular_orbit(position: Vector2, planet: Node2D) -> Vector2:
	"""Calculate velocity vector needed for circular orbit at current position"""
	var r_vec = position - planet.global_position
	var radius = r_vec.length()
	var orbital_speed = calculate_circular_orbital_velocity(radius, planet)
	var tangent = r_vec.normalized().rotated(PI/2)
	return tangent * orbital_speed

# === STABILITY ANALYSIS ===

func analyze_orbit_stability(position: Vector2, velocity: Vector2, planet: Node2D) -> Dictionary:
	"""Detailed stability analysis returning diagnostic information"""
	var distance = (position - planet.global_position).length()
	var speed = velocity.length()
	
	# Calculate velocity components
	var r_hat = (position - planet.global_position).normalized()
	var radial_velocity = velocity.dot(r_hat)
	var tangential_velocity = velocity - (r_hat * radial_velocity)
	var tangential_speed = tangential_velocity.length()
	
	# Calculate required circular velocity
	var circular_velocity = calculate_circular_orbital_velocity(distance, planet)
	var velocity_ratio = tangential_speed / circular_velocity
	
	# Calculate energy and angular momentum
	var energy = calculate_orbital_energy(position, velocity, planet)
	var angular_momentum = calculate_angular_momentum_scalar(position, velocity, planet)
	
	return {
		"distance": distance,
		"speed": speed,
		"radial_velocity": radial_velocity,
		"tangential_speed": tangential_speed,
		"circular_velocity": circular_velocity,
		"velocity_ratio": velocity_ratio,
		"energy": energy,
		"angular_momentum": angular_momentum,
		"is_bound": energy < 0,
		"stability_status": get_stability_status(velocity_ratio, radial_velocity, tangential_speed)
	}

func get_stability_status(velocity_ratio: float, radial_velocity: float, tangential_speed: float) -> String:
	"""Get human-readable stability status"""
	# Check for extreme radial motion
	if abs(radial_velocity) > tangential_speed * 0.5:
		if radial_velocity < -50:
			return "FALLING INWARD"
		elif radial_velocity > 50:
			return "ESCAPING"
	
	# Analyze based on velocity ratio
	if velocity_ratio < 0.5:
		return "SEVERE DECAY"
	elif velocity_ratio < 0.8:
		return "DECAYING ORBIT"
	elif velocity_ratio > 2.0:
		return "HYPERBOLIC ESCAPE"
	elif velocity_ratio > 1.4:
		return "ESCAPE TRAJECTORY"
	elif velocity_ratio > 0.98 and velocity_ratio < 1.02:
		return "STABLE CIRCULAR"
	elif velocity_ratio > 0.85 and velocity_ratio < 1.15:
		return "ELLIPTICAL ORBIT"
	else:
		return "UNSTABLE"

# === UTILITY FUNCTIONS ===

func orbital_state_to_string(state: OrbitalState) -> String:
	"""Convert orbital state enum to string"""
	match state:
		OrbitalState.STABLE_ORBIT:
			return "STABLE_ORBIT"
		OrbitalState.ELLIPTICAL_ORBIT:
			return "ELLIPTICAL_ORBIT"
		OrbitalState.DECAY_ORBIT:
			return "DECAY_ORBIT"
		OrbitalState.ESCAPE_TRAJECTORY:
			return "ESCAPE_TRAJECTORY"
		OrbitalState.HYPERBOLIC_TRAJECTORY:
			return "HYPERBOLIC_TRAJECTORY"
		_:
			return "UNKNOWN"

func get_orbital_status_text(analysis: OrbitalAnalysis) -> String:
	"""Get formatted status text for UI display"""
	match analysis.orbital_state:
		OrbitalState.STABLE_ORBIT:
			return "STABLE ORBIT (e=%.2f)" % analysis.orbital_data.eccentricity
		OrbitalState.ELLIPTICAL_ORBIT:
			return "ELLIPTICAL ORBIT (e=%.2f)" % analysis.orbital_data.eccentricity
		OrbitalState.DECAY_ORBIT:
			return "DECAY ORBIT - DANGER!"
		OrbitalState.ESCAPE_TRAJECTORY:
			return "ESCAPE TRAJECTORY"
		OrbitalState.HYPERBOLIC_TRAJECTORY:
			return "HYPERBOLIC TRAJECTORY"
		_:
			return "ANALYZING..."
