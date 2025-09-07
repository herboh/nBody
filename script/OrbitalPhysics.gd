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

# === CORE CALCULATIONS (Consolidated) ===

func get_gravity_at(pos: Vector2, sources: Array) -> Vector2:
	"""Single function for gravity calculations"""
	var accel = Vector2.ZERO
	for src in sources:
		if not src.has_method("get_global_position"): continue
		var delta = src.global_position - pos
		var dist = max(delta.length(), MIN_DISTANCE)
		accel += delta.normalized() * (GRAVITY_CONSTANT * src.mass / (dist * dist))
	return accel

func analyze_orbit(pos: Vector2, vel: Vector2, sources: Array) -> OrbitalData:
	"""Simplified orbital analysis"""
	var data = OrbitalData.new()
	
	# Find primary body (strongest influence)
	var max_influence = 0.0
	for body in sources:
		if not body.has_method("get_global_position"): continue
		var dist = (pos - body.global_position).length()
		var influence = body.mass / (dist * dist)
		if influence > max_influence:
			max_influence = influence
			data.primary = body
	
	if not data.primary: return data
	
	# Calculate orbital parameters
	var r = pos - data.primary.global_position
	var dist = r.length()
	var mu = GRAVITY_CONSTANT * data.primary.mass
	
	# Energy and eccentricity
	data.energy = 0.5 * vel.length_squared() - mu / dist
	var h = r.cross(vel)  # Angular momentum (scalar in 2D)
	var v_cross_h = Vector2(-vel.y * h, vel.x * h)
	var e_vec = (v_cross_h / mu) - (r / dist)
	data.eccentricity = e_vec.length()
	
	# Classify state
	if data.energy >= 0:
		data.state = OrbitalState.ESCAPE
	elif dist < 70:  # Too close to surface (assuming 50px radius + margin)
		data.state = OrbitalState.DECAY
	elif data.eccentricity < 0.3:
		data.state = OrbitalState.STABLE
		data.is_stable = true
	else:
		data.state = OrbitalState.ELLIPTICAL
		data.is_stable = true
	
	# Period for bound orbits
	if data.energy < 0:
		var a = -mu / (2.0 * data.energy)  # Semi-major axis
		data.period = 2.0 * PI * sqrt(pow(a, 3) / mu)
	
	return data

func predict_trajectory(pos: Vector2, vel: Vector2, sources: Array, time: float, steps: int) -> Array:
	"""Simplified trajectory prediction"""
	var points = [pos]
	var dt = time / steps
	
	for i in steps:
		var accel = get_gravity_at(pos, sources)
		vel += accel * dt
		pos += vel * dt
		points.append(pos)
		
		# Early exit if too close to any source
		for src in sources:
			if (pos - src.global_position).length() < MIN_DISTANCE * 5:
				return points
	
	return points

func place_in_orbit(body: RigidBody2D, planet: Node2D, radius: float):
	"""Place body in circular orbit"""
	body.global_position = planet.global_position + Vector2.LEFT * radius
	
	# Get planet mass
	var planet_mass = 0.0
	if "mass" in planet:
		planet_mass = planet.mass
	elif planet.has_method("get_mass"):
		planet_mass = planet.get_mass()
	
	var speed = sqrt(GRAVITY_CONSTANT * planet_mass / radius)
	body.linear_velocity = Vector2.UP * speed

func get_status_text(data: OrbitalData) -> String:
	"""Get UI status text"""
	match data.state:
		OrbitalState.STABLE: return "STABLE (e=%.2f)" % data.eccentricity
		OrbitalState.ELLIPTICAL: return "ELLIPTICAL (e=%.2f)" % data.eccentricity
		OrbitalState.DECAY: return "DECAY - DANGER!"
		OrbitalState.ESCAPE: return "ESCAPE"
		_: return "ANALYZING..."
