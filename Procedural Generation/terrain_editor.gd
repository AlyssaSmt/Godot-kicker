extends Node3D
class_name TerrainEditor

@export var terrain: TerrainGeneration
@export var raise_key := "Q"
@export var lower_key := "E"

var last_quad: int = -1

func _unhandled_input(event):
	if terrain == null:
		push_error("TerrainEditor: terrain not set!")
		return

	# Left-click → Select quad
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_quad()

	# Q / E → Edit terrain
	if event is InputEventKey and event.pressed:
		if event.as_text() == raise_key:
			_edit(+terrain.edit_height)
		elif event.as_text() == lower_key:
			_edit(-terrain.edit_height)

func _select_quad() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		print("No camera!")
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

	var col: Object = hit["collider"]

	# Only target terrain (MeshInstance or its collider child)
	if terrain.mesh_instance == null:
		return
	if col != terrain.mesh_instance and (col is Node and (col as Node).get_parent() != terrain.mesh_instance):
		print("Did not hit terrain")
		return

	var face: int = int(hit["face_index"])
	var quad_id := face / 2

	# If forbidden: don't select
	if terrain.is_quad_forbidden(quad_id):
		print("Forbidden Quad:", quad_id, " face:", face)
		last_quad = -1
		terrain.hide_quad_highlight()
		return

	last_quad = quad_id
	print("Quad selected:", last_quad)

	terrain.show_quad_highlight(last_quad)


func _edit(amount: float) -> void:
	if last_quad == -1:
		return
	terrain.edit_quad(last_quad, amount)
	terrain.show_quad_highlight(last_quad) # reapply after edit
