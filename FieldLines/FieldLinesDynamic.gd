extends MeshInstance3D

@export var terrain: TerrainGeneration
@export var field_width: float = 68.0
@export var resolution: int = 150
@export var line_height_offset: float = 0.05

# Goal positions
@export var goal_z: float = 28.0

# 16-meter box values
@export var goal_zone_width: float = 16.0
@export var goal_zone_depth: float = 16.0


func _ready() -> void:
	if terrain != null:
		terrain.connect("terrain_changed", Callable(self, "redraw_all_lines"))
	redraw_all_lines()

# TYPED helper function

func draw_dynamic_line(im: ImmediateMesh, x1: float, z1: float, x2: float, z2: float) -> void:
	var count: int = resolution - 1

	for i: int in range(count):
		var t1: float = float(i) / float(resolution)
		var t2: float = float(i + 1) / float(resolution)

		var xa: float = lerp(x1, x2, t1)
		var za: float = lerp(z1, z2, t1)
		var xb: float = lerp(x1, x2, t2)
		var zb: float = lerp(z1, z2, t2)

		var pa: Vector3 = global_transform * Vector3(xa, 0.0, za)
		var pb: Vector3 = global_transform * Vector3(xb, 0.0, zb)

		var ya: float = terrain.get_height_at_position(pa.x, pa.z) + line_height_offset
		var yb: float = terrain.get_height_at_position(pb.x, pb.z) + line_height_offset

		im.surface_add_vertex(Vector3(pa.x, ya, pa.z))
		im.surface_add_vertex(Vector3(pb.x, yb, pb.z))


# MAIN FUNCTION

func redraw_all_lines() -> void:
	if terrain == null:
		return

	var im: ImmediateMesh = ImmediateMesh.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()

	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	mat.emission_enabled = true
	mat.emission = Color.WHITE

	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)

	var half_w: float = field_width / 2.0


	# CENTER LINE
	draw_dynamic_line(im, -half_w, 0.0, half_w, 0.0)


	# CENTER CIRCLE
	var radius: float = 9.0
	var steps: int = 80

	for i: int in range(steps):
		var a1: float = TAU * float(i) / float(steps)
		var a2: float = TAU * float(i + 1) / float(steps)

		var x1: float = sin(a1) * radius
		var z1: float = cos(a1) * radius
		var x2: float = sin(a2) * radius
		var z2: float = cos(a2) * radius

		var y1: float = terrain.get_height_at_position(x1, z1) + line_height_offset
		var y2: float = terrain.get_height_at_position(x2, z2) + line_height_offset

		im.surface_add_vertex(Vector3(x1, y1, z1))
		im.surface_add_vertex(Vector3(x2, y2, z2))



	# GOAL LINES - ACROSS FULL FIELD WIDTH

	# top goal line
	draw_dynamic_line(im, -half_w, -goal_z -7, half_w, -goal_z -7)

	# bottom goal line
	draw_dynamic_line(im, -half_w,  goal_z +7, half_w,  goal_z+7)



	# 16-METER AREAS AROUND THE GOALS

	var half_zone_w: float = goal_zone_width / 2.0
	var depth: float = goal_zone_depth


	# TOP
	
	var z_front_top: float = -goal_z
	var z_back_top: float  = z_front_top - depth

	draw_dynamic_line(im, -half_zone_w, z_front_top, half_zone_w, z_front_top)
	draw_dynamic_line(im, -half_zone_w, z_back_top,  half_zone_w, z_back_top)
	draw_dynamic_line(im, -half_zone_w, z_back_top, -half_zone_w, z_front_top)
	draw_dynamic_line(im,  half_zone_w, z_back_top,  half_zone_w, z_front_top)


	# BOTTOM

	var z_front_bottom: float = goal_z
	var z_back_bottom: float = z_front_bottom + depth

	draw_dynamic_line(im, -half_zone_w, z_front_bottom, half_zone_w, z_front_bottom)
	draw_dynamic_line(im, -half_zone_w, z_back_bottom,  half_zone_w, z_back_bottom)
	draw_dynamic_line(im, -half_zone_w, z_front_bottom, -half_zone_w, z_back_bottom)
	draw_dynamic_line(im,  half_zone_w, z_front_bottom,  half_zone_w, z_back_bottom)


	# FINISH
	im.surface_end()
	mesh = im


