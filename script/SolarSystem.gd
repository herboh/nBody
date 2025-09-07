# SolarSystem.gd - Clean coordinator using streamlined OrbitalPhysics
extends Node2D

@onready var ship: RigidBody2D = $Ship
@onready var trajectory_line = $TrajectoryLine
@onready var ui_manager = $UIManager

var planets: Array[Node2D] = []

func _ready():
	discover_planets()
	place_ship()
	setup_trajectory_system()

func place_ship():
	if planets.size() > 0:
		OrbitalPhysics.place_in_orbit(ship, planets[0], 200.0)

func discover_planets():
	planets.clear()
	for child in get_children():
		if child.has_method("get_radius") and child.has_method("get_mass"):
			planets.append(child)

func setup_trajectory_system():
	trajectory_line.ship = ship
	trajectory_line.physics_world = self

func _physics_process(delta: float):
	apply_gravitational_forces(delta)
	update_orbital_analysis()

func apply_gravitational_forces(delta: float):
	var gravity_acceleration = OrbitalPhysics.get_gravity_at(ship.global_position, planets)
	var impulse = gravity_acceleration * ship.mass * delta
	ship.apply_central_impulse(impulse)

func update_orbital_analysis():
	OrbitalPhysics.update_orbital_analysis(ship, planets)

# Public interface for other systems
func get_ship() -> RigidBody2D:
	return ship

func get_planets() -> Array[Node2D]:
	return planets

func get_current_orbital_data() -> OrbitalPhysics.OrbitalData:
	return OrbitalPhysics.get_cached_orbital_data()
