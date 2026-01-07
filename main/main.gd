extends Node3D

@onready var terrain: TerrainGeneration = $TerrainGeneration
@onready var pause_menu := get_node("HelpUI/PauseMenu")
@onready var match_manager: MatchManager = $MatchManager


var reset_vote_a: bool = false
var reset_vote_b: bool = false

func _ready() -> void:

	if pause_menu == null:
		push_error("❌ PauseMenu NICHT gefunden! Pfad prüfen.")
		return


	var left_goal := $HockeyGoalLeft
	var right_goal := $HockeyGoalRight

	left_goal.position = Vector3(0, 0, -35)
	right_goal.position = Vector3(0, 0, 35)

	left_goal.rotation_degrees.y = 180
	right_goal.rotation_degrees.y = 0

	# Goal detectors verbinden
	$GoalDetectorLeft.goal_scored.connect(_on_goal_scored)
	$GoalDetectorRight.goal_scored.connect(_on_goal_scored)

	# Help Button
	$HelpUI/HelpButton.pressed.connect(_on_help_pressed)

	# PauseMenu Signale
	pause_menu.request_reset.connect(_on_reset_requested)
	pause_menu.request_forfeit.connect(_on_forfeit_requested)
	

	print("Main ready – Tore verbunden.")


func _on_goal_scored(team_name: String) -> void:
	# score erhöhen
	$ScoreManager.add_goal(team_name)

	# GOAL Overlay
	$GoalOverlay.show_goal(team_name)

	# ball resetten
	reset_ball()

	# kamera resetten
	var cam := $EditorCameraRoot/EditorCamera
	if cam:
		cam.reset_camera()

	# feld resetten
	if terrain:
		terrain.reset_field()


# -------------------------
# Pause / Hilfe Menü
# -------------------------

func _on_help_pressed() -> void:
	# (Optional) hier kannst du team_name_local setzen:
	# pause_menu.team_name_local = "Team A"  # oder "Team B"

	pause_menu.set_votes(reset_vote_a, reset_vote_b)
	pause_menu.open_menu()


func _on_reset_requested(team_name: String, wants_reset: bool) -> void:
	var t := team_name.strip_edges().to_upper()

	if t == "TEAM A":
		reset_vote_a = wants_reset
	elif t == "TEAM B":
		reset_vote_b = wants_reset
	else:
		print("⚠️ Unbekanntes Team:", team_name)

	pause_menu.set_votes(reset_vote_a, reset_vote_b)

	if reset_vote_a and reset_vote_b:
		_do_full_reset()



func _do_full_reset() -> void:
	reset_vote_a = false
	reset_vote_b = false
	pause_menu.clear_votes()

	# Feld reset
	if terrain:
		terrain.reset_field()

	# Ball reset
	reset_ball()

	# Kamera reset
	var cam := $EditorCameraRoot/EditorCamera
	if cam:
		cam.reset_camera()

	# Menü schließen
	pause_menu.close_menu()


func _on_forfeit_requested(team_name: String) -> void:
	var t := team_name.strip_edges().to_upper()
	print("🏳️ Aufgabe von: ", t, " -> verliert!")

	reset_vote_a = false
	reset_vote_b = false
	pause_menu.clear_votes()

	pause_menu.close_menu()

	if match_manager:
		match_manager.forfeit(t)
	else:
		push_warning("⚠️ MatchManager nicht gefunden.")





# -------------------------
# Ball Reset
# -------------------------

func reset_ball() -> void:
	var ball := get_tree().get_first_node_in_group("ball")
	if ball == null:
		return

	ball.global_transform.origin = Vector3(0, 1, 0)

	if ball is RigidBody3D:
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
