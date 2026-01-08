extends Camera3D

@export var move_speed := 20.0
@export var fast_speed := 60.0
@export var look_sensitivity := 0.003

var rotating := false
var pitch := 0.0
var yaw := 0.0

# Store start transforms
var start_camera_transform: Transform3D
var start_parent_transform: Transform3D


func _ready():
	current = true

	var root = get_parent()

	# Start rotation
	yaw = root.rotation_degrees.y
	pitch = rotation_degrees.x

	# Remember start transforms
	start_camera_transform = global_transform
	start_parent_transform = root.global_transform


func reset_camera():
	var root = get_parent()

	# Reset parent (Yaw + Position)
	root.global_transform = start_parent_transform

	# Reset camera (Pitch + Position)
	global_transform = start_camera_transform

	# Update Yaw/Pitch
	yaw = root.rotation_degrees.y
	pitch = rotation_degrees.x



func _unhandled_input(event):

	# Right mouse button to rotate
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotating = event.pressed
			Input.set_mouse_mode(
				Input.MOUSE_MODE_CAPTURED if rotating else Input.MOUSE_MODE_VISIBLE
			)

	# Rotate with mouse
	if event is InputEventMouseMotion and rotating:
		yaw -= event.relative.x * look_sensitivity * 100
		pitch -= event.relative.y * look_sensitivity * 100

		pitch = clamp(pitch, -85, 85)

		# Apply Yaw to parent
		get_parent().rotation_degrees.y = yaw
		# Apply Pitch to camera
		rotation_degrees.x = pitch



func _process(delta):
	var dir := Vector3.ZERO
	var root = get_parent()

	# Movement relative to parent
	if Input.is_action_pressed("ui_up"):
		dir -= root.transform.basis.z
	if Input.is_action_pressed("ui_down"):
		dir += root.transform.basis.z
	if Input.is_action_pressed("ui_left"):
		dir -= root.transform.basis.x
	if Input.is_action_pressed("ui_right"):
		dir += root.transform.basis.x

	if Input.is_action_pressed("space"):
		dir.y += 1
	if Input.is_action_pressed("shift"):
		dir.y -= 1

	var speed := fast_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed

	if dir != Vector3.ZERO:
		root.position += dir.normalized() * speed * delta
