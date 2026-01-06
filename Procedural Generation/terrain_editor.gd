extends Node3D

@export var terrain: TerrainGeneration
@export var raise_key := "Q"
@export var lower_key := "E"

var last_quad: int = -1


func _unhandled_input(event):

	if terrain == null:
		push_error("TerrainEditor: terrain nicht gesetzt!")
		return

	# Linksklick → Quad auswählen
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_select_quad()

	# Q / E → Terrain bearbeiten
	if event is InputEventKey and event.pressed:
		if event.as_text() == raise_key:
			_edit(+terrain.edit_height)

		if event.as_text() == lower_key:
			_edit(-terrain.edit_height)



func _select_quad():
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		print("Keine Kamera!")
		return

	var mouse_pos := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mouse_pos)
	var to := from + cam.project_ray_normal(mouse_pos) * 5000.0

	var q := PhysicsRayQueryParameters3D.new()
	q.from = from
	q.to = to

	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return

	var pos: Vector3 = hit["position"]


	var col: Node = hit["collider"]

	# nur Terrain anvisieren
	if col != terrain.mesh_instance and col.get_parent() != terrain.mesh_instance:
		print("Did not hit terrain")
		return

	var face: int = hit["face_index"]
	var quad_id := face / 2

	#  Wenn verboten: nicht auswählen
	if terrain.has_method("is_quad_forbidden") and terrain.is_quad_forbidden(quad_id):
		print(" Forbidden Quad:", quad_id, " face:", face)
		last_quad = -1
		return

	last_quad = quad_id
	print("Quad gewählt:", last_quad)



func _edit(amount: float):
	if last_quad == -1:
		return

	terrain.edit_quad(last_quad, amount)
