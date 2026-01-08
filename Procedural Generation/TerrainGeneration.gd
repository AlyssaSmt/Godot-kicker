@tool
class_name TerrainGeneration
extends Node3D

# =========================
# EXPORTS / SETTINGS
# =========================
@export var size_width : int = 110
@export var size_depth : int = 135
@export var edit_height : float = 1.5
@export var noise: FastNoiseLite
@export var min_height := -4.0
@export var max_height := 4.0

@export var field_material : Material

@export var quads_x: int = 10
@export var quads_z: int = 12

@export var field_width: float = 68.0
@export var field_length: float = 105.0
@export var border_extra: float = 2.0
@export var lock_border_rings: int = 1
@export var debug_locked_border: bool = false

@export var border_exception_quads: Array[int] = [92, 96, 20, 24]

@export var forbidden_quads: Array[int] = [
	94,93,95,84,85,86,
	30,31,32,23,22,21
]

# Field dimensions (for _is_inside_field)
const FIELD_W := 68.0
const FIELD_L := 105.0

signal terrain_changed

var mesh_instance: MeshInstance3D
var data := MeshDataTool.new()

# =========================
# SHADER (Checkerboard per UV)
# =========================
const FIELD_SHADER_CODE := """
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec3 col_a : source_color = vec3(0.13, 0.45, 0.13);
uniform vec3 col_b : source_color = vec3(0.10, 0.38, 0.10);

uniform int cells_x = 10;
uniform int cells_z = 12;

uniform float roughness = 0.95;
uniform float metallic = 0.0;

void fragment() {
    float gx = floor(UV.x * float(cells_x));
    float gz = floor(UV.y * float(cells_z));
    float parity = mod(gx + gz, 2.0);

    ALBEDO = mix(col_a, col_b, parity);
    ROUGHNESS = roughness;
    METALLIC = metallic;
}
"""

var field_shader_material: ShaderMaterial

# =========================
# HIGHLIGHT
# =========================
var highlight_mesh: MeshInstance3D
var highlight_mat: StandardMaterial3D
var highlight_quad_id := -1

const HIGHLIGHT_OK := Color(1, 1, 1, 0.22)         # weiß
const HIGHLIGHT_FORBID := Color(1, 0.10, 0.10, 0.28) # rot

func _ready() -> void:
	generate()

# =========================
# MATERIAL HELPERS
# =========================
func _ensure_field_material() -> void:
	if field_material:
		return
	if field_shader_material:
		return

	var shader := Shader.new()
	shader.code = FIELD_SHADER_CODE

	field_shader_material = ShaderMaterial.new()
	field_shader_material.shader = shader
	_sync_shader_params()

func _sync_shader_params() -> void:
	if not field_shader_material:
		return
	field_shader_material.set_shader_parameter("cells_x", quads_x)
	field_shader_material.set_shader_parameter("cells_z", quads_z)
	field_shader_material.set_shader_parameter("col_a", Color(0.13, 0.45, 0.13))
	field_shader_material.set_shader_parameter("col_b", Color(0.10, 0.38, 0.10))

func _apply_field_material() -> void:
	if not mesh_instance:
		return

	if field_material:
		mesh_instance.set_surface_override_material(0, field_material)
		return

	_ensure_field_material()
	_sync_shader_params()
	mesh_instance.set_surface_override_material(0, field_shader_material)

# =========================
# GENERATE TERRAIN
# =========================
func generate() -> void:
	_ensure_field_material()

	if noise == null:
		noise = FastNoiseLite.new()
		noise.frequency = 0.05

	var plane := PlaneMesh.new()
	plane.size = Vector2(size_width, size_depth)
	plane.subdivide_depth = quads_z
	plane.subdivide_width = quads_x

	var st := SurfaceTool.new()
	st.create_from(plane, 0)
	var base_mesh := st.commit()

	data = MeshDataTool.new()
	data.create_from_surface(base_mesh, 0)

	# flach machen
	for i in range(data.get_vertex_count()):
		var v: Vector3 = data.get_vertex(i)
		v.y = 0.0
		data.set_vertex(i, v)

	_apply_outer_border_height()

	# commit
	var new_mesh := ArrayMesh.new()
	data.commit_to_surface(new_mesh)

	if mesh_instance:
		mesh_instance.queue_free()

	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = new_mesh
	add_child(mesh_instance)

	_apply_field_material()
	mesh_instance.create_trimesh_collision()

	_create_highlight()

	print("Terrain generated – first vertex:", data.get_vertex(0))

