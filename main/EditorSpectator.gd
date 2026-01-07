extends CharacterBody3D
class_name EditorSpectator

@export var move_speed := 20.0
@export var fast_speed := 60.0
@export var look_sensitivity := 0.003

@export var vertical_speed := 20.0   # Space/Shift hoch/runter
@export var accel := 18.0            # wie schnell er auf Zielgeschw. geht
@export var decel := 22.0            # wie schnell er stoppt

@onready var cam: Camera3D = $EditorCamera

var rotating := false
var pitch := 0.0
var yaw := 0.0

# Starttransforms speichern
var start_root_transform: Transform3D
var start_cam_transform: Transform3D

func _ready():
	if cam:
		cam.current = true

	# Startrotation lesen
	yaw = rotation_degrees.y
	if cam:
		pitch = cam.rotation_degrees.x

	# Start-Transforms merken
	start_root_transform = global_transform
	if cam:
		start_cam_transform = cam.global_transform

func reset_camera():
	# Root zurücksetzen (Yaw + Position)
	global_transform = start_root_transform

	# Kamera zurücksetzen (Pitch + Position)
	if cam:
		cam.global_transform = start_cam_transform

	# Yaw/Pitch aktualisieren
	yaw = rotation_degrees.y
	if cam:
		pitch = cam.rotation_degrees.x

func _unhandled_input(event):
	# Rechte Maustaste zum Drehen
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		rotating = event.pressed
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if rotating else Input.MOUSE_MODE_VISIBLE)

	# Rotation mit Maus
	if event is InputEventMouseMotion and rotating:
		yaw -= event.relative.x * look_sensitivity * 100.0
		pitch -= event.relative.y * look_sensitivity * 100.0
		pitch = clamp(pitch, -85.0, 85.0)

		# Yaw auf Root
		rotation_degrees.y = yaw
		# Pitch auf Kamera
		if cam:
			cam.rotation_degrees.x = pitch

func _physics_process(delta):
	var dir := Vector3.ZERO

	# Bewegung relativ zum Root (genau wie bei dir)
	if Input.is_action_pressed("ui_up"):
		dir -= transform.basis.z
	if Input.is_action_pressed("ui_down"):
		dir += transform.basis.z
	if Input.is_action_pressed("ui_left"):
		dir -= transform.basis.x
	if Input.is_action_pressed("ui_right"):
		dir += transform.basis.x

	# Hoch/Runter (wie bei dir: space hoch, shift runter)
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

	# Smooth accel/decel (fühlt sich Editor-like an)
	velocity.x = move_toward(velocity.x, target_v.x, (accel if absf(target_v.x) > 0.01 else decel) * delta * speed)
	velocity.z = move_toward(velocity.z, target_v.z, (accel if absf(target_v.z) > 0.01 else decel) * delta * speed)
	velocity.y = move_toward(velocity.y, target_v.y, (accel if absf(target_v.y) > 0.01 else decel) * delta * vertical_speed)

	move_and_slide()
