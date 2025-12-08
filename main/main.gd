extends Node3D

@onready var terrain := $TerrainGeneration

func _ready():
	var left_goal := $HockeyGoalLeft
	var right_goal := $HockeyGoalRight

	left_goal.position = Vector3(0, 0, -35)
	right_goal.position = Vector3(0, 0, 35)

	left_goal.rotation_degrees.y = 180
	right_goal.rotation_degrees.y = 0

	# Goal detectors verbinden
	$GoalDetectorLeft.connect("goal_scored", Callable(self, "_on_goal_scored"))
	$GoalDetectorRight.connect("goal_scored", Callable(self, "_on_goal_scored"))

	print("Main ready – Tore verbunden.")


func _on_goal_scored(team_name: String):

	# score erhöhen
	$ScoreManager.add_goal(team_name)

	# ball resetten
	reset_ball()

	# kamera resetten
	var cam := $EditorCameraRoot/EditorCamera
	if cam:
		cam.reset_camera()

	# feld resetten
	if terrain:
		terrain.reset_field()


func reset_ball():
	var ball := get_tree().get_first_node_in_group("ball")
	if ball == null:
		return

	ball.global_transform.origin = Vector3(0, 1, 0)

	if ball is RigidBody3D:
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