# =========================
# TERRAIN EDITING
# =========================
func edit_quad(quad_id: int, delta: float) -> void:
	if quad_id < 0:
		return

	# Forbidden blocken
	if _is_quad_forbidden(quad_id):
		return

	# Rand sperren
	if _is_quad_locked_border(quad_id):
		if border_exception_quads.has(quad_id):
			if debug_locked_border:
				print("✅ Border exception quad allowed:", quad_id)
		else:
			if debug_locked_border:
				print("⛔ Border locked quad:", quad_id)
			return

	_apply_quad_deformation(quad_id, delta)
	_apply_outer_border_height()

	var updated_mesh := ArrayMesh.new()
	data.commit_to_surface(updated_mesh)
	mesh_instance.mesh = updated_mesh
	_apply_field_material()

	# collider neu
	for child in mesh_instance.get_children():
		if child is StaticBody3D:
			child.queue_free()

	await get_tree().process_frame
	await get_tree().process_frame

	mesh_instance.create_trimesh_collision()
	_fix_ball_safely()

	# Highlight rebuild (falls aktiv)
	if highlight_quad_id == quad_id:
		show_quad_highlight(quad_id, false)

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

		var base := delta
		var n := noise.get_noise_2d(vert.x * 0.2, vert.z * 0.2)
		var offset := n * absf(delta) * 3.0

		vert.y += base + offset
		vert.y = clamp(vert.y, min_height, max_height)
		data.set_vertex(vid, vert)

func _is_inside_field(x: float, z: float) -> bool:
	return (
		x > -FIELD_W / 2.0 and x < FIELD_W / 2.0 and
		z > -FIELD_L / 2.0 and z < FIELD_L / 2.0
	)

# =========================
# BALL FIXING
# =========================
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

	if dist <= 0.2:
		rb.apply_central_impulse(Vector3.UP * 4.0)
		if rb.linear_velocity.y < 0.0:
			rb.linear_velocity.y *= 0.4

	if pos.y < terrain_y + 0.05:
		pos.y = terrain_y + 0.3
		rb.global_transform.origin = pos

# =========================
# RESET
# =========================
func reset_field() -> void:
	for i in range(data.get_vertex_count()):
		var v: Vector3 = data.get_vertex(i)
		v.y = 0.0
		data.set_vertex(i, v)

	_apply_outer_border_height()

	var new_mesh := ArrayMesh.new()
	data.commit_to_surface(new_mesh)
	mesh_instance.mesh = new_mesh
	_apply_field_material()

	for child in mesh_instance.get_children():
		if child is StaticBody3D:
			child.queue_free()

	await get_tree().process_frame
	await get_tree().process_frame

	mesh_instance.create_trimesh_collision()
	_fix_ball_safely()

	# Highlight neu setzen falls aktiv
	if highlight_quad_id != -1:
		show_quad_highlight(highlight_quad_id, is_quad_forbidden(highlight_quad_id))

	emit_signal("terrain_changed")

# =========================
# FORBIDDEN / BORDER (Public API)
# =========================
func is_quad_forbidden(quad_id: int) -> bool:
	return _is_quad_forbidden(quad_id)

func _is_quad_forbidden(quad_id: int) -> bool:
	return forbidden_quads.has(quad_id)

func is_quad_blocked(quad_id: int) -> bool:
	if _is_quad_forbidden(quad_id):
		return true
	if _is_quad_locked_border(quad_id) and not border_exception_quads.has(quad_id):
		return true
	return false

func _get_border_height() -> float:
	return max_height + border_extra

func _apply_outer_border_height() -> void:
	var hw := field_width * 0.5
	var hl := field_length * 0.5
	var h := _get_border_height()

	for i in range(data.get_vertex_count()):
		var v := data.get_vertex(i)
		if abs(v.x) > hw or abs(v.z) > hl:
			v.y = h
			data.set_vertex(i, v)

func _quad_size() -> float:
	return float(size_width) / float(quads_x)

func _is_in_locked_border(pos: Vector3) -> bool:
	var s := _quad_size()
	var rings := float(lock_border_rings)

	var hw := field_width * 0.5
	var hl := field_length * 0.5

	var inner_hw := hw - rings * s
	var inner_hl := hl - rings * s

	return abs(pos.x) >= inner_hw or abs(pos.z) >= inner_hl

