extends Node3D

@onready var terrain: TerrainGeneration = $TerrainGeneration
@onready var pause_menu := get_node_or_null("HelpUI/PauseMenu")
@onready var match_manager = $MatchManager

@onready var ui_score_label := get_node_or_null("UI/ScoreLabel")
@onready var pause_button := get_node_or_null("HelpUI/HelpButton")

@onready var match_ui := get_node_or_null("UI/MatchUI")
@onready var hud := get_node_or_null("UI/MatchUI/HUD")
@onready var timer_label := get_node_or_null("UI/MatchUI/HUD/TimerLabel")
@onready var hud_score_label := get_node_or_null("UI/MatchUI/HUD/ScoreLabel")


var match_running: bool = false




var reset_vote_a: bool = false
var reset_vote_b: bool = false

func _ready() -> void:

	_set_hud_visible(false)
	_pause_match(true)

	if pause_menu == null:
		push_error("❌ PauseMenu NOT found! Check path.")
		return

	# --- Multiplayer init ---
	if multiplayer.multiplayer_peer != null:
		print("MP active. is_server=", multiplayer.is_server(), " my_id=", multiplayer.get_unique_id())

		# Host setzt Turn-Reihenfolge
		if has_node("TurnManager") and multiplayer.is_server():
			$TurnManager.server_rebuild_order()


	var left_goal := $HockeyGoalLeft
	var right_goal := $HockeyGoalRight

	left_goal.position = Vector3(0, 0, -35)
	right_goal.position = Vector3(0, 0, 35)

	left_goal.rotation_degrees.y = 180
	right_goal.rotation_degrees.y = 0

	# Connect goal detectors
	$GoalDetectorLeft.goal_scored.connect(_on_goal_scored)
	$GoalDetectorRight.goal_scored.connect(_on_goal_scored)

	# Help Button
	$HelpUI/HelpButton.pressed.connect(_on_help_pressed)

	# PauseMenu Signale
	pause_menu.request_reset.connect(_on_reset_requested)
	pause_menu.request_forfeit.connect(_on_forfeit_requested)
	
	match_running = false

	if match_ui and match_ui.has_method("stop_match_ui"):
		match_ui.stop_match_ui()


	print("Main ready – goals connected.")


func _on_goal_scored(team_name: String) -> void:
	# Nur der Server/Host entscheidet und führt aus
	if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
		return

	# Score nur auf Host ändern (dein ScoreManager syncst du später separat)
	$ScoreManager.add_goal(team_name)

	# ✅ ALLES an alle replizieren (inkl. Host via call_local)
	rpc("_rpc_show_goal", team_name)
	rpc("_rpc_reset_ball")
	rpc("_rpc_reset_field")
	rpc("_rpc_reset_camera")




# -------------------------
# Pause / Help Menu
# -------------------------

func _on_help_pressed() -> void:
	# (Optional) here you can set team_name_local:
	# pause_menu.team_name_local = "Team Blue"  # or "Team Red"

	pause_menu.set_votes(reset_vote_a, reset_vote_b)
	pause_menu.open_menu()


func _on_reset_requested(team_name: String, wants_reset: bool) -> void:
	var t := team_name.strip_edges().to_upper()

	if t == "TEAM BLUE":
		reset_vote_a = wants_reset
	elif t == "TEAM RED":
		reset_vote_b = wants_reset
	else:
		print("⚠️ Unknown team:", team_name)

	pause_menu.set_votes(reset_vote_a, reset_vote_b)

	if reset_vote_a and reset_vote_b:
		if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
			return
		_do_full_reset()
		_rpc_full_reset()



func _do_full_reset() -> void:
	reset_vote_a = false
	reset_vote_b = false
	pause_menu.clear_votes()

	# Reset field
	if terrain:
		terrain.reset_field()

	# Ball reset
	reset_ball()

	# Reset camera
	var cam := $EditorCameraRoot/EditorCamera
	if cam:
		cam.reset_camera()

	# Close menu
	pause_menu.close_menu()


