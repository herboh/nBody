extends RigidBody2D

@export var thrust_power: float = 300.0
@export var turn_speed: float = 3.0
@export var max_fuel: float = 100.0

var current_fuel: float
var is_thrusting: bool = false

@onready var particles = $CPUParticles2D

func _ready():
	current_fuel = max_fuel
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
	handle_input()
	apply_thrust(delta)

func handle_input():
	# Rotation
	if Input.is_action_pressed("turn_left"):
		angular_velocity = -turn_speed
	elif Input.is_action_pressed("turn_right"):
		angular_velocity = turn_speed
	else:
		angular_velocity = 0
	
	# Thrust
	var thrust_input = Input.is_action_pressed("thrust")
	is_thrusting = thrust_input and current_fuel > 0

func apply_thrust(delta):
	if is_thrusting:
		var thrust_vector = Vector2(0, -thrust_power).rotated(rotation)
		apply_central_force(thrust_vector)
		
		current_fuel -= 20.0 * delta  # Consume fuel
		current_fuel = max(0, current_fuel)
		
		particles.emitting = true
	else:
		particles.emitting = false
