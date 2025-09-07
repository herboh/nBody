extends Node

# Simplified Orbital Physics System
const GRAVITY_CONSTANT: float = 1000.0
const MIN_DISTANCE: float = 10.0

enum OrbitalState { UNKNOWN, STABLE, ELLIPTICAL, DECAY, ESCAPE }

class OrbitalData:
	var state: OrbitalState = OrbitalState.UNKNOWN
	var eccentricity: float = 0.0
	var energy: float = 0.0
	var period: float = 0.0
	var primary: Node2D = null
	var is_stable: bool = false

func get_gravity_at(pos: Vector2, sources: Array) -> Vector2:
	"""Calculate gravitational acceleration from all sources"""
	var accel := Vector2.ZERO
	
	for source in sources:
		if not source or not source.has_method("get_global_position"):
			continue
			
		var delta: Vector2 = source.global_position - pos
		var dist_sq: float = delta.length_squared()
		var dist: float = max(sqrt(dist_sq), MIN_DISTANCE)
		
		# F = GMm/r^2, so a = GM/r^2
		var acceleration_magnitude: float = GRAVITY_CONSTANT * source.mass / (dist * dist)
		accel += delta.normalized() * acceleration_magnitude
	
	return accel

func analyze_orbit(pos: Vector2, vel: Vector2, sources: Array) -> OrbitalData:
	"""Analyze orbital characteristics relative to primary body"""
	var data := OrbitalData.new()
	
	# Find primary body (strongest gravitational influence)
	var max_influence: float = 0.0
	for body in sources:
		if not body or not body.has_method("get_global_position"):
			continue
			
		var dist: float = (pos - body.global_position).length()
		var influence: float = body.mass / (dist * dist)
		if influence > max_influence:
			max_influence = influence
			data.primary = body
	
	if not data.primary:
		return data
	
	# Calculate orbital parameters relative to primary
	var r: Vector2 = pos - data.primary.global_position
	var dist: float = r.length()
	var mu: float = GRAVITY_CONSTANT * data.primary.mass
	
	# Specific orbital energy
	data.energy = 0.5 * vel.length_squared() - mu / dist
	
	# Eccentricity vector calculation
	var v_squared: float = vel.length_squared()
	var r_dot_v: float = r.dot(vel)
	var e_vec: Vector2 = ((v_squared - mu/dist) * r - r_dot_v * vel) / mu
	data.eccentricity = e_vec.length()
	
	# Get body radius for collision detection
	var body_radius: float = 50.0  # Default
	if data.primary.has_method("get_radius"):
		body_radius = data.primary.get_radius()
	elif "radius" in data.primary:
		body_radius = data.primary.radius
	
	# Calculate periapsis for bound orbits
	var periapsis: float = INF
	if data.energy < 0 and data.eccentricity < 1.0:
		var a: float = -mu / (2.0 * data.energy)  # Semi-major axis
		periapsis = a * (1.0 - data.eccentricity)
	
	# Classify orbital state
	if data.energy >= 0:
		data.state = OrbitalState.ESCAPE
	elif periapsis < body_radius * 1.5:  # Will crash
		data.state = OrbitalState.DECAY
	elif data.eccentricity < 0.2 and dist > body_radius * 3.0:
		data.state = OrbitalState.STABLE
		data.is_stable = true
	elif data.eccentricity < 0.8 and periapsis > body_radius * 2.0:
		data.state = OrbitalState.ELLIPTICAL
		data.is_stable = true
	else:
		data.state = OrbitalState.DECAY
		
	# Calculate orbital period for bound orbits
	if data.energy < 0 and data.eccentricity < 1.0:
		var a: float = -mu / (2.0 * data.energy)
		data.period = 2.0 * PI * sqrt(pow(a, 3) / mu)
	
	return data

func predict_trajectory_verlet(pos: Vector2, vel: Vector2, sources: Array, total_time: float, steps: int) -> PackedVector2Array:
	"""Predict trajectory using Velocity-Verlet integration with all gravitational sources"""
	var points: PackedVector2Array = PackedVector2Array()
	points.append(pos)
	
	if steps <= 0 or total_time <= 0:
		return points
	
	var dt: float = total_time / float(steps)
	var current_pos: Vector2 = pos
	var current_vel: Vector2 = vel
	var current_accel: Vector2 = get_gravity_at(current_pos, sources)

	for i in range(steps):
		# Velocity-Verlet integration step
		# Position: x(t+dt) = x(t) + v(t)*dt + 0.5*a(t)*dt^2
		current_pos += current_vel * dt + 0.5 * current_accel * dt * dt
		
		# Calculate new acceleration at new position
		var new_accel: Vector2 = get_gravity_at(current_pos, sources)
		
		# Velocity: v(t+dt) = v(t) + 0.5*(a(t) + a(t+dt))*dt
		current_vel += 0.5 * (current_accel + new_accel) * dt
		current_accel = new_accel
		
		points.append(current_pos)

		# Check for collisions with any gravitational body
		for source in sources:
			if not source:
				continue
				
			var collision_radius: float = 50.0  # Default
			if source.has_method("get_radius"):
				collision_radius = source.get_radius()
			elif "radius" in source:
				collision_radius = source.radius
			
			var distance_to_body: float = (current_pos - source.global_position).length()
			if distance_to_body < collision_radius * 1.1:  # Small margin for collision
				return points

	return points

func place_in_orbit(body: RigidBody2D, planet: Node2D, radius: float) -> void:
	"""Place body in circular orbit around planet"""
	body.global_position = planet.global_position + Vector2.LEFT * radius
	
	# Get planet mass
	var planet_mass: float = 0.0
	if "mass" in planet:
		planet_mass = planet.mass
	elif planet.has_method("get_mass"):
		planet_mass = planet.get_mass()
	
	# Calculate circular orbital velocity
	var speed: float = sqrt(GRAVITY_CONSTANT * planet_mass / radius)
	body.linear_velocity = Vector2.UP * speed
	
	# Set angular velocity if supported
	if body.has_method("set_angular_velocity"):
		var angular_vel: float = speed / radius
		body.angular_velocity = angular_vel

func get_status_text(data: OrbitalData) -> String:
	"""Generate status text for UI display"""
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
		status += "\nPrimary: %s" % data.primary.name
		if data.period > 0:
			status += "\nPeriod: %.1fs" % data.period
		status += "\nEccentricity: %.3f" % data.eccentricity
	
	return status
