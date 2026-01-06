@tool
class_name TerrainGeneration
extends Node3D

# =========================
# EXPORTS / SETTINGS
# =========================
@export var size_width : int = 110      # Gesamtbreite des Terrains
@export var size_depth : int = 135      # Gesamtlänge des Terrains
@export var edit_height : float = 1.5   # Wie stark wird das Terrain pro Bearbeitung verändert
@export var noise: FastNoiseLite
@export var min_height := -4.0
@export var max_height := 4.0

# Wenn du hier manuell ein Material reinziehst, wird das statt dem Shader benutzt.
@export var field_material : Material

@export var quads_x: int = 10
@export var quads_z: int = 12

@export var field_width: float = 68.0
@export var field_length: float = 105.0
@export var border_extra: float = 2.0
@export var lock_border_rings: int = 1 # 1 = Außenrand + 1 Ring nach innen
@export var debug_locked_border: bool = false

@export var border_exception_quads: Array[int] = [92, 96, 20, 24]

@export var forbidden_quads: Array[int] = [
	95,94,93,84,85,86,
	30,31,32,21,22,23
]

var forbidden_zones: Array[Rect2] = []

# Spielfeld-Maße (für _is_inside_field)
const FIELD_W := 68.0
const FIELD_L := 105.0

signal terrain_changed

var mesh_instance: MeshInstance3D
var data := MeshDataTool.new()

# =========================
# SHADER 
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
    // UV ist 0..1 über die ganze Plane
    float gx = floor(UV.x * float(cells_x));
    float gz = floor(UV.y * float(cells_z));

    // Checkerboard
    float parity = mod(gx + gz, 2.0);

    ALBEDO = mix(col_a, col_b, parity);
    ROUGHNESS = roughness;
    METALLIC = metallic;
}
"""





var field_shader_material: ShaderMaterial

func _ready() -> void:
	generate()

# =========================
# MATERIAL HELPERS
# =========================
func _ensure_field_material() -> void:
	# Wenn du ein Material im Inspector zugewiesen hast, nutzen wir das
	if field_material:
		return

	# Sonst bauen wir unser ShaderMaterial einmalig
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

	# Falls ein Material manuell gesetzt wurde, das nutzen
	if field_material:
		mesh_instance.set_surface_override_material(0, field_material)
		return

	# Sonst ShaderMaterial
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

	# Terrain komplett flach machen
	for i in range(data.get_vertex_count()):
		var v: Vector3 = data.get_vertex(i)
		v.y = 0.0
		data.set_vertex(i, v)

	_apply_outer_border_height()
	_apply_checkerboard_per_quad()

	# Neues Mesh
	var new_mesh := ArrayMesh.new()
	data.commit_to_surface(new_mesh)

	# MeshInstance ersetzen
	if mesh_instance:
		mesh_instance.queue_free()

	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = new_mesh
	add_child(mesh_instance)

	_apply_field_material()

	mesh_instance.create_trimesh_collision()

	print("Terrain generiert – erster Vertex:", data.get_vertex(0))

# =========================
# TERRAIN EDITING
# =========================
func edit_quad(quad_id: int, delta: float) -> void:
	if quad_id < 0:
		return

	if _is_quad_forbidden(quad_id):
		return

	# ⛔ Rand + 1 Ring nach innen sperren (mit Ausnahmen)
	if _is_quad_locked_border(quad_id):
		if border_exception_quads.has(quad_id):
			if debug_locked_border:
				print("✅ Border exception quad erlaubt:", quad_id)
		else:
			if debug_locked_border:
				print("⛔ Border locked quad:", quad_id)
			return

	_apply_quad_deformation(quad_id, delta)
	_apply_outer_border_height()
	_apply_checkerboard_per_quad()

	# Mesh aktualisieren
	var updated_mesh := ArrayMesh.new()
	data.commit_to_surface(updated_mesh)
	mesh_instance.mesh = updated_mesh

	# WICHTIG: Material nach commit wieder setzen
	_apply_field_material()

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

	# Ball hängt fest, wird hochgepusht
	if dist <= 0.2:
		rb.apply_central_impulse(Vector3.UP * 4.0)
		if rb.linear_velocity.y < 0.0:
			rb.linear_velocity.y *= 0.4

	# Failsafe
	if pos.y < terrain_y + 0.05:
		pos.y = terrain_y + 0.3
		rb.global_transform.origin = pos

# =========================
# HEIGHT SAMPLING
# =========================
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

	_apply_outer_border_height()
	_apply_checkerboard_per_quad()

	var new_mesh := ArrayMesh.new()
	data.commit_to_surface(new_mesh)
	mesh_instance.mesh = new_mesh

	# WICHTIG: Material nach commit wieder setzen
	_apply_field_material()

	for child in mesh_instance.get_children():
		if child is StaticBody3D:
			child.queue_free()

	await get_tree().process_frame
	await get_tree().process_frame

	mesh_instance.create_trimesh_collision()
	_fix_ball_safely()

	emit_signal("terrain_changed")
	print("Spielfeld wurde zurückgesetzt!")

# =========================
# FORBIDDEN / BORDER
# =========================
func _is_quad_forbidden(quad_id: int) -> bool:
	return forbidden_quads.has(quad_id)

func _get_border_height() -> float:
	return max_height + border_extra

func _apply_outer_border_height() -> void:
	var hw := field_width * 0.5
	var hl := field_length * 0.5
	var h := _get_border_height()

	for i in range(data.get_vertex_count()):
		var v := data.get_vertex(i)
		# Alles außerhalb der Bande dauerhaft hochsetzen
		if abs(v.x) > hw or abs(v.z) > hl:
			v.y = h
			data.set_vertex(i, v)

func _quad_size() -> float:
	return float(size_width) / float(quads_x)  # bei quadratischen Quads reicht das

func _is_in_locked_border(pos: Vector3) -> bool:
	var s := _quad_size()
	var rings := float(lock_border_rings)

	var hw := field_width * 0.5
	var hl := field_length * 0.5

	# Grenze der EDITIERBAREN Zone (innen)
	var inner_hw := hw - rings * s
	var inner_hl := hl - rings * s

	# Alles außerhalb der inneren Zone ist gesperrt
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


func _apply_checkerboard_per_quad() -> void:
	var col_a := Color(0.13, 0.45, 0.13, 1.0)
	var col_b := Color(0.10, 0.38, 0.10, 1.0)

	for quad_id in range(data.get_face_count() / 2):
		var face_a := quad_id * 2
		var face_b := face_a + 1

		# Parität: jedes 2. Quad andere Farbe
		var parity := quad_id % 2
		var c := col_a if parity == 0 else col_b

		# Alle Vertices von beiden Dreiecken färben
		for i in 3:
			data.set_vertex_color(
				data.get_face_vertex(face_a, i),
				c
			)
			data.set_vertex_color(
				data.get_face_vertex(face_b, i),
				c
			)
