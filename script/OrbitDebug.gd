extends Node

@onready var solar_system = get_parent()
@onready var ship = solar_system.get_node("Ship")

var planets = []
var initial_data: OrbitalPhysics.OrbitalData
var log_timer: float = 0.0
var setup_timer: float = 0.0
var orbit_rotations: float = 0.0
var last_angle: float = 0.0

func _ready():
	# More robust planet detection
	for child in solar_system.get_children():
		if child.has_method("get_radius") and child.has_method("get_global_position"):
			planets.append(child)
	print("OrbitDebug: Found %d planets" % planets.size())

func _physics_process(delta):
	if planets.size() == 0: return
	
	# Wait for setup
	if setup_timer < 0.1:
		setup_timer += delta
		return
	
	# Establish baseline once
	if not initial_data:
		initial_data = OrbitalPhysics.analyze_orbit(ship.global_position, ship.linear_velocity, planets)
		if initial_data.primary:
			var r = ship.global_position - initial_data.primary.global_position
			last_angle = atan2(r.y, r.x)
		print("OrbitDebug: Baseline - Energy=%.1f" % initial_data.energy)
		return
	
	# Log periodically
	log_timer += delta
	if log_timer >= 0.4:
		log_timer = 0.0
		log_status()

func log_status():
	var data = OrbitalPhysics.analyze_orbit(ship.global_position, ship.linear_velocity, planets)
	if not data.primary: return
	
	var r = ship.global_position - data.primary.global_position
	var dist = r.length()
	var speed = ship.linear_velocity.length()
	
	# Track orbit rotations
	var angle = atan2(r.y, r.x)
	var angle_diff = angle - last_angle
	if angle_diff > PI: angle_diff -= 2 * PI
	elif angle_diff < -PI: angle_diff += 2 * PI
	orbit_rotations += abs(angle_diff) / (2 * PI)
	last_angle = angle
	
	# Calculate drift
	var energy_drift = 0.0
	if abs(initial_data.energy) > 0.001:
		energy_drift = (data.energy - initial_data.energy) / abs(initial_data.energy) * 100.0
	
	print("=== Orbits: %.2f | Dist: %.1f | Speed: %.1f ===" % [orbit_rotations, dist, speed])
	print("State: %s | Energy drift: %+.2f%%" % [OrbitalPhysics.get_status_text(data), energy_drift])
	
	if abs(energy_drift) > 1.0:
		print("⚠️ HIGH ENERGY DRIFT!")
	if dist < 100:
		print("🔥 TOO CLOSE TO PLANET!")
	print("---")
