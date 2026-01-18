@tool
class_name FootballGoal
extends Node3D

# goal dimensions
@export var goal_width: float = 16    # Goal width
@export var goal_height: float = 8  # Height
@export var goal_depth: float = 8.5    # Depth

# wall thicknesses
@export var post_thickness: float = 0.12     # Post
@export var bar_thickness: float = 0.12      # Crossbar
@export var wall_thickness: float = 0.10     # Sides, top, back

@export var goal_color: Color = Color(1, 1, 1, 1) # Default: white
@export var goal_roughness: float = 0.6
@export var goal_metallic: float = 0.0

enum Team { BLUE, RED }

@export var team: Team = Team.BLUE



func _ready() -> void:
	if Engine.is_editor_hint():
		_clear()
	_create_goal()


func _clear():
	for c in get_children():
		c.queue_free()



# Helper to create a wall + collider

func _create_box(size: Vector3, pos: Vector3):
	var mesh := MeshInstance3D.new()

	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos

	# set material correctly
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _get_team_color()
	mat.roughness = 0.5
	mat.metallic = 0.0

	mesh.set_surface_override_material(0, mat)

	add_child(mesh)

	# Collider
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var colbox := BoxShape3D.new()
	colbox.size = size
	shape.shape = colbox
	body.add_child(shape)
	mesh.add_child(body)




# GOAL CONSTRUCTION

func _create_goal():


	# 1) left post

	_create_box(
		Vector3(post_thickness, goal_height, post_thickness),
		Vector3(-goal_width/2, goal_height/2, 0)
	)

	# 2) right post

	_create_box(
		Vector3(post_thickness, goal_height, post_thickness),
		Vector3(goal_width/2, goal_height/2, 0)
	)


	# 3) crossbar

	_create_box(
		Vector3(goal_width, bar_thickness, bar_thickness),
		Vector3(0, goal_height, 0)
	)


	# 4) walls right/left

	_create_box(
		Vector3(wall_thickness, goal_height, goal_depth),
		Vector3(-goal_width/2, goal_height/2, goal_depth/2)
	)

	_create_box(
		Vector3(wall_thickness, goal_height, goal_depth),
		Vector3(goal_width/2, goal_height/2, goal_depth/2)
	)


	# 5) top

	_create_box(
		Vector3(goal_width, wall_thickness, goal_depth),
		Vector3(0, goal_height + wall_thickness/2, goal_depth/2)
	)


	# 6) back wall

	_create_box(
		Vector3(goal_width, goal_height, wall_thickness),
		Vector3(0, goal_height/2, goal_depth)
	)


func _get_team_color() -> Color:
	match team:
		Team.BLUE:
			return Color(0.15, 0.35, 0.95)
		Team.RED:
			return Color(0.95, 0.20, 0.20)
	return Color.WHITE


