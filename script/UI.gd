# UI.gd - Sibling node that handles all UI updates
extends CanvasLayer

@export var ui_update_interval: float = 0.05  # 20 FPS for UI

var fuel_bar: ProgressBar
var speed_label: Label
var status_label: Label
var ui_timer: float = 0.0

var solar_system: Node2D  # Reference to sibling SolarSystem node

func _ready():
	initialize_ui_elements()
	find_solar_system()

func initialize_ui_elements():
	"""Find and cache UI element references in CanvasLayer children"""
	# CanvasLayer UI elements are typically nested under child Control nodes
	fuel_bar = find_child("Fuel") if find_child("Fuel") else null
	speed_label = find_child("Speed") if find_child("Speed") else null
	status_label = find_child("Status") if find_child("Status") else null
	
	print("UI initialized - Fuel: %s, Speed: %s, Status: %s" % [
		"✓" if fuel_bar else "✗",
		"✓" if speed_label else "✗", 
		"✓" if status_label else "✗"
	])

func find_solar_system():
	"""Locate the SolarSystem sibling node"""
	solar_system = get_node("../SolarSystem") if has_node("../SolarSystem") else null
	if not solar_system:
		print("Warning: Could not find SolarSystem sibling node")

func _process(delta: float):
	if not solar_system:
		return
		
	ui_timer += delta
	if ui_timer < ui_update_interval:
		return
	ui_timer = 0.0
	
	update_ui()

func update_ui():
	"""Update all UI elements with current game data"""
	var ship = solar_system.get_ship()
	if not ship:
		return
	
	# Update fuel display
	if fuel_bar:
		fuel_bar.value = ship.current_fuel
	
	# Update speed display
	if speed_label:
		var speed = ship.linear_velocity.length()
		speed_label.text = "Speed: %.0f px/s" % speed
	
	# Update orbital status using cached data from OrbitalPhysics
	if status_label:
		var orbital_data = OrbitalPhysics.get_cached_orbital_data()
		status_label.text = OrbitalPhysics.get_status_text(orbital_data)

# Optional: Manual refresh method for immediate updates
func force_update():
	"""Force immediate UI update"""
	ui_timer = ui_update_interval  # Trigger update on next frame
