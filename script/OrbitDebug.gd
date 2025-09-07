extends Node

# Simplified orbit debugger using global orbital physics system

@onready var solar_system = get_parent()
@onready var ship = solar_system.get_node("Ship")
@onready var planets = []

var debug_active: bool = false
var baseline_established: bool = false

var log_interval: float = 0.4
var time_since_log: float = 0.0
var initial_analysis: OrbitalPhysics.OrbitalAnalysis
var orbit_start_time: float = 0.0

# Wait time before establishing baseline
var setup_wait_time: float = 0.1
var time_since_ready: float = 0.0

# Track orbit characteristics
var min_distance: float = INF
var max_distance: float = 0.0
var orbit_count: float = 0.0
var last_angle: float = 0.0

func _ready():
	# Collect all planets
	for child in solar_system.get_children():
		if child is Planet:
			planets.append(child)
	
	print("OrbitDebug: Found %d planets" % planets.size())
	if planets.size() == 0:
		print("OrbitDebug: No planets found - debugger disabled")
		return
	
	debug_active = true
	orbit_start_time = Time.get_ticks_msec() / 1000.0
	
func _physics_process(delta):
	if not debug_active or planets.size() == 0:
		return
		
	time_since_ready += delta
	
	# Wait for setup period before establishing baseline
	if not baseline_established and time_since_ready >= setup_wait_time:
		establish_baseline()
		baseline_established = true
		print("OrbitDebug: Baseline established after %.1fs" % setup_wait_time)
	
	if baseline_established:
		time_since_log += delta
		if time_since_log >= log_interval:
			time_since_log = 0.0
			log_orbital_data()

func establish_baseline():
	"""Establish initial orbital analysis when ship has settled"""
	initial_analysis = OrbitalPhysics.analyze_orbit(
		ship.global_position,
		ship.linear_velocity,
		planets
	)
	
	# Reset tracking variables
	if initial_analysis.primary_body:
		var distance = (ship.global_position - initial_analysis.primary_body.global_position).length()
		min_distance = distance
		max_distance = distance
		
		# Calculate initial angle
		var r_vec = ship.global_position - initial_analysis.primary_body.global_position
		last_angle = atan2(r_vec.y, r_vec.x)
	
	print("OrbitDebug: Initial energy = %.1f" % initial_analysis.orbital_data.specific_energy)
	var initial_momentum = OrbitalPhysics.calculate_angular_momentum_scalar(
		ship.global_position, ship.linear_velocity, initial_analysis.primary_body
	)
	print("OrbitDebug: Initial angular momentum = %.1f" % initial_momentum)

