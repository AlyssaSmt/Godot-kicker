extends CharacterBody3D
class_name EditorSpectator

@export var move_speed := 20.0
@export var fast_speed := 60.0
@export var look_sensitivity := 0.003

@export var vertical_speed := 20.0   # Space/Shift up/down
@export var accel := 18.0            # how fast it accelerates to target speed
@export var decel := 22.0            # how quickly it decelerates

@onready var cam: Camera3D = $EditorCamera

var rotating := false
var pitch := 0.0
var yaw := 0.0

# Store start transforms
var start_root_transform: Transform3D
var start_cam_transform: Transform3D

func _ready():
	if cam:
		cam.current = true

	# Read start rotation
	yaw = rotation_degrees.y
	if cam:
		pitch = cam.rotation_degrees.x

# Remember start transforms
	start_root_transform = global_transform
	if cam:
		start_cam_transform = cam.global_transform

func reset_camera():
	# Reset root (Yaw + Position)
	global_transform = start_root_transform

	# Reset camera (Pitch + Position)
	if cam:
		cam.global_transform = start_cam_transform

	# Update Yaw/Pitch
	yaw = rotation_degrees.y
	if cam:
		pitch = cam.rotation_degrees.x

func _unhandled_input(event):
	# Right mouse button to rotate
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		rotating = event.pressed
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if rotating else Input.MOUSE_MODE_VISIBLE)

	# Rotate with mouse
	if event is InputEventMouseMotion and rotating:
		yaw -= event.relative.x * look_sensitivity * 100.0
		pitch -= event.relative.y * look_sensitivity * 100.0
		pitch = clamp(pitch, -85.0, 85.0)

		# Apply Yaw to root
		rotation_degrees.y = yaw
		# Apply Pitch to camera
		if cam:
			cam.rotation_degrees.x = pitch

func _physics_process(delta):
	var dir := Vector3.ZERO

	# Movement relative to root (same as yours)
	if Input.is_action_pressed("ui_up"):
		dir -= transform.basis.z
	if Input.is_action_pressed("ui_down"):
		dir += transform.basis.z
	if Input.is_action_pressed("ui_left"):
		dir -= transform.basis.x
	if Input.is_action_pressed("ui_right"):
		dir += transform.basis.x

	# Up/Down (like you: space up, shift down)
	var vy := 0.0
	if Input.is_action_pressed("space"):
		vy += 1.0
	if Input.is_action_pressed("shift"):
		vy -= 1.0

	var speed := fast_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed

	var target_v := Vector3.ZERO
	if dir != Vector3.ZERO:
		target_v.x = dir.normalized().x * speed
		target_v.z = dir.normalized().z * speed
	else:
		target_v.x = 0.0
		target_v.z = 0.0

	target_v.y = vy * vertical_speed

	# Smooth accel/decel (feels editor-like)
	velocity.x = move_toward(velocity.x, target_v.x, (accel if absf(target_v.x) > 0.01 else decel) * delta * speed)
	velocity.z = move_toward(velocity.z, target_v.z, (accel if absf(target_v.z) > 0.01 else decel) * delta * speed)
	velocity.y = move_toward(velocity.y, target_v.y, (accel if absf(target_v.y) > 0.01 else decel) * delta * vertical_speed)

	move_and_slide()
