extends Node3D

@onready var terrain := $TerrainGeneration

func _ready():
	# Tore
	var left_goal := $HockeyGoalLeft
	var right_goal := $HockeyGoalRight

	left_goal.position = Vector3(0, 0, -35)
	right_goal.position = Vector3(0, 0, 35)

	left_goal.rotation_degrees.y = 180
	right_goal.rotation_degrees.y = 0

	# 🔥 GoalDetectors direkt unter main verbinden
	var left_detector := $GoalDetectorLeft
	var right_detector := $GoalDetectorRight

	left_detector.connect("goal_scored", Callable(self, "_on_goal_scored"))
	right_detector.connect("goal_scored", Callable(self, "_on_goal_scored"))

	print("Main ready – Tore & GoalDetectors verbunden.")


func _on_goal_scored(team_name: String):
	print("TOR für: ", team_name)

	reset_ball()

	if terrain:
		await terrain.reset_field()  # wichtig: mit await!
		print("Terrain reset abgeschlossen")


func reset_ball():
	var ball := get_tree().get_first_node_in_group("ball")
	if ball == null:
		return

	ball.global_transform.origin = Vector3(0, 1, 0)

	if ball is RigidBody3D:
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
