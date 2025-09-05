extends Node2D

@onready var fuel_bar = $CanvasLayer/UI/FuelBar
@onready var speed_label = $CanvasLayer/UI/SpeedLabel
@onready var status_label = $CanvasLayer/UI/StatusLabel
@onready var ship = $Ship
@onready var trajectory_line = $TrajectoryLine
@onready var gravity = 1
var planets: Array[Planet] = []

func _ready():
	for child in get_children():
		if child is Planet:
			planets.append(child)
	fuel_bar.max_value = ship.max_fuel

func _physics_process(delta):
	for planet in planets:
		var dir = planet.global_position - ship.global_position
		var dist = dir.length()
		var force = gravity * (planet.mass * ship.mass) / (dist * dist)
		ship.apply_central_force(dir.normalized() * force)

func update_ui():
	fuel_bar.value = ship.current_fuel
	speed_label.text = "Speed: %.0f" % ship.linear_velocity.length()
