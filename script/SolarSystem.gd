extends Node2D

@onready var ui = $"../UI"
@onready var fuel_bar = ui.get_node("Fuel")
@onready var speed_label = ui.get_node("Speed")
@onready var orbit_status_label = ui.get_node("OrbitStatus")  
@onready var trajectory_line: TrajectoryPredictor = $TrajectoryLine
@onready var ship = $Ship

const GRAVITY_CONSTANT: float = 1000.0
const MIN_DISTANCE: float = 10.0

var planets: Array[Planet] = []
var game_over: bool = false

# Orbital analysis settings
const ORBIT_ANALYSIS_RATE: float = 0.1  # Update every 0.1 seconds
const APOAPSIS_PERIAPSIS_TOLERANCE: float = 5.0  # Tolerance for circular orbit detection
const ESCAPE_VELOCITY_MARGIN: float = 1.1  # Margin for escape velocity detection

# Orbital state tracking
var orbit_analysis_timer: float = 0.0
var current_orbital_state: OrbitalState = OrbitalState.UNKNOWN
var primary_body: Planet = null  # The planet we're primarily orbiting
var orbital_data: OrbitalData = OrbitalData.new()

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
	var primary_body: Planet = null


func _ready():
	setup_planets()
	setup_ship()
	setup_trajectory()

func setup_planets():
	for child in get_children():
		if child is Planet:
			planets.append(child)

func setup_ship():
	fuel_bar.max_value = ship.max_fuel
	if planets.size() > 0:
		put_ship_in_circular_orbit(planets[0], 200.0)

func setup_trajectory():
	trajectory_line.initialize(ship, self)

func _physics_process(delta):
	if game_over:
		return
	apply_gravity(delta)
	update_ui()
	
func apply_gravity(delta):
	var total_force = Vector2.ZERO
	
	for planet in planets:
		var direction = planet.global_position - ship.global_position
		var distance = max(direction.length(), MIN_DISTANCE)
		
		var force_magnitude = GRAVITY_CONSTANT * planet.mass * ship.mass / (distance * distance)
		var force = direction.normalized() * force_magnitude
		total_force += force
		
	#ship.apply_central_force(total_force)
	var impulse = total_force * delta
	ship.apply_central_impulse(impulse)

func update_orbital_analysis(delta):
	orbit_analysis_timer += delta
	if orbit_analysis_timer >= ORBIT_ANALYSIS_RATE:
		orbit_analysis_timer = 0.0
		analyze_current_orbit()

func analyze_current_orbit():
	# Find the primary gravitational body (closest planet with significant influence)
	primary_body = find_primary_body()
	
	if not primary_body:
		current_orbital_state = OrbitalState.UNKNOWN
		return
	
	# Calculate orbital parameters
	var r = ship.global_position - primary_body.global_position
	var v = ship.linear_velocity
	var distance = r.length()
	var speed = v.length()
	
	# Calculate specific orbital energy
	var kinetic_energy = 0.5 * speed * speed
	var potential_energy = -GRAVITY_CONSTANT * primary_body.mass / distance
	orbital_data.specific_energy = kinetic_energy + potential_energy
	
	# Calculate angular momentum (scalar in 2D)
	var h = r.cross(v)  # This gives us the z-component of angular momentum
	
	# Calculate eccentricity vector magnitude
	var mu = GRAVITY_CONSTANT * primary_body.mass
	var e_vec = (v.cross(Vector3(0,0,h)) / mu) - (r / distance)
	orbital_data.eccentricity = Vector2(e_vec.x, e_vec.y).length()
	
	# Calculate semi-major axis
	if orbital_data.specific_energy < 0:  # Bound orbit
		orbital_data.semi_major_axis = -mu / (2.0 * orbital_data.specific_energy)
		
		# Calculate apoapsis and periapsis
		var h_scalar = abs(h)
		var p = h_scalar * h_scalar / mu  # Semi-latus rectum
		orbital_data.apoapsis = p / (1.0 - orbital_data.eccentricity)
		orbital_data.periapsis = p / (1.0 + orbital_data.eccentricity)
		
		# Calculate orbital period
		orbital_data.orbital_period = 2.0 * PI * sqrt(pow(orbital_data.semi_major_axis, 3) / mu)
		
		# Determine orbit stability
		classify_orbital_state()
	else:  # Unbound trajectory
		current_orbital_state = OrbitalState.ESCAPE_TRAJECTORY
		orbital_data.is_stable = false

