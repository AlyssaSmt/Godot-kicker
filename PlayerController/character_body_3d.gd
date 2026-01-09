extends CharacterBody3D

@export var speed: float = 7.0
@export var mouse_sensitivity: float = 0.002
@export var jump_force: float = 4.5
@export var gravity: float = 12.0

var camera: Camera3D
var look_rotation_x: float = 0.0

func _ready():
	camera = $Camera3D
	# Keep mouse visible at start; user can capture it later
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	if event is InputEventMouseMotion:
		# Horizontal rotation (Y-axis)
		rotate_y(-event.relative.x * mouse_sensitivity)

		# Vertical rotation (X-axis) — clamp to avoid spinning
		look_rotation_x -= event.relative.y * mouse_sensitivity
		look_rotation_x = clamp(look_rotation_x, deg_to_rad(-89), deg_to_rad(89))
		camera.rotation.x = look_rotation_x

	if event is InputEventKey:
		# ESC → Maus freigeben
		if event.pressed and event.keycode == KEY_ESCAPE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	var input_dir = Vector2.ZERO

	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.y += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

	input_dir = input_dir.normalized()

	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# --- Movement ---
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Jump
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_force

	move_and_slide()
