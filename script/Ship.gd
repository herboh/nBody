extends RigidBody2D

@export var thrust_power: float = 30.0
@export var turn_speed: float = 6.0
@export var max_fuel: float = 100.0
@export var fuel_consumption_rate: float = 10.0

var current_fuel: float
var thrusting: bool = false

@onready var particles = $CPUParticles2D

func _ready():
	current_fuel = max_fuel
	mass = 1.0
	setup_particles()

func setup_particles():
	particles.emitting = false
	particles.amount = 100
	particles.lifetime = 0.2
	particles.direction = Vector2(0, 1)
	particles.spread = 20.0
	particles.initial_velocity_min = 120.0
	particles.initial_velocity_max = 180.0
	particles.scale_amount_min = 0.3
	particles.scale_amount_max = 0.7
	particles.color = Color(1.0, 0.8, 0.3)

func _physics_process(delta):
	handle_input(delta)
	update_particles()	

func handle_input(delta):
	# Rotation
	var rotation_input = 0.0
	if Input.is_action_pressed("turn_left"):
		rotation_input -= 1.0
	if Input.is_action_pressed("turn_right"):
		rotation_input += 1.0
	if rotation_input != 0:
		rotation += rotation_input * turn_speed * delta

	# Thrust
	thrusting = Input.is_action_pressed("thrust") and current_fuel > 0
	if thrusting:
		var thrust_force = Vector2.UP.rotated(rotation) * thrust_power
		apply_central_force(thrust_force)
		
		current_fuel -= fuel_consumption_rate * delta
		current_fuel = max(0, current_fuel)	

func update_particles():
	particles.emitting = thrusting
	particles.position = Vector2(0, 12)
