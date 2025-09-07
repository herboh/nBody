extends Node2D

@onready var ui = $"../UI"
@onready var ship = $Ship
@onready var trajectory_line = $TrajectoryLine

var planets: Array = []  # Array of Planet nodes
var orbital_data: OrbitalPhysics.OrbitalData
var analysis_timer: float = 0.0

func _ready():
	# Setup planets - more robust detection
	for child in get_children():
		if child.has_method("get_radius") and child.has_method("get_global_position"):
			planets.append(child)
			print("Found planet: ", child.name)
	
	# Initialize ship orbit
	if planets.size() > 0:
		OrbitalPhysics.place_in_orbit(ship, planets[0], 200.0)
	
	# Setup trajectory
	trajectory_line.ship = ship
	trajectory_line.physics_world = self
	
	orbital_data = OrbitalPhysics.OrbitalData.new()

func _physics_process(delta):
	# Apply gravity
	var impulse = OrbitalPhysics.get_gravity_at(ship.global_position, planets) * ship.mass * delta
	ship.apply_central_impulse(impulse)
	
	# Update analysis periodically
	analysis_timer += delta
	if analysis_timer >= 0.1:
		analysis_timer = 0.0
		orbital_data = OrbitalPhysics.analyze_orbit(ship.global_position, ship.linear_velocity, planets)
	
	# Update UI
	ui.get_node("Fuel").value = ship.current_fuel
	ui.get_node("Speed").text = "Speed: %.0f px/s" % ship.linear_velocity.length()
	#ui.get_node("OrbitStatus").text = OrbitalPhysics.get_status_text(orbital_data)

# Interface for trajectory predictor
# Interface for trajectory predictor
func get_planets() -> Array:
	return planets
