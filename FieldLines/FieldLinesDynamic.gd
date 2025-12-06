extends MeshInstance3D

@export var terrain: TerrainGeneration
@export var field_width: float = 68.0
@export var field_length: float = 105.0
@export var resolution: int = 150
@export var line_height_offset: float = 0.05


func _ready() -> void:
	if terrain != null:
		terrain.connect("terrain_changed", Callable(self, "redraw_all_lines"))

	redraw_all_lines()



# -------------------------------------------------
# TYPISIERTE Hilfsfunktion
# -------------------------------------------------
func draw_dynamic_line(im: ImmediateMesh, x1: float, z1: float, x2: float, z2: float) -> void:
	var count: int = resolution - 1

	for i in count:
		var t1: float = float(i) / float(resolution)
		var t2: float = float(i + 1) / float(resolution)

		var xa: float = lerp(x1, x2, t1)
		var za: float = lerp(z1, z2, t1)
		var xb: float = lerp(x1, x2, t2)
		var zb: float = lerp(z1, z2, t2)

		# Punkte in Weltkoordinaten transformieren
		var pa := global_transform * Vector3(xa, 0, za)
		var pb := global_transform * Vector3(xb, 0, zb)

		# Terrainhöhe korrekt ermitteln
		var ya: float = terrain.get_height_at_position(pa.x, pa.z) + line_height_offset
		var yb: float = terrain.get_height_at_position(pb.x, pb.z) + line_height_offset

		im.surface_add_vertex(Vector3(pa.x, ya, pa.z))
		im.surface_add_vertex(Vector3(pb.x, yb, pb.z))


# -------------------------------------------------
# HAUPTFUNKTION – komplett typisiert
# -------------------------------------------------
func redraw_all_lines() -> void:
	if terrain == null:
		return

	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()

	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color.WHITE
	mat.emission_enabled = true
	mat.emission = Color.WHITE

	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)

	var half_w: float = field_width / 2.0
	var half_l: float = field_length / 2.0

	# Außenlinien
	draw_dynamic_line(im, -half_w, -half_l,  half_w, -half_l)
	draw_dynamic_line(im, -half_w,  half_l,  half_w,  half_l)
	draw_dynamic_line(im, -half_w, -half_l, -half_w,  half_l)
	draw_dynamic_line(im,  half_w, -half_l,  half_w,  half_l)

	# Mittellinie
	draw_dynamic_line(im, -half_w, 0.0, half_w, 0.0)

	# Strafraum oben
	draw_dynamic_line(im, -20.15, -half_l, -20.15, -half_l + 16.5)
	draw_dynamic_line(im,  20.15, -half_l,  20.15, -half_l + 16.5)
	draw_dynamic_line(im, -20.15, -half_l + 16.5, 20.15, -half_l + 16.5)

	# Strafraum unten
	draw_dynamic_line(im, -20.15, half_l - 16.5, -20.15, half_l)
	draw_dynamic_line(im,  20.15, half_l - 16.5,  20.15, half_l)
	draw_dynamic_line(im, -20.15, half_l - 16.5,  20.15, half_l - 16.5)

	# 5m-Raum oben
	draw_dynamic_line(im, -10.0, -half_l, -10.0, -half_l + 5.5)
	draw_dynamic_line(im,  10.0, -half_l,  10.0, -half_l + 5.5)
	draw_dynamic_line(im, -10.0, -half_l + 5.5, 10.0, -half_l + 5.5)

	# 5m-Raum unten
	draw_dynamic_line(im, -10.0, half_l - 5.5, -10.0, half_l)
	draw_dynamic_line(im,  10.0, half_l - 5.5,  10.0, half_l)
	draw_dynamic_line(im, -10.0, half_l - 5.5,  10.0, half_l - 5.5)

	# Mittelkreis
	var r: float = 9.15
	var steps: int = 80

	for i: int in steps:
		var a1: float = TAU * float(i) / float(steps)
		var a2: float = TAU * float(i + 1) / float(steps)

		var x1: float = sin(a1) * r
		var z1: float = cos(a1) * r
		var x2: float = sin(a2) * r
		var z2: float = cos(a2) * r

		var y1: float = terrain.get_height_at_position(x1, z1) + line_height_offset
		var y2: float = terrain.get_height_at_position(x2, z2) + line_height_offset

		im.surface_add_vertex(Vector3(x1, y1, z1))
		im.surface_add_vertex(Vector3(x2, y2, z2))

	im.surface_end()
	mesh = im
