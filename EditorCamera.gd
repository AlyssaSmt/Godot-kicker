extends Camera3D

@export var move_speed := 20.0
@export var fast_speed := 60.0
@export var look_sensitivity := 0.003

var rotating := false
var pitch := 0.0
var yaw := 0.0

func _ready():
	current = true
	
	# Initiale Orientierung
	var root = get_parent()
	yaw = root.rotation_degrees.y
	pitch = rotation_degrees.x


func _unhandled_input(event):
	# Rechte Maustaste gedrückt halten -> Maus einfangen
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotating = event.pressed
			Input.set_mouse_mode(
				Input.MOUSE_MODE_CAPTURED if rotating else Input.MOUSE_MODE_VISIBLE
			)

	# Mausbewegung -> Kamera drehen
	if event is InputEventMouseMotion and rotating:
		yaw -= event.relative.x * look_sensitivity * 100
		pitch -= event.relative.y * look_sensitivity * 100

		pitch = clamp(pitch, -85, 85)

		# Yaw dreht den Parent → horizontale Rotation
		get_parent().rotation_degrees.y = yaw
		# Pitch dreht die Kamera → vertikale Rotation
		rotation_degrees.x = pitch


func _process(delta):
	var dir := Vector3.ZERO
	var root = get_parent()

	# Bewegung relativ zur Root-Orientierung
	if Input.is_action_pressed("ui_up"):      # W
		dir -= root.transform.basis.z
	if Input.is_action_pressed("ui_down"):    # S
		dir += root.transform.basis.z
	if Input.is_action_pressed("ui_left"):    # A
		dir -= root.transform.basis.x
	if Input.is_action_pressed("ui_right"):   # D
		dir += root.transform.basis.x

	if Input.is_action_pressed("space"):      # Hoch
		dir.y += 1
	if Input.is_action_pressed("shift"):      # Runter
		dir.y -= 1

	var speed := fast_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed

	if dir != Vector3.ZERO:
		root.position += dir.normalized() * speed * delta
