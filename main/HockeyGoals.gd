@tool
class_name FootballGoal
extends Node3D

# --- FIFA-Maße ---
@export var goal_width: float = 10    # Torbreite
@export var goal_height: float = 4  # Höhe
@export var goal_depth: float = 3.00     # Tiefe

# --- Wanddicken ---
@export var post_thickness: float = 0.12     # Pfosten
@export var bar_thickness: float = 0.12      # Querlatte
@export var wall_thickness: float = 0.10     # Seiten, Dach, Rückwand


func _ready() -> void:
	if Engine.is_editor_hint():
		_clear()
	_create_goal()


func _clear():
	for c in get_children():
		c.queue_free()


# ------------------------------------------------------
# Hilfsmethode zum Erstellen einer Wand + Collider
# ------------------------------------------------------
func _create_box(size: Vector3, pos: Vector3):
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	add_child(mesh)

	# Collider
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var colbox := BoxShape3D.new()
	colbox.size = size
	shape.shape = colbox
	body.add_child(shape)
	mesh.add_child(body)


# ------------------------------------------------------
# HIER ENTSTEHT DAS GANZE TOR
# ------------------------------------------------------
func _create_goal():

	# ================================================
	# 1) LINKER PFOSTEN
	# ================================================
	_create_box(
		Vector3(post_thickness, goal_height, post_thickness),
		Vector3(-goal_width/2, goal_height/2, 0)
	)

	# ================================================
	# 2) RECHTER PFOSTEN
	# ================================================
	_create_box(
		Vector3(post_thickness, goal_height, post_thickness),
		Vector3(goal_width/2, goal_height/2, 0)
	)

	# ================================================
	# 3) QUERLATTE (vorne)
	# ================================================
	_create_box(
		Vector3(goal_width, bar_thickness, bar_thickness),
		Vector3(0, goal_height, 0)
	)

	# ================================================
	# 4) SEITENWÄNDE LINKS/RECHTS
	# ================================================
	_create_box(
		Vector3(wall_thickness, goal_height, goal_depth),
		Vector3(-goal_width/2, goal_height/2, goal_depth/2)
	)

	_create_box(
		Vector3(wall_thickness, goal_height, goal_depth),
		Vector3(goal_width/2, goal_height/2, goal_depth/2)
	)

	# ================================================
	# 5) DACH DES TORES
	# ================================================
	_create_box(
		Vector3(goal_width, wall_thickness, goal_depth),
		Vector3(0, goal_height + wall_thickness/2, goal_depth/2)
	)

	# ================================================
	# 6) RÜCKWAND (komplett geschlossen)
	# ================================================
	_create_box(
		Vector3(goal_width, goal_height, wall_thickness),
		Vector3(0, goal_height/2, goal_depth)
	)
