@tool
class_name TerrainGeneration
extends Node3D

@export var size_width : int = 88      # Gesamtbreite des Terrains
@export var size_depth : int = 135     # Gesamtlänge des Terrains
@export var edit_height : float = 1.5   # Wie stark wird das Terrain pro Bearbeitung verändert
@export var noise: FastNoiseLite 
@export var min_height := -4.0
@export var max_height := 4.0

@export var quads_x: int = 8
@export var quads_z: int = 12



@export var forbidden_quads: Array[int] = [
	95,94,93,84,85,86,
	21,22,23,30,31,32
]


var forbidden_zones: Array[Rect2] = []


# Spielfeld-Maße
const FIELD_W := 68.0
const FIELD_L := 105.0

signal terrain_changed

var mesh_instance: MeshInstance3D
var data := MeshDataTool.new()


func _ready() -> void:
	generate()





# GENERATE TERRAIN


func generate() -> void:
	if noise == null:
		noise = FastNoiseLite.new()
		noise.frequency = 0.05

	# Basismesh
	var plane := PlaneMesh.new()
	plane.size = Vector2(size_width, size_depth)
	plane.subdivide_depth = quads_z
	plane.subdivide_width = quads_x


	var st := SurfaceTool.new()
	st.create_from(plane, 0)
	var base_mesh := st.commit()

	data = MeshDataTool.new()
	data.create_from_surface(base_mesh, 0)

	# terrain komplett flach machen
	for i in range(data.get_vertex_count()):
		var v: Vector3 = data.get_vertex(i)
		v.y = 0.0
		data.set_vertex(i, v)

	# Neues Mesh
	var new_mesh := ArrayMesh.new()
	data.commit_to_surface(new_mesh)

	# MeshInstance ersetzen
	if mesh_instance:
		mesh_instance.queue_free()

	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = new_mesh
	mesh_instance.set_surface_override_material(
		0, preload("res://Procedural Generation/TerrainMaterial.tres")
	)
	add_child(mesh_instance)

	mesh_instance.create_trimesh_collision()

	print("Terrain generiert – erster Vertex:", data.get_vertex(0))




#TERRAIN EDITING


func edit_quad(quad_id: int, delta: float) -> void:
	if quad_id < 0:
		return

	if _is_quad_forbidden(quad_id):
		return

	_apply_quad_deformation(quad_id, delta)

	# Mesh aktualisieren
	var updated_mesh := ArrayMesh.new()
	data.commit_to_surface(updated_mesh)
	mesh_instance.mesh = updated_mesh

	# Alte Collider löschen
	for child in mesh_instance.get_children():
		if child is StaticBody3D:
			child.queue_free()

	await get_tree().process_frame
	await get_tree().process_frame

	mesh_instance.create_trimesh_collision()
	_fix_ball_safely()

	for node in get_tree().get_nodes_in_group("field_lines"):
		node.redraw_all_lines()

	emit_signal("terrain_changed")




func _apply_quad_deformation(quad_id: int, delta: float) -> void:
	var face_a := quad_id * 2
	var face_b := face_a + 1

	var verts := []

	for i in 3:
		verts.append(data.get_face_vertex(face_a, i))
	for i in 3:
		verts.append(data.get_face_vertex(face_b, i))

	var unique := []
	for v in verts:
		if not unique.has(v):
			unique.append(v)


	for vid in unique:
		var vert := data.get_vertex(vid)

		if not _is_inside_field(vert.x, vert.z):
			continue


		# ✅ Normale Terrain-Bewegung
		var base := delta
		var n := noise.get_noise_2d(vert.x * 0.2, vert.z * 0.2)
		var offset := n * absf(delta) * 3.0

		vert.y += base + offset
		vert.y = clamp(vert.y, min_height, max_height)

		data.set_vertex(vid, vert)





func _is_inside_field(x: float, z: float) -> bool:
	return (
		x > -FIELD_W/2.0 and x < FIELD_W/2.0 and
		z > -FIELD_L/2.0 and z < FIELD_L/2.0
	)




#  BALL FIXING


func _fix_ball_safely() -> void:
	var ball := get_tree().get_first_node_in_group("ball")
	if ball == null:
		return
	if not (ball is RigidBody3D):
		return

	var rb := ball as RigidBody3D
	var pos: Vector3 = rb.global_transform.origin

	var q := PhysicsRayQueryParameters3D.new()
	q.from = pos + Vector3(0, 10, 0)
	q.to = pos + Vector3(0, -50, 0)
	q.exclude = [rb]

	var result := get_world_3d().direct_space_state.intersect_ray(q)
	if not result:
		return

	var terrain_y: float = result.position.y
	var dist: float = pos.y - terrain_y


	# Ball hängt fest, wird hochgepusht
	if dist <= 0.2:
		rb.apply_central_impulse(Vector3.UP * 4.0)
		if rb.linear_velocity.y < 0.0:
			rb.linear_velocity.y *= 0.4

	# Failsafe
	if pos.y < terrain_y + 0.05:
		pos.y = terrain_y + 0.3
		rb.global_transform.origin = pos




# HEIGHT SAMPLING

func get_height_at_position(x: float, z: float) -> float:
	var closest := INF
	var height := 0.0

	for i in range(data.get_vertex_count()):
		var v := data.get_vertex(i)
		var dist := v.distance_to(Vector3(x, v.y, z))
		if dist < closest:
			closest = dist
			height = v.y

	return height


func reset_field() -> void:
	for i in range(data.get_vertex_count()):
		var v: Vector3 = data.get_vertex(i)
		v.y = 0.0
		data.set_vertex(i, v)

	var new_mesh := ArrayMesh.new()
	data.commit_to_surface(new_mesh)
	mesh_instance.mesh = new_mesh

	for child in mesh_instance.get_children():
		if child is StaticBody3D:
			child.queue_free()

	await get_tree().process_frame
	await get_tree().process_frame

	mesh_instance.create_trimesh_collision()
	_fix_ball_safely()


	emit_signal("terrain_changed")

	print("Spielfeld wurde zurückgesetzt!")

# FORBIDDEN ZONES 

func _is_quad_forbidden(quad_id: int) -> bool:
	return forbidden_quads.has(quad_id)
