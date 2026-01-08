extends MeshInstance3D

const FIELD_LENGTH := 105.0
const FIELD_WIDTH := 68.0

var im: ImmediateMesh

func _ready() -> void:
	im = ImmediateMesh.new()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)

	var w := FIELD_WIDTH / 2.0
	var l := FIELD_LENGTH / 2.0

	# -----------------------
	# Outer lines
	# -----------------------
	line(Vector3(-w, 0.05, -l), Vector3(w, 0.05, -l))
	line(Vector3(w, 0.05, -l), Vector3(w, 0.05, l))
	line(Vector3(w, 0.05, l), Vector3(-w, 0.05, l))
	line(Vector3(-w, 0.05, l), Vector3(-w, 0.05, -l))

	# -----------------------
	# Center line
	# -----------------------
	line(Vector3(-w, 0.05, 0.0), Vector3(w, 0.05, 0.0))

	# -----------------------
	# Center circle
	# -----------------------
	var radius := 9.15
	var steps := 64
	for i in range(steps):
		var a := float(i) / steps * TAU
		var b := float(i + 1) / steps * TAU
		line(
			Vector3(sin(a) * radius, 0.05, cos(a) * radius),
			Vector3(sin(b) * radius, 0.05, cos(b) * radius)
		)

	# -----------------------
	# Strafraum (oben)
	# -----------------------
	var box_w := 40.3 / 2.0
	var box_l := 16.5

	line(Vector3(-box_w, 0.05, -l), Vector3(-box_w, 0.05, -l + box_l))
	line(Vector3(box_w, 0.05, -l), Vector3(box_w, 0.05, -l + box_l))
	line(Vector3(-box_w, 0.05, -l + box_l), Vector3(box_w, 0.05, -l + box_l))

	# -----------------------
	# Strafraum (unten)
	# -----------------------
	line(Vector3(-box_w, 0.05, l), Vector3(-box_w, 0.05, l - box_l))
	line(Vector3(box_w, 0.05, l), Vector3(box_w, 0.05, l - box_l))
	line(Vector3(-box_w, 0.05, l - box_l), Vector3(box_w, 0.05, l - box_l))

	im.surface_end()
	mesh = im


# ======================================================
# Helper function (NOT in _ready! -> otherwise lambda error)
# ======================================================
func line(a: Vector3, b: Vector3) -> void:
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
