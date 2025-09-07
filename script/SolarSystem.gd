extends Node2D

@onready var ui = $"../UI"
@onready var fuel_bar = ui.get_node("Fuel")
@onready var speed_label = ui.get_node("Speed")
@onready var orbit_status_label = ui.get_node("OrbitStatus")  
@onready var trajectory_line: TrajectoryPredictor = $TrajectoryLine
@onready var ship = $Ship

var planets: Array[Planet] = []
var game_over: bool = false

# Orbital analysis settings
const ORBIT_ANALYSIS_RATE: float = 0.1

# Orbital state tracking
var orbit_analysis_timer: float = 0.0
var current_orbital_analysis: OrbitalPhysics.OrbitalAnalysis

func _ready():
	setup_planets()
	setup_ship()
	setup_trajectory()
	current_orbital_analysis = OrbitalPhysics.OrbitalAnalysis.new()

func setup_planets():
	for child in get_children():
		if child is Planet:
			planets.append(child)

func setup_ship():
	fuel_bar.max_value = ship.max_fuel
	if planets.size() > 0:
		OrbitalPhysics.place_in_circular_orbit(ship, planets[0], 200.0)

func setup_trajectory():
	trajectory_line.initialize(ship, self)

func _physics_process(delta):
	if game_over:
		return
	apply_gravity(delta)
	update_orbital_analysis(delta)
	update_ui()
	
func apply_gravity(delta):
	var total_force = Vector2.ZERO
	
	for planet in planets:
		var direction = planet.global_position - ship.global_position
		var distance = max(direction.length(), OrbitalPhysics.MIN_DISTANCE)
		
		var force_magnitude = OrbitalPhysics.GRAVITY_CONSTANT * planet.mass * ship.mass / (distance * distance)
		var force = direction.normalized() * force_magnitude
		total_force += force
		
	#ship.apply_central_force(total_force)
	var impulse = total_force * delta
	ship.apply_central_impulse(impulse)

func update_orbital_analysis(delta):
	orbit_analysis_timer += delta
	if orbit_analysis_timer >= ORBIT_ANALYSIS_RATE:
		orbit_analysis_timer = 0.0
		current_orbital_analysis = OrbitalPhysics.analyze_orbit(
			ship.global_position,
			ship.linear_velocity,
			planets
		)

# Public interface for other systems
func get_orbital_state() -> OrbitalPhysics.OrbitalState:
	return current_orbital_analysis.orbital_state

func get_orbital_data() -> OrbitalPhysics.OrbitalData:
	return current_orbital_analysis.orbital_data

func get_primary_body() -> Planet:
	return current_orbital_analysis.primary_body

func get_orbital_period() -> float:
	return current_orbital_analysis.orbital_data.orbital_period if current_orbital_analysis.orbital_data.is_stable else 0.0

func is_orbit_stable() -> bool:
	return current_orbital_analysis.orbital_data.is_stable

# Interface for trajectory predictor
func calculate_gravity_acceleration_at(position: Vector2) -> Vector2:
	return OrbitalPhysics.calculate_gravity_acceleration_at(position, planets)

func get_min_distance_to_gravity_source(position: Vector2) -> float:
	return OrbitalPhysics.get_minimum_distance_to_sources(position, planets)

func get_planets() -> Array[Planet]:
	return planets

func update_ui():
	fuel_bar.value = ship.current_fuel
	speed_label.text = "Speed: %.0f px/s" % ship.linear_velocity.length()
	
	# Update orbital status
	var status_text = OrbitalPhysics.get_orbital_status_text(current_orbital_analysis)
	if orbit_status_label:
		orbit_status_label.text = status_text