func find_primary_body() -> Planet:
	if planets.size() == 0:
		return null
	
	var closest_planet: Planet = null
	var strongest_influence = 0.0
	
	for planet in planets:
		var distance = (ship.global_position - planet.global_position).length()
		# Calculate gravitational influence (not just distance)
		var influence = planet.mass / (distance * distance)
		
		if influence > strongest_influence:
			strongest_influence = influence
			closest_planet = planet
	
	return closest_planet

func classify_orbital_state():
	orbital_data.primary_body = primary_body
	
	# Check if orbit is decaying (periapsis too low)
	if orbital_data.periapsis < primary_body.get_radius() + 20.0:  # 20px safety margin
		current_orbital_state = OrbitalState.DECAY_ORBIT
		orbital_data.is_stable = false
		return
	
	# Check eccentricity for orbit type
	if orbital_data.eccentricity < 0.05:  # Nearly circular
		current_orbital_state = OrbitalState.STABLE_ORBIT
		orbital_data.is_stable = true
	elif orbital_data.eccentricity < 0.3:  # Low eccentricity ellipse
		current_orbital_state = OrbitalState.STABLE_ORBIT
		orbital_data.is_stable = true
	elif orbital_data.eccentricity < 1.0:  # Elliptical but stable
		current_orbital_state = OrbitalState.ELLIPTICAL_ORBIT
		orbital_data.is_stable = true
	else:  # Should not happen for bound orbits, but safety check
		current_orbital_state = OrbitalState.ESCAPE_TRAJECTORY
		orbital_data.is_stable = false

func put_ship_in_circular_orbit(planet: Node2D, radius: float):
	var center = planet.global_position
	var pos = center + Vector2.LEFT * radius
	ship.global_position = pos
	var v_mag = sqrt(GRAVITY_CONSTANT * planet.mass / radius)
	var tangent = (pos - center).normalized().rotated(PI/2)
	ship.linear_velocity = tangent * v_mag

func calculate_gravity_acceleration_at(position: Vector2) -> Vector2:
	"""Calculate gravitational acceleration at a given position (for trajectory prediction)"""
	var total_acceleration = Vector2.ZERO
	
	for planet in planets:
		var direction = planet.global_position - position
		var distance = max(direction.length(), MIN_DISTANCE)
		var accel_magnitude = GRAVITY_CONSTANT * planet.mass / (distance * distance)
		total_acceleration += direction.normalized() * accel_magnitude
	return total_acceleration

func get_min_distance_to_gravity_source(position: Vector2) -> float:
	"""Get minimum distance to any planet (for trajectory prediction early exit)"""
	var min_distance = INF
	for planet in planets:
		var distance = (planet.global_position - position).length()
		min_distance = min(min_distance, distance)
	return min_distance

# Public interface for trajectory predictor
func get_orbital_state() -> OrbitalState:
	return current_orbital_state

func get_orbital_data() -> OrbitalData:
	return orbital_data

func get_primary_body() -> Planet:
	return primary_body

func get_orbital_period() -> float:
	return orbital_data.orbital_period if orbital_data.is_stable else 0.0

func is_orbit_stable() -> bool:
	return orbital_data.is_stable

func update_ui():
	fuel_bar.value = ship.current_fuel
	speed_label.text = "Speed: %.0f px/s" % ship.linear_velocity.length()
	
	# Update orbital status
	var status_text = get_orbital_status_text()
	if orbit_status_label:
		orbit_status_label.text = status_text

func get_orbital_status_text() -> String:
	match current_orbital_state:
		OrbitalState.STABLE_ORBIT:
			return "STABLE ORBIT (e=%.2f)" % orbital_data.eccentricity
		OrbitalState.ELLIPTICAL_ORBIT:
			return "ELLIPTICAL ORBIT (e=%.2f)" % orbital_data.eccentricity
		OrbitalState.DECAY_ORBIT:
			return "DECAY ORBIT - DANGER!"
		OrbitalState.ESCAPE_TRAJECTORY:
			return "ESCAPE TRAJECTORY"
		OrbitalState.HYPERBOLIC_TRAJECTORY:
			return "HYPERBOLIC TRAJECTORY"
		_:
			return "ANALYZING..."
