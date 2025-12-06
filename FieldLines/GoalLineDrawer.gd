extends MeshInstance3D

@export var terrain: TerrainGeneration
@export var line_width := 68.0
@export var z_pos := -52.5
@export var resolution := 120

func redraw_goal_line():
	if terrain == null:
		return

	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()

	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	mat.emission_enabled = true
	mat.emission = Color.WHITE

	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)

	var half = line_width / 2.0

	for i in range(resolution - 1):
		var t1 = float(i) / resolution
		var t2 = float(i + 1) / resolution

		var x1 = lerp(-half, half, t1)
		var x2 = lerp(-half, half, t2)

		var y1 = terrain.get_height_at_position(x1, z_pos)
		var y2 = terrain.get_height_at_position(x2, z_pos)

		im.surface_add_vertex(Vector3(x1, y1 + 0.05, z_pos))
		im.surface_add_vertex(Vector3(x2, y2 + 0.05, z_pos))

	im.surface_end()

	mesh = im
