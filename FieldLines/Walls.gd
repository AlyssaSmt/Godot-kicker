@tool
extends Node3D

@export var terrain: TerrainGeneration
@export var wall_height := 10.0
@export var wall_thickness := 1.0
@export var goal_wall_length := 14.0   # length of wall behind the goals


func _ready():
	if terrain == null:
		push_error("Walls: terrain not assigned!")
		return

	update_wall_positions()


func update_wall_positions():
	var w = terrain.size_width 
	var l = terrain.size_depth 

	# ============================
	# NORTH WALL (oben)
	# ============================
	var north = $NorthWall
	var n_col: BoxShape3D = north.get_node("CollisionShape3D").shape
	var n_mesh: BoxMesh = north.get_node("MeshInstance3D").mesh

	var desired_length = terrain.size_width / 2.0  # half field width

	north.position = Vector3(0, wall_height/2, -(l/2 + wall_thickness/2))
	north.rotation.y = deg_to_rad(90)

	# CORRECT:
	# X = Thickness
	# Y = Height
	# Z = LENGTH (visible!)
	n_col.size = Vector3(wall_thickness, wall_height, desired_length)
	n_mesh.size = Vector3(wall_thickness, wall_height, desired_length)


	# ============================
	# SOUTH WALL (unten)
	# ============================
	var south = $SouthWall
	var s_col: BoxShape3D = south.get_node("CollisionShape3D").shape
	var s_mesh: BoxMesh = south.get_node("MeshInstance3D").mesh

	south.position = Vector3(0, wall_height/2, +(l/2 + wall_thickness/2))
	south.rotation.y = deg_to_rad(90)

	s_col.size = Vector3(wall_thickness, wall_height, desired_length)
	s_mesh.size = Vector3(wall_thickness, wall_height, desired_length)




	# ============================
	# EAST WALL (rechts)
	# ============================
	var east = $EastWall
	var e_col: BoxShape3D = east.get_node("CollisionShape3D").shape
	var e_mesh: BoxMesh = east.get_node("MeshInstance3D").mesh

	east.position = Vector3((w/2 + wall_thickness/2), wall_height/2, 0)

	e_col.size = Vector3(wall_thickness, wall_height, l)
	e_mesh.size = Vector3(wall_thickness, wall_height, l)

	# ============================
	# WEST WALL (links)
	# ============================
	var west = $WestWall
	var w_col: BoxShape3D = west.get_node("CollisionShape3D").shape
	var w_mesh: BoxMesh = west.get_node("MeshInstance3D").mesh

	west.position = Vector3(-(w/2 + wall_thickness/2), wall_height/2, 0)

	w_col.size = Vector3(wall_thickness, wall_height, l)
	w_mesh.size = Vector3(wall_thickness, wall_height, l)