func log_orbital_data():
	if not baseline_established or not initial_analysis.primary_body:
		return
		
	var time_elapsed = (Time.get_ticks_msec() / 1000.0) - orbit_start_time
	
	# Get current orbital analysis
	var current_analysis = OrbitalPhysics.analyze_orbit(
		ship.global_position,
		ship.linear_velocity,
		planets
	)
	
	var planet = current_analysis.primary_body
	if not planet:
		print("OrbitDebug: No primary body found")
		return
	
	# Calculate current parameters
	var r_vec = ship.global_position - planet.global_position
	var distance = r_vec.length()
	var velocity = ship.linear_velocity
	var speed = velocity.length()
	
	# Track orbit characteristics
	min_distance = min(min_distance, distance)
	max_distance = max(max_distance, distance)
	
	# Check for orbit completion
	var current_angle = atan2(r_vec.y, r_vec.x)
	var angle_diff = current_angle - last_angle
	
	# Handle angle wrapping
	if angle_diff > PI:
		angle_diff -= 2 * PI
	elif angle_diff < -PI:
		angle_diff += 2 * PI
	
	orbit_count += abs(angle_diff) / (2 * PI)
	last_angle = current_angle
	
	# Get detailed stability analysis
	var stability = OrbitalPhysics.analyze_orbit_stability(
		ship.global_position,
		ship.linear_velocity,
		planet
	)
	
	# Calculate drifts
	var energy_drift = 0.0
	var momentum_drift = 0.0
	
	if abs(initial_analysis.orbital_data.specific_energy) > 0.001:
		energy_drift = (current_analysis.orbital_data.specific_energy - initial_analysis.orbital_data.specific_energy) / abs(initial_analysis.orbital_data.specific_energy) * 100.0
	
	var initial_momentum = OrbitalPhysics.calculate_angular_momentum_scalar(
		ship.global_position, ship.linear_velocity, initial_analysis.primary_body
	)
	if abs(initial_momentum) > 0.001:
		momentum_drift = (stability.angular_momentum - initial_momentum) / abs(initial_momentum) * 100.0
	
	# Calculate eccentricity if we have min/max distances
	var estimated_eccentricity = 0.0
	if min_distance > 0 and max_distance > min_distance:
		var semi_major = (max_distance + min_distance) / 2.0
		var semi_minor = sqrt(max_distance * min_distance)
		if semi_major > 0:
			estimated_eccentricity = sqrt(1 - (semi_minor * semi_minor) / (semi_major * semi_major))
	
	# Check for potential issues
	var warnings = check_for_issues(distance, planet, speed, stability)
	
	# Log comprehensive data
	print("=== T: %.1fs | Orbits: %.2f ===" % [time_elapsed, orbit_count])
	print("Distance: %.1f px (min: %.1f, max: %.1f) | Speed: %.1f px/s" % [distance, min_distance, max_distance, speed])
	print("Radial vel: %+.1f | Tangential vel: %.1f" % [stability.radial_velocity, stability.tangential_speed])
	print("Required circular vel: %.1f | Ratio: %.3f" % [stability.circular_velocity, stability.velocity_ratio])
	
	if estimated_eccentricity > 0:
		print("Estimated eccentricity: %.3f | Calculated: %.3f" % [estimated_eccentricity, current_analysis.orbital_data.eccentricity])
	
	print("Energy: %.1f (drift: %+.2f%%) | L: %.1f (drift: %+.2f%%)" % [
		current_analysis.orbital_data.specific_energy, energy_drift, 
		stability.angular_momentum, momentum_drift
	])
	print("Orbital State: %s | Status: %s" % [
		OrbitalPhysics.orbital_state_to_string(current_analysis.orbital_state),
		stability.stability_status
	])
	
	# Display warnings
	if warnings.size() > 0:
		for warning in warnings:
			print("WARNING: %s" % warning)
	
	# Alert on significant drift
	if abs(energy_drift) > 1.0:
		print("âš ï¸ ENERGY DRIFT: %+.2f%%" % energy_drift)
	if abs(momentum_drift) > 1.0:
		print("âš ï¸ MOMENTUM DRIFT: %+.2f%%" % momentum_drift)
	
	# Check for orbit decay or escape
	if distance < min_distance * 0.9:
		print("ðŸ“‰ ORBIT DECAY DETECTED")
	elif distance > max_distance * 1.1:
		print("ðŸš€ POSSIBLE ESCAPE TRAJECTORY")
	
	print("---")

func check_for_issues(distance: float, planet: Node2D, speed: float, stability: Dictionary) -> Array:
	"""Check for potential numerical or physical issues"""
	var issues = []
	
	if distance < OrbitalPhysics.MIN_DISTANCE * 1.1:
		issues.append("Distance near MIN_DISTANCE limit! (%.1f)" % distance)
	
	# Check if ship is too close to planet surface
	var surface_radius = 50.0  # Default
	if planet.has_method("get_radius"):
		surface_radius = planet.get_radius()
	elif planet.has_method("radius"):
		surface_radius = planet.radius
	
	if distance < surface_radius * 2:
		issues.append("Ship very close to planet surface! (%.1f < %.1f)" % [distance, surface_radius * 2])
	
	# Check for problematic speeds
	if speed > 1000:
		issues.append("Very high speed detected (%.1f px/s)" % speed)
	
	# Check if multiple planets are significantly affecting the orbit
	if planets.size() > 1:
		var primary_influence = planet.mass / (distance * distance)
		var secondary_influence = 0.0
		
		for p in planets:
			if p != planet:
				var d = (ship.global_position - p.global_position).length()
				if d > OrbitalPhysics.MIN_DISTANCE:
					secondary_influence += p.mass / (d * d)
		
		if secondary_influence > primary_influence * 0.2:
			issues.append("Multi-body effects significant (%.1f%% of primary)" % (secondary_influence / primary_influence * 100))
	
	return issues

# Call this function to reset baseline (useful when manually placing ship in orbit)
func reset_baseline():
	baseline_established = false
	time_since_ready = 0.0
	orbit_count = 0.0
	min_distance = INF
	max_distance = 0.0
	print("OrbitDebug: Baseline reset - will re-establish in %.1fs" % setup_wait_time)
