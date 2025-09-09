# UI.gd (ultra-simple)
extends CanvasLayer

@onready var solar_system: Node = $"../SolarSystem"
@onready var fuel_bar: ProgressBar = $Fuel
@onready var speed_label: Label = $Speed
@onready var status_label: Label = $"OrbitalStatus"  # change to $Status if that's your node name

func _ready() -> void:
	var ship = solar_system.get_ship()
	fuel_bar.min_value = 0.0
	fuel_bar.max_value = ship.max_fuel

func _process(_delta: float) -> void:
	var ship = solar_system.get_ship()
	fuel_bar.value = ship.current_fuel
	speed_label.text = "Speed: %d px/s" % int(ship.linear_velocity.length())
	var od = OrbitalPhysics.get_cached_orbital_data()
	status_label.text = OrbitalPhysics.get_status_text(od)
