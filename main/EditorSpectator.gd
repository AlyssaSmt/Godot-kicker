extends CharacterBody3D
class_name EditorSpectator

@export var move_speed := 20.0
@export var fast_speed := 60.0
@export var look_sensitivity := 0.003

@export var vertical_speed := 20.0   # Space/Shift up/down
@export var accel := 18.0            # how fast it accelerates to target speed
@export var decel := 22.0            # how quickly it decelerates

@onready var cam: Camera3D = $EditorCamera

@export var terrain_path: NodePath
@export var quad_edit_controller_path: NodePath

@onready var terrain := get_node_or_null(terrain_path)
@onready var quad_edit := get_node_or_null(quad_edit_controller_path)

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
	global_transform = start_root_transform

	if cam:
		cam.global_transform = start_cam_transform

	yaw = rotation_degrees.y
	if cam:
		pitch = cam.rotation_degrees.x


func _unhandled_input(event):
	# Right mouse button to rotate
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		rotating = event.pressed
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if rotating else Input.MOUSE_MODE_VISIBLE)
		return

	# Rotate with mouse
	if event is InputEventMouseMotion and rotating:
		yaw -= event.relative.x * look_sensitivity * 100.0
		pitch -= event.relative.y * look_sensitivity * 100.0
		pitch = clamp(pitch, -85.0, 85.0)

		rotation_degrees.y = yaw
		if cam:
			cam.rotation_degrees.x = pitch
		return

	# Left click to edit quad (only when not rotating)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and !rotating:
		print("LEFT CLICK RECEIVED, rotating=", rotating)
		if quad_edit == null:
			print("QuadEditController path not set!")
			return

		var quad_id := _get_quad_id_under_mouse()
		if quad_id != -1:
			print("quad_edit is null? ", quad_edit == null)
#			quad_edit.client_try_edit_quad(quad_id, 1.0) # delta wie bei dir


func _physics_process(delta):
	var dir := Vector3.ZERO

	if Input.is_action_pressed("ui_up"):
		dir -= transform.basis.z
	if Input.is_action_pressed("ui_down"):
		dir += transform.basis.z
	if Input.is_action_pressed("ui_left"):
		dir -= transform.basis.x
	if Input.is_action_pressed("ui_right"):
		dir += transform.basis.x

	var vy := 0.0
	if Input.is_action_pressed("space"):
		vy += 1.0
	if Input.is_action_pressed("shift"):
		vy -= 1.0

	var speed := fast_speed if Input.is_key_pressed(KEY_CTRL) else move_speed

	var target_v := Vector3.ZERO
	if dir != Vector3.ZERO:
		var n := dir.normalized()
		target_v.x = n.x * speed
		target_v.z = n.z * speed
	target_v.y = vy * vertical_speed

	velocity.x = move_toward(velocity.x, target_v.x, (accel if absf(target_v.x) > 0.01 else decel) * delta * speed)
	velocity.z = move_toward(velocity.z, target_v.z, (accel if absf(target_v.z) > 0.01 else decel) * delta * speed)
	velocity.y = move_toward(velocity.y, target_v.y, (accel if absf(target_v.y) > 0.01 else decel) * delta * vertical_speed)

	move_and_slide()


func _get_quad_id_under_mouse() -> int:
	if cam == null or terrain == null:
		return -1

	var mouse_pos := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse_pos)
	var to := from + cam.project_ray_normal(mouse_pos) * 5000.0

	var q := PhysicsRayQueryParameters3D.new()
	q.from = from
	q.to = to
	q.collide_with_bodies = true
	q.collide_with_areas = true

	# eigenen CharacterBody ignorieren
	q.exclude = [self]

	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		print("RAY: NO HIT")
		return -1

	print("RAY HIT collider=", hit["collider"], " face=", hit.get("face_index", -1))

	# nur Terrain akzeptieren
	if terrain.mesh_instance == null:
		return -1

	var col: Object = hit["collider"]
	if !(col is Node):
		return -1

	var n := col as Node
	if terrain.mesh_instance == null:
		return -1

	# akzeptiere mesh_instance selbst ODER irgendein child/grandchild davon (StaticBody3D etc.)
	if n != terrain.mesh_instance and !terrain.mesh_instance.is_ancestor_of(n):
		return -1


	var face: int = int(hit["face_index"])
	return int(face / 2)
