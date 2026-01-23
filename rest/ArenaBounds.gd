@tool
extends Node3D
class_name ArenaBounds

@export var width: float = 80.0
@export var length: float = 120.0
@export var height: float = 50.0
@export var wall_thickness: float = 1.0

@export var visible_walls := false
@export var wall_material: Material

@export_flags_3d_physics var wall_collision_layer: int = 1
@export_flags_3d_physics var wall_collision_mask: int = 0

func _ready():
	_clear()
	_build()

func _clear():
	for c in get_children():
		c.queue_free()

func _build():
	# left / right
	_create_wall(
		Vector3(wall_thickness, height, length),
		Vector3(-width/2 - wall_thickness/2, height/2, 0)
	)
	_create_wall(
		Vector3(wall_thickness, height, length),
		Vector3(width/2 + wall_thickness/2, height/2, 0)
	)

	# front / back
	_create_wall(
		Vector3(width, height, wall_thickness),
		Vector3(0, height/2, -length/2 - wall_thickness/2)
	)
	_create_wall(
		Vector3(width, height, wall_thickness),
		Vector3(0, height/2, length/2 + wall_thickness/2)
	)

	# top
	_create_wall(
		Vector3(width, wall_thickness, length),
		Vector3(0, height + wall_thickness/2, 0)
	)

func _create_wall(size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = pos

	# Set collision layers/masks
	body.collision_layer = wall_collision_layer
	body.collision_mask = wall_collision_mask

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	if visible_walls:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		if wall_material:
			mesh.material_override = wall_material
		body.add_child(mesh)