func _is_quad_locked_border(quad_id: int) -> bool:
	var face_a := quad_id * 2
	var face_b := face_a + 1
	if face_b >= data.get_face_count():
		return false

	var ids: Array[int] = []
	for i in 3:
		ids.append(data.get_face_vertex(face_a, i))
	for i in 3:
		ids.append(data.get_face_vertex(face_b, i))

	var unique: Array[int] = []
	for id in ids:
		if not unique.has(id):
			unique.append(id)

	var center := Vector3.ZERO
	for id in unique:
		center += data.get_vertex(id)
	center /= float(unique.size())

	return _is_in_locked_border(center)

# =========================
# HIGHLIGHT
# =========================
func _create_highlight() -> void:
	if highlight_mesh and is_instance_valid(highlight_mesh):
		return

	highlight_mesh = MeshInstance3D.new()
	highlight_mesh.name = "QuadHighlight"
	add_child(highlight_mesh)

	highlight_mat = StandardMaterial3D.new()
	highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight_mat.emission_enabled = true
	highlight_mat.no_depth_test = true

	# default white
	highlight_mat.albedo_color = HIGHLIGHT_OK
	highlight_mat.emission = Color(1, 1, 1)
	highlight_mat.emission_energy_multiplier = 1.0

	highlight_mesh.material_override = highlight_mat
	highlight_mesh.visible = false

func show_quad_highlight(quad_id: int, forbidden := false) -> void:
	if quad_id < 0 or data == null:
		hide_quad_highlight()
		return

	var face_a := quad_id * 2
	var face_b := face_a + 1
	if face_b >= data.get_face_count():
		hide_quad_highlight()
		return

	# Unique Vertex-IDs sammeln
	var ids: Array[int] = []
	for i in 3:
		ids.append(data.get_face_vertex(face_a, i))
	for i in 3:
		ids.append(data.get_face_vertex(face_b, i))

	var unique: Array[int] = []
	for id in ids:
		if not unique.has(id):
			unique.append(id)

	if unique.size() < 4:
		hide_quad_highlight()
		return

	# Punkte holen
	var pts: Array[Vector3] = []
	for id in unique:
		pts.append(data.get_vertex(id))

	# Mittelpunkt
	var center := Vector3.ZERO
	for p in pts:
		center += p
	center /= float(pts.size())

	# Winkel sortieren im XZ
	pts.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		var aa := atan2(a.z - center.z, a.x - center.x)
		var bb := atan2(b.z - center.z, b.x - center.x)
		return aa < bb
	)

	# Mesh bauen
	var up := Vector3.UP * 0.03
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	st.add_vertex(pts[0] + up)
	st.add_vertex(pts[1] + up)
	st.add_vertex(pts[2] + up)

	st.add_vertex(pts[0] + up)
	st.add_vertex(pts[2] + up)
	st.add_vertex(pts[3] + up)

	highlight_mesh.mesh = st.commit()

	# ✅ Farbe setzen
	if highlight_mat:
		if forbidden:
			highlight_mat.albedo_color = HIGHLIGHT_FORBID
			highlight_mat.emission = Color(1, 0.15, 0.15)
			highlight_mat.emission_energy_multiplier = 1.2
		else:
			highlight_mat.albedo_color = HIGHLIGHT_OK
			highlight_mat.emission = Color(1, 1, 1)
			highlight_mat.emission_energy_multiplier = 1.0

	highlight_mesh.visible = true
	highlight_quad_id = quad_id

	# Auto-unhighlight nach 4s
	if highlight_mesh.has_meta("hide_tween"):
		var old_t: Tween = highlight_mesh.get_meta("hide_tween")
		if old_t:
			old_t.kill()

	var t := create_tween()
	highlight_mesh.set_meta("hide_tween", t)
	t.tween_interval(4.0)
	t.tween_callback(Callable(self, "hide_quad_highlight"))

func hide_quad_highlight() -> void:
	if highlight_mesh:
		highlight_mesh.visible = false
	highlight_quad_id = -1


# =========================
# HEIGHT SAMPLING
# =========================
func get_height_at_position(x: float, z: float) -> float:
	if data == null:
		return 0.0

	var closest := INF
	var height := 0.0

	for i in range(data.get_vertex_count()):
		var v := data.get_vertex(i)
		var dist := Vector2(v.x - x, v.z - z).length()
		if dist < closest:
			closest = dist
			height = v.y

	return height
