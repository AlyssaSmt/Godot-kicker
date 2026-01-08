@tool
class_name RinkWalls
extends Node3D

@export var field_width: float = 64.0        # inner field (like FIELD_W)
@export var field_length: float = 110.0      # inner field (like FIELD_L)
@export var wall_height: float = 10.0         # visible height above ground
@export var wall_thickness: float = 0.5
@export var corner_radius: float = 8.0       # corner rounding
@export var segments_per_corner: int = 12    # higher = rounder
@export var wall_depth_below_ground: float = 2.0  # how deep the wall extends into the terrain
@export var wall_base_height: float = 4.0

func _ready() -> void:
	# rebuild in editor and at runtime
	_clear_children()
	_create_rink()


func _clear_children() -> void:
	for child: Node in get_children():
		child.queue_free()


func _create_rink() -> void:
	var w: float = field_width / 2.0
	var l: float = field_length / 2.0

	

	# 1) Straight walls top/bottom (by the goals)
	_create_wall_segment(
		Vector3(-w + corner_radius, 0.0, -l),
		Vector3( w - corner_radius, 0.0, -l),
		90.0
	)

	_create_wall_segment(
		Vector3(-w + corner_radius, 0.0,  l),
		Vector3( w - corner_radius, 0.0,  l),
		90.0
	)

	# 2) Straight walls left/right
	_create_wall_segment(
		Vector3(-w, 0.0, -l + corner_radius),
		Vector3(-w, 0.0,  l - corner_radius)
	)

	_create_wall_segment(
		Vector3( w, 0.0, -l + corner_radius),
		Vector3( w, 0.0,  l - corner_radius)
	)

	# 3) Corners (quarter circles)
	# Top-Right (oben rechts)
	_create_corner(Vector3( w - corner_radius, 0.0, -l + corner_radius), 270.0)
	# Bottom-Right (unten rechts)
	_create_corner(Vector3( w - corner_radius, 0.0,  l - corner_radius),   0.0)
	# Bottom-Left (unten links)
	_create_corner(Vector3(-w + corner_radius, 0.0,  l - corner_radius),  90.0)
	# Top-Left (oben links)
	_create_corner(Vector3(-w + corner_radius, 0.0, -l + corner_radius), 180.0)


func _create_wall_segment(a: Vector3, b: Vector3, rotate: bool = true) -> void:
	var length: float = a.distance_to(b)

	var wall_mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(wall_thickness, wall_height, length)
	wall_mesh.mesh = box_mesh

	# Set center
	wall_mesh.position = (a + b) / 2.0
	wall_mesh.position.y = wall_base_height + wall_height / 2.0

	# Rotate only when allowed
	if rotate:
		var dir: Vector3 = (b - a).normalized()
		wall_mesh.look_at_from_position(
			wall_mesh.position,
			wall_mesh.position + dir,
			Vector3.UP
		)
	else:
		# don't rotate -> default along Z
		wall_mesh.rotation = Vector3.ZERO

	add_child(wall_mesh)

	# Physik
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var col := BoxShape3D.new()
	col.size = box_mesh.size
	shape.shape = col
	body.add_child(shape)
	wall_mesh.add_child(body)
	body.add_to_group("walls")



func _create_corner(center: Vector3, start_angle_deg: float) -> void:
	var step: float = 90.0 / float(segments_per_corner)

	for i: int in range(segments_per_corner):
		var a1: float = deg_to_rad(start_angle_deg + step * float(i))
		var a2: float = deg_to_rad(start_angle_deg + step * float(i + 1))

		var p1: Vector3 = center + Vector3(cos(a1), 0.0, sin(a1)) * corner_radius
		var p2: Vector3 = center + Vector3(cos(a2), 0.0, sin(a2)) * corner_radius

		_create_wall_segment(p1, p2)
