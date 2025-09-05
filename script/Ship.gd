extends RigidBody2D

@export var thrust: float = 300.0
@export var turn_speed: float = 3.0
@export var fuel: float = 100.0

var current_fuel: float
var thrusting: bool = false

@onready var particles = $CPUParticles2D

func _ready():
	current_fuel = fuel
	setup_particles()

func setup_particles():
	particles.emitting = false
	particles.texture = null  # Will show as white squares
	particles.emission.amount = 50
	particles.emission.lifetime = 1.0
	particles.direction = Vector2(0, 1)  # Backward from ship
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0

func _physics_process(delta):
	# Rotation
	if Input.is_action_pressed("turn_left"):
		rotation -= turn_speed * delta
	if Input.is_action_pressed("turn_right"):
		rotation += turn_speed * delta
	
	# Thrust
	if Input.is_action_pressed("thrust") and fuel > 0:
		thrusting = true
		var thrust_vec = Vector2.RIGHT.rotated(rotation) * thrust
		apply_central_force(thrust_vec)
		fuel -= delta * 5
		emit_signal("fuel_changed", fuel)
	else:
		thrusting = false

	$ThrustParticles.emitting = thrusting
	
func _input(event):
	if event.is_action_pressed("thrust") or event.is_action_released("thrust"):
		emit_signal("thrust_toggled")
