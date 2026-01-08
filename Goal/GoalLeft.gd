extends Node3D

var width := 7.32
var height := 2.44
var depth := 2.0
var thick := 0.12


# ----------------------------------------------------------
# HELPER FUNCTION 1: create post
# ----------------------------------------------------------
func make_post(pos: Vector3) -> MeshInstance3D:
	var post := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(thick, height, thick)
	post.mesh = box
	post.material_override = make_material()
	post.position = pos
	return post




# ----------------------------------------------------------
# HELPER FUNCTION 2: create horizontal bar
# ----------------------------------------------------------
func make_bar(pos: Vector3, length: float) -> MeshInstance3D:
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, thick, thick)
	bar.mesh = box
	bar.material_override = make_material()
	bar.position = pos
	return bar



# ----------------------------------------------------------
# GOAL CONSTRUCTION
# ----------------------------------------------------------
func create_goal(position: Vector3) -> Node3D:
	var goal := Node3D.new()
	goal.position = position

	# --- Front posts ---
	goal.add_child(make_post(Vector3(-width/2, height/2, 0)))
	goal.add_child(make_post(Vector3(width/2, height/2, 0)))

	# --- Front crossbar ---
	goal.add_child(make_bar(Vector3(0, height, 0), width))

	# --- Back posts ---
	goal.add_child(make_post(Vector3(-width/2, height/2, -depth)))
	goal.add_child(make_post(Vector3(width/2, height/2, -depth)))

	# --- Back crossbar ---
	goal.add_child(make_bar(Vector3(0, height, -depth), width))

	# --- Front bottom ---
	goal.add_child(make_bar(Vector3(0, thick/2, 0), width))

	# --- Back bottom ---
	goal.add_child(make_bar(Vector3(0, thick/2, -depth), width))

	# --- Bottom sides ---
	goal.add_child(make_bar(Vector3(-width/2, thick/2, -depth/2), thick))
	goal.add_child(make_bar(Vector3(width/2, thick/2, -depth/2), thick))

	return goal

func make_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.95, 1.0)  # slightly whitish
	m.metallic = 0.05                        # slightly metallic
	m.roughness = 0.2                        # somewhat glossy
	m.specular = 1.0                         # nice highlight sheen
	m.clearcoat = 0.3                        # additional reflection
	m.clearcoat_gloss = 0.8
	return m


# ----------------------------------------------------------
# ON START
# ----------------------------------------------------------
func _ready():
	var goal_offset := 2.0   # how far the goals should sit behind the line

	add_child(create_goal(Vector3(0, 0, -50.5 - goal_offset)))   # hinter linkem Tor
	add_child(create_goal(Vector3(0, 0,  52.5 + goal_offset)))   # hinter rechtem Tor
