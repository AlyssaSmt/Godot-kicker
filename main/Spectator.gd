extends CharacterBody3D
class_name SpectatorController

@export var speed: float = 10.0
@export var sprint_mult: float = 1.8
@export var mouse_sensitivity: float = 0.002
@export var vertical_speed: float = 6.0   # hoch/runter (Space/Ctrl)

@export var min_pitch_deg: float = -80.0
@export var max_pitch_deg: float = 80.0

@onready var cam: Camera3D = $Camera3D

var _yaw: float = 0.0
var _pitch: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_yaw = rotation.y
	_pitch = cam.rotation.x

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity

		var min_pitch := deg_to_rad(min_pitch_deg)
		var max_pitch := deg_to_rad(max_pitch_deg)
		_pitch = clamp(_pitch, min_pitch, max_pitch)

		rotation.y = _yaw
		cam.rotation.x = _pitch

	# ESC toggelt Maus
	if event.is_action_pressed("ui_cancel"):
		var captured := Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if captured else Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	# Bewegung relativ zur Blickrichtung (yaw)
	var input_dir := Vector3.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.z = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	input_dir = input_dir.normalized()

	var basis := global_transform.basis
	var forward := -basis.z
	var right := basis.x

	var move := (right * input_dir.x) + (forward * input_dir.z)

	# hoch/runter (Space/Ctrl) - optional
	var up_down := 0.0
	if Input.is_action_pressed("move_up"):
		up_down += 1.0
	if Input.is_action_pressed("move_down"):
		up_down -= 1.0

	var spd := speed * (sprint_mult if Input.is_action_pressed("sprint") else 1.0)

	velocity.x = move.x * spd
	velocity.z = move.z * spd
	velocity.y = up_down * vertical_speed

	move_and_slide()