func _on_forfeit_requested(team_name: String) -> void:
	var t := team_name.strip_edges().to_upper()
	print("🏳️ Forfeit by:", t, " -> they lose!")

	reset_vote_a = false
	reset_vote_b = false
	pause_menu.clear_votes()

	pause_menu.close_menu()

	if match_manager:
		match_manager.forfeit(t)
	else:
			push_warning("⚠️ MatchManager not found.")





# -------------------------
# Ball Reset
# -------------------------

func reset_ball() -> void:
	var ball := get_tree().get_first_node_in_group("ball")
	if ball == null:
		push_warning("reset_ball: no node in group 'ball'")
		return

	# ✅ Position setzen (Godot 4)
	ball.global_position = Vector3(0, 1, 0)

	# ✅ Velocity reset
	if ball is RigidBody3D:
		var rb := ball as RigidBody3D
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		rb.sleeping = false

	# ✅ wenn dein Ball auf Clients freeze=true ist: reset ist trotzdem ok (pos wird gesetzt)

@rpc("authority", "reliable", "call_local")
func _rpc_show_goal(team_name: String) -> void:
	if has_node("GoalOverlay"):
		$GoalOverlay.show_goal(team_name)

@rpc("authority", "reliable", "call_local")
func _rpc_reset_ball() -> void:
	reset_ball()

@rpc("authority", "reliable", "call_local")
func _rpc_reset_field() -> void:
	if terrain:
		terrain.reset_field()

@rpc("authority", "reliable", "call_local")
func _rpc_full_reset() -> void:
	_do_full_reset()


func _set_hud_visible(v: bool) -> void:
	# HUD Block (Timer + HUD Score)
	if hud:
		hud.visible = v

	if timer_label:
		timer_label.visible = v

	if hud_score_label:
		hud_score_label.visible = v

	# Dein extra ScoreLabel unter UI (falls du das weiterhin nutzt)
	if ui_score_label:
		ui_score_label.visible = v

	# Pause Button
	if pause_button:
		pause_button.visible = v


func _pause_match(pause: bool) -> void:
	if match_manager == null:
		return

	if pause:
		match_manager.stop_match()
	else:
		match_manager.start_match()





func on_multiplayer_menu_closed() -> void:
	_set_hud_visible(true)

	# UI freischalten
	if match_ui and match_ui.has_method("start_match_ui"):
		match_ui.start_match_ui()

	# Match nur lokal starten (Host und Client jeweils lokal)
	_pause_match(false)

	# Kamera je nach Team setzen
	_apply_team_camera()

	print("Game started ✅")


func _apply_team_camera() -> void:
	# Team vom Net-System holen
	var my_id := multiplayer.get_unique_id()
	var my_team := "A"
	if has_node("/root/Net") and Net.players.has(my_id):
		my_team = str(Net.players[my_id].get("team", "A")).to_upper()

	# Deine Kamera (EditorCameraRoot/EditorCamera) anpassen
	var cam_root := $EditorCameraRoot
	if cam_root == null:
		return

	# Du hast: Tore bei z=-35 und z=+35 -> Feld ist entlang Z
	# Team A schaut von "links" (z.B. von -Z Richtung +Z)
	# Team B schaut von "rechts" (von +Z Richtung -Z)
	if my_team == "A":
		cam_root.global_position = Vector3(0, 18, -60)
		cam_root.look_at(Vector3(0, 0, 0), Vector3.UP)
	else:
		cam_root.global_position = Vector3(0, 18, 60)
		cam_root.look_at(Vector3(0, 0, 0), Vector3.UP)

	print("Camera set for team:", my_team)


@rpc("authority", "reliable", "call_local")
func _rpc_reset_camera() -> void:
	# robust: such den Node der reset_camera hat
	var cam_root := get_node_or_null("EditorCameraRoot")
	if cam_root and cam_root.has_method("reset_camera"):
		cam_root.reset_camera()
		return

	var cam := get_node_or_null("EditorCameraRoot/EditorCamera")
	if cam and cam.has_method("reset_camera"):
		cam.reset_camera()
