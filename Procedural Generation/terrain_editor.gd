@tool
extends Node3D
class_name TerrainEditor

@export var terrain: TerrainGeneration
@export var quad_edit_controller_path: NodePath
@export var raise_key := "Q"
@export var lower_key := "E"

@onready var quad_edit := get_node_or_null(quad_edit_controller_path)

var last_quad: int = -1

func _unhandled_input(event):
	if terrain == null:
		push_error("TerrainEditor: terrain not set!")
		return

	# Left-click → select quad
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_quad()

	# Q / E → edit terrain
	if event is InputEventKey and event.pressed:
		if event.as_text() == raise_key:
			_request_edit(+terrain.edit_height)
		elif event.as_text() == lower_key:
			_request_edit(-terrain.edit_height)

func _select_quad() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse_pos)
	var to := from + cam.project_ray_normal(mouse_pos) * 5000.0

	var q := PhysicsRayQueryParameters3D.new()
	q.from = from
	q.to = to
	q.collide_with_bodies = true
	q.collide_with_areas = true

	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return

	# Only target terrain
	if terrain.mesh_instance == null:
		return

	var col: Object = hit["collider"]
	if !(col is Node):
		return

	var n := col as Node
	if n != terrain.mesh_instance and !terrain.mesh_instance.is_ancestor_of(n):
		return

	var face: int = int(hit["face_index"])
	var quad_id := int(face / 2)

	var blocked := terrain.is_quad_blocked(quad_id)

	last_quad = quad_id
	print("HIGHLIGHT quad=", quad_id, " blocked=", blocked)
	terrain.show_quad_highlight(quad_id, blocked)

	if blocked:
		last_quad = -1

func _request_edit(delta: float) -> void:
	if last_quad == -1:
		return

	# Multiplayer: request to host
	if quad_edit != null:
		quad_edit.client_try_edit_quad(last_quad, delta)
		return

	# Singleplayer fallback
	terrain.edit_quad(last_quad, delta)
	terrain.show_quad_highlight(last_quad, false)
