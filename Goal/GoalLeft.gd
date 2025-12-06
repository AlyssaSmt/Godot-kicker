extends Node3D

var width := 7.32
var height := 2.44
var depth := 2.0
var thick := 0.12


# ----------------------------------------------------------
# HILFSFUNKTION 1: Pfosten erzeugen
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
# HILFSFUNKTION 2: horizontalen Balken erzeugen
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
# TOR KONSTRUKTION
# ----------------------------------------------------------
func create_goal(position: Vector3) -> Node3D:
	var goal := Node3D.new()
	goal.position = position

	# --- Vordere Pfosten ---
	goal.add_child(make_post(Vector3(-width/2, height/2, 0)))
	goal.add_child(make_post(Vector3(width/2, height/2, 0)))

	# --- Vordere Latte ---
	goal.add_child(make_bar(Vector3(0, height, 0), width))

	# --- Hintere Pfosten ---
	goal.add_child(make_post(Vector3(-width/2, height/2, -depth)))
	goal.add_child(make_post(Vector3(width/2, height/2, -depth)))

	# --- Hintere Latte ---
	goal.add_child(make_bar(Vector3(0, height, -depth), width))

	# --- Boden vorne ---
	goal.add_child(make_bar(Vector3(0, thick/2, 0), width))

	# --- Boden hinten ---
	goal.add_child(make_bar(Vector3(0, thick/2, -depth), width))

	# --- Boden-Seiten ---
	goal.add_child(make_bar(Vector3(-width/2, thick/2, -depth/2), thick))
	goal.add_child(make_bar(Vector3(width/2, thick/2, -depth/2), thick))

	return goal

func make_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.95, 1.0)  # leicht weißlich
	m.metallic = 0.05                        # schwach metallisch
	m.roughness = 0.2                        # etwas glänzend
	m.specular = 1.0                         # schöner Highlight-Glanz
	m.clearcoat = 0.3                        # zusätzliche Reflektion
	m.clearcoat_gloss = 0.8
	return m


# ----------------------------------------------------------
# IM SPIEL STARTEN
# ----------------------------------------------------------
func _ready():
	var goal_offset := 2.0   # wie weit die Tore hinter der Linie stehen sollen

	add_child(create_goal(Vector3(0, 0, -50.5 - goal_offset)))   # hinter linkem Tor
	add_child(create_goal(Vector3(0, 0,  52.5 + goal_offset)))   # hinter rechtem Tor
