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


func _normalize_team_name(t: String) -> String:
	var s := t.strip_edges()
	var u := s.to_upper()
	if u == "TEAM BLUE" or u == "BLUE" or u == "A" or u == "TEAM A":
		return "Team Blue"
	if u == "TEAM RED" or u == "RED" or u == "B" or u == "TEAM B":
		return "Team Red"
	if s == "Team Blue" or s == "Team Red":
		return s
	return s


func _ready() -> void:
	_set_hud_visible(false)
	_pause_match(true)

	if pause_menu == null:
		push_error("❌ PauseMenu NOT found! Check path.")
		return

	# --- Multiplayer init ---
	if multiplayer.multiplayer_peer != null:
		print("MP active. is_server=", multiplayer.is_server(), " my_id=", multiplayer.get_unique_id())
		# If start_game fired while transitioning scenes (e.g., standalone menu -> game.tscn),
		# ensure the new game scene actually starts for this peer.
		if has_node("/root/Net"):
			if not Net.start_game.is_connected(_on_net_start_game):
				Net.start_game.connect(_on_net_start_game)
			if Net.has_method("consume_start_game_pending") and Net.consume_start_game_pending():
				call_deferred("on_multiplayer_menu_closed")
		# If someone disconnects during the game, everyone returns to main menu.
		multiplayer.peer_disconnected.connect(func(_id: int):
			if multiplayer.is_server():
				_server_force_return_to_menu()
		)

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
	var help_btn := $HelpUI/HelpButton
	if help_btn:
		help_btn.text = "Pause"

	# PauseMenu Signale
	pause_menu.request_reset.connect(_on_reset_requested)
	pause_menu.request_forfeit.connect(_on_forfeit_requested)
	pause_menu.request_resume.connect(_on_resume_requested)

	match_running = false

	if match_ui and match_ui.has_method("stop_match_ui"):
		match_ui.stop_match_ui()

	print("Main ready – goals connected.")


func _on_net_start_game() -> void:
	# Fallback: if for any reason the menu didn't call on_multiplayer_menu_closed,
	# starting the game should still hide the lobby UI and unpause the round.
	call_deferred("on_multiplayer_menu_closed")


func request_return_to_menu() -> void:
	# Called by UI (e.g. end screen Main Menu button). Ensures everyone leaves together.
	if multiplayer.multiplayer_peer == null:
		_go_to_main_menu_local()
		return

	if multiplayer.is_server():
		_server_force_return_to_menu()
		return

	var host := 1
	if has_node("/root/Net") and Net.host_id != -1:
		host = int(Net.host_id)
	rpc_id(host, "_rpc_request_return_to_menu")


func _go_to_main_menu_local() -> void:
	# Ensure we never carry a paused tree into the menu (can look like a gray freeze)
	get_tree().paused = false
	# Hide any in-game overlays that might still be visible
	if pause_menu and pause_menu.has_method("close_menu_silent"):
		pause_menu.close_menu_silent()
	if match_ui and match_ui.has_method("hide_end_screen"):
		match_ui.hide_end_screen()
	if match_ui and match_ui.has_method("stop_match_ui"):
		match_ui.stop_match_ui()

	if has_node("/root/Net") and Net.has_method("leave_local"):
		Net.leave_local()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var err := get_tree().change_scene_to_file("res://MainMenu/MultiplayerMenu.tscn")
	if err != OK:
		push_error("Main: Could not open MultiplayerMenu.tscn: %s" % err)


func _server_force_return_to_menu() -> void:
	# Broadcast to everyone (includes host via call_local).
	rpc("_rpc_return_to_menu")


func request_play_again() -> void:
	# Called from the end screen. Keeps same teams; resets the match for everyone.
	if multiplayer.multiplayer_peer == null:
		_do_rematch_local()
		return
	if multiplayer.is_server():
		_server_start_rematch()
		return
	var host := 1
	if has_node("/root/Net") and Net.host_id != -1:
		host = int(Net.host_id)
	rpc_id(host, "_rpc_request_rematch")


func _server_start_rematch() -> void:
	rpc("_rpc_start_rematch")


func _do_rematch_local() -> void:
	# Clear any global pause from end screen
	get_tree().paused = false
	reset_vote_a = false
	reset_vote_b = false
	if pause_menu and pause_menu.has_method("clear_votes"):
		pause_menu.clear_votes()
	if pause_menu and pause_menu.has_method("close_menu_silent"):
		pause_menu.close_menu_silent()

	# Reset score + round timer
	if has_node("ScoreManager") and $ScoreManager.has_method("reset_score"):
		$ScoreManager.reset_score()
	if match_manager and match_manager.has_method("reset_round"):
		match_manager.reset_round()

	# Reset field + ball + camera
	if terrain:
		terrain.reset_field()
	reset_ball()
	_apply_team_camera()

	# Ensure UI is in match-running state
	if match_ui and match_ui.has_method("hide_end_screen"):
		match_ui.hide_end_screen()
	if match_ui and match_ui.has_method("start_match_ui"):
		match_ui.start_match_ui()


@rpc("any_peer", "reliable")
func _rpc_request_rematch() -> void:
	if not multiplayer.is_server():
		return
	_server_start_rematch()


@rpc("authority", "reliable", "call_local")
func _rpc_start_rematch() -> void:
	_do_rematch_local()


func _input(event: InputEvent) -> void:
	# Pause hotkeys disabled — handled via UI only
	return


# -------------------------
# Goals
# -------------------------

func _on_goal_scored(team_name: String) -> void:
	# Nur der Server/Host entscheidet und führt aus
	if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
		return

	$ScoreManager.add_goal(team_name)

	# ✅ an alle replizieren (inkl. Host via call_local)
	rpc("_rpc_show_goal", team_name)
	rpc("_rpc_reset_ball")
	rpc("_rpc_reset_field")
	rpc("_rpc_reset_camera")


# -------------------------
# Pause / Help Menu
# -------------------------

func _on_help_pressed() -> void:
	# Ensure PauseMenu knows this player's team so its local button text updates correctly
	if pause_menu and has_node("/root/Net"):
		var my_id := multiplayer.get_unique_id()
		if Net.players.has(my_id):
			var tcode := str(Net.players[my_id].get("team", "A")).to_upper()
			pause_menu.team_name_local = "Team Blue" if tcode == "A" else "Team Red"

	pause_menu.set_votes(reset_vote_a, reset_vote_b)
	if multiplayer.multiplayer_peer != null:
		# If we're the host, call the request handler locally (rpc() won't execute on the caller)
		if multiplayer.is_server():
			_rpc_request_pause(true)
		else:
			rpc("_rpc_request_pause", true)
	else:
		pause_menu.open_menu()
		# ensure local camera capture is disabled while menu is open
		var cam_root := get_node_or_null("EditorCameraRoot")
		if cam_root and cam_root.has_method("set_capture_enabled"):
			cam_root.set_capture_enabled(false)


func _on_reset_requested(team_name: String, wants_reset: bool) -> void:
	# Determine local player's team reliably from Net.players (fallback to incoming team_name)
	var my_team_str := "TEAM BLUE"
	var my_id := multiplayer.get_unique_id()
	if has_node("/root/Net") and Net.players.has(my_id):
		var tcode := str(Net.players[my_id].get("team", "A")).to_upper()
		if tcode == "A":
			my_team_str = "TEAM BLUE"
		else:
			my_team_str = "TEAM RED"
	else:
		my_team_str = team_name.strip_edges().to_upper()

	if my_team_str == "TEAM BLUE":
		reset_vote_a = wants_reset
	elif my_team_str == "TEAM RED":
		reset_vote_b = wants_reset
	else:
		print("⚠️ Unknown team (reset request):", my_team_str)

	pause_menu.set_votes(reset_vote_a, reset_vote_b)

	# MP: send reset request to host with authoritative team string
	if multiplayer.multiplayer_peer != null:
		# If we're the server, call the handler directly so server-side state and broadcasts run
		if multiplayer.is_server():
			_rpc_request_reset(my_team_str, wants_reset)
			return
		# Clients ask the host via RPC
		rpc("_rpc_request_reset", my_team_str, wants_reset)
		return

	# SP fallback: if both agree, perform reset
	if reset_vote_a and reset_vote_b:
		_do_full_reset()
		_rpc_full_reset()


func _on_forfeit_requested(team_name: String) -> void:
	var t := _normalize_team_name(team_name)
	print("🏳️ Forfeit by:", t, " -> they lose!")

	reset_vote_a = false
	reset_vote_b = false
	pause_menu.clear_votes()
	# Close locally without emitting resume; the match is ending.
	if pause_menu and pause_menu.has_method("close_menu_silent"):
		pause_menu.close_menu_silent()
	else:
		pause_menu.close_menu_no_global_pause()

	if multiplayer.multiplayer_peer != null:
		# If we're the host, call the request handler locally (rpc() won't execute on the caller)
		if multiplayer.is_server():
			_rpc_request_forfeit(t)
		else:
			rpc("_rpc_request_forfeit", t)
		return

	if match_manager:
		match_manager.stop_match()
		var blue_score := 0
		var red_score := 0
		if has_node("ScoreManager"):
			blue_score = int($ScoreManager.get_left_score())
			red_score = int($ScoreManager.get_right_score())
			_rpc_show_forfeit_result(t, blue_score, red_score)
		else:
			push_warning("⚠️ MatchManager not found.")


func _on_resume_requested() -> void:
	if multiplayer.multiplayer_peer != null:
		# RPC expects no args
		if multiplayer.is_server():
			_rpc_request_resume()
		else:
			rpc("_rpc_request_resume")
	else:
		if pause_menu:
			# Singleplayer: close UI and resume match locally
			pause_menu.close_menu()
			_pause_match(false)
			var cam_root := get_node_or_null("EditorCameraRoot")
			if cam_root and cam_root.has_method("set_capture_enabled"):
				cam_root.set_capture_enabled(true)


# -------------------------
# Full Reset
# -------------------------

func _do_full_reset() -> void:
	reset_vote_a = false
	reset_vote_b = false
	pause_menu.clear_votes()

	if terrain:
		terrain.reset_field()

	reset_ball()

	# Reapply team camera pose instead of using EditorSpectator's stored start transforms
	_apply_team_camera()

	pause_menu.close_menu()


# -------------------------
# Ball Reset
# -------------------------

func reset_ball() -> void:
	var ball := get_tree().get_first_node_in_group("ball")
	if ball == null:
		push_warning("reset_ball: no node in group 'ball'")
		return

	ball.global_position = Vector3(0, 1, 0)

	if ball is RigidBody3D:
		var rb := ball as RigidBody3D
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		rb.sleeping = false


# -------------------------
# Match start hook (called when multiplayer menu closes)
# -------------------------

func on_multiplayer_menu_closed() -> void:
	# When game.tscn is loaded from the standalone menu, it includes an embedded MultiplayerMenu
	# instance by default. Ensure it's hidden/disabled once the match starts.
	var embedded_menu := get_node_or_null("MultiplayerMenu")
	if embedded_menu:
		embedded_menu.visible = false
		embedded_menu.set_process(false)
		embedded_menu.set_physics_process(false)
		embedded_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_set_hud_visible(true)

	if match_ui and match_ui.has_method("start_match_ui"):
		match_ui.start_match_ui()

	_pause_match(false)
	_apply_team_camera()

	# Do not force mouse centering or automatic capture here.
	# Players can enable camera capture manually (right-click) or via UI.
	print("Game started ✅")


func _apply_team_camera() -> void:
	var my_id := multiplayer.get_unique_id()
	var my_team := "A"
	if has_node("/root/Net") and Net.players.has(my_id):
		my_team = str(Net.players[my_id].get("team", "A")).to_upper()

	var cam_root := get_node_or_null("EditorCameraRoot")
	if cam_root == null:
		return

	if my_team == "A":
		cam_root.global_position = Vector3(0, 20, 50)
		# Root handles yaw only; rotate Blue by 180° around Y so it faces opposite direction
		cam_root.rotation_degrees = Vector3(0.0, 0.0, 0.0)
		var child_cam := cam_root.get_node_or_null("EditorCamera")
		if child_cam:
				child_cam.rotation_degrees = Vector3(-37.5, 0.0, 0.0)
		# Sync orientation on the spectator/root (updates yaw/pitch internal state)
		if cam_root.has_method("sync_orientation"):
			cam_root.sync_orientation()
	else:
		cam_root.global_position = Vector3(0, 20, -50)
		# Root yaw for Red team (face opposite of Blue)
		cam_root.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		var child_cam := cam_root.get_node_or_null("EditorCamera")
		if child_cam:
				child_cam.rotation_degrees = Vector3(-37.5, 0.0, 0.0)
		if cam_root.has_method("sync_orientation"):
			cam_root.sync_orientation()

	print("Camera set for team:", my_team)


# -------------------------
# HUD / Match start-stop helpers
# -------------------------

func _set_hud_visible(v: bool) -> void:
	if hud:
		hud.visible = v
	if timer_label:
		timer_label.visible = v
	if hud_score_label:
		hud_score_label.visible = v
	if ui_score_label:
		ui_score_label.visible = v
	if pause_button:
		pause_button.visible = v


func _pause_match(pause: bool) -> void:
	if match_manager == null:
		return
	# Also toggle the global tree paused state so physics and timers stop
	if pause:
		match_manager.stop_match()
	else:
		match_manager.start_match()


# -------------------------
# RPCs (Host authoritative)
# -------------------------

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


@rpc("any_peer", "reliable")
func _rpc_request_forfeit(team_name: String) -> void:
	if not multiplayer.is_server():
		return
	rpc("_rpc_do_forfeit", team_name)

@rpc("authority", "reliable", "call_local")
func _rpc_do_forfeit(team_name: String) -> void:
	# Stop the match locally.
	if match_manager:
		match_manager.stop_match()

	# Only the server broadcasts the per-player results.
	if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
		return

	var loser_team := _normalize_team_name(team_name)
	var blue_score := 0
	var red_score := 0
	if has_node("ScoreManager"):
		blue_score = int($ScoreManager.get_left_score())
		red_score = int($ScoreManager.get_right_score())
	rpc("_rpc_show_forfeit_result", loser_team, blue_score, red_score)


@rpc("authority", "reliable", "call_local")
func _rpc_show_forfeit_result(loser_team: String, blue_score: int, red_score: int) -> void:
	# Ensure pause/help UI is not covering the end screen.
	if pause_menu and pause_menu.has_method("close_menu_silent"):
		pause_menu.close_menu_silent()
	elif pause_menu and pause_menu.has_method("close_menu_no_global_pause"):
		pause_menu.close_menu_no_global_pause()

	# End the game like a normal round end: freeze gameplay and show "Team X wins!"
	get_tree().paused = true

	var loser := _normalize_team_name(loser_team)
	var winner_text := "Team Red wins!" if loser == "Team Blue" else "Team Blue wins!"

	var ui_node: Node = match_ui
	if ui_node == null and match_manager != null:
		ui_node = match_manager.get("ui")

	if ui_node and ui_node.has_method("show_end_screen"):
		ui_node.show_end_screen(blue_score, red_score, winner_text)


@rpc("any_peer", "reliable")
func _rpc_request_pause(open: bool) -> void:
	if not multiplayer.is_server():
		return
	rpc("_rpc_set_pause", open)

@rpc("authority", "reliable", "call_local")
func _rpc_set_pause(open: bool) -> void:
	if pause_menu == null:
		return

	var cam_root := get_node_or_null("EditorCameraRoot")
	# Ensure PauseMenu has correct local team before opening so vote button shows correctly
	if open and has_node("/root/Net") and pause_menu:
		var my_id := multiplayer.get_unique_id()
		if Net.players.has(my_id):
			var tcode := str(Net.players[my_id].get("team", "A")).to_upper()
			pause_menu.team_name_local = "Team Blue" if tcode == "A" else "Team Red"
	if open:
		# Always pause gameplay, but never globally pause the tree (host or client)
		_pause_match(true)
		if pause_menu and pause_menu.has_method("open_menu_no_global_pause"):
			pause_menu.open_menu_no_global_pause()
		# When pause opens, broadcast current votes to all clients so their UI matches server state
		if has_node("/root/Net"):
			for peer_id in Net.players.keys():
				var tcode := str(Net.players[peer_id].get("team", "A")).to_upper()
				var local_team := "Team Blue" if tcode == "A" else "Team Red"
				rpc_id(peer_id, "_rpc_set_votes_for", local_team, reset_vote_a, reset_vote_b)
			# Also update server/local UI
			var my_id := multiplayer.get_unique_id()
			var my_local_team := "Team Blue"
			if has_node("/root/Net") and Net.players.has(my_id):
				var my_tcode := str(Net.players[my_id].get("team","A")).to_upper()
				my_local_team = "Team Blue" if my_tcode == "A" else "Team Red"
			rpc_id(my_id, "_rpc_set_votes_for", my_local_team, reset_vote_a, reset_vote_b)
		if cam_root and cam_root.has_method("set_capture_enabled"):
			cam_root.set_capture_enabled(false)
	else:
		# Always unpause gameplay and close UI without toggling global pause
		if pause_menu and pause_menu.has_method("close_menu_silent"):
			pause_menu.close_menu_silent()
		elif pause_menu and pause_menu.has_method("close_menu_no_global_pause"):
			pause_menu.close_menu_no_global_pause()
		_pause_match(false)
		if cam_root and cam_root.has_method("set_capture_enabled"):
			cam_root.set_capture_enabled(true)


@rpc("any_peer", "reliable")
func _rpc_request_resume() -> void:
	if not multiplayer.is_server():
		return
	rpc("_rpc_set_pause", false)


@rpc("any_peer", "reliable")
func _rpc_request_return_to_menu() -> void:
	if not multiplayer.is_server():
		return
	_server_force_return_to_menu()


@rpc("authority", "reliable", "call_local")
func _rpc_return_to_menu() -> void:
	_go_to_main_menu_local()


@rpc("any_peer", "reliable")
func _rpc_request_reset(team_name: String, wants_reset: bool) -> void:
	if not multiplayer.is_server():
		return

	var t := team_name.strip_edges().to_upper()
	if t == "TEAM BLUE":
		reset_vote_a = wants_reset
	elif t == "TEAM RED":
		reset_vote_b = wants_reset
	else:
		print("⚠️ Unknown team in _rpc_request_reset:", team_name)

	# Send votes to each connected peer with that peer's local team string
	if has_node("/root/Net"):
		for peer_id in Net.players.keys():
			var tcode := str(Net.players[peer_id].get("team", "A")) .to_upper()
			var local_team := "Team Blue" if tcode == "A" else "Team Red"
			rpc_id(peer_id, "_rpc_set_votes_for", local_team, reset_vote_a, reset_vote_b)
		# Also ensure server/local UI is updated
		var my_id := multiplayer.get_unique_id()
		if not Net.players.has(my_id):
			var my_tcode := "A"
			var my_local_team := "Team Blue" if my_tcode == "A" else "Team Red"
			rpc_id(my_id, "_rpc_set_votes_for", my_local_team, reset_vote_a, reset_vote_b)
	else:
		rpc("_rpc_set_votes", reset_vote_a, reset_vote_b)

	if reset_vote_a and reset_vote_b:
		_do_full_reset()
		rpc("_rpc_full_reset")


@rpc("authority", "reliable", "call_local")
func _rpc_set_votes(a: bool, b: bool) -> void:
	if pause_menu:
		pause_menu.set_votes(a, b)


@rpc("authority", "reliable", "call_local")
func _rpc_set_votes_for(local_team: String, a: bool, b: bool) -> void:
	if pause_menu:
		pause_menu.team_name_local = str(local_team)
		pause_menu.set_votes(a, b)


@rpc("authority", "reliable", "call_local")
func _rpc_reset_camera() -> void:
	# Reapply the team-specific camera pose to avoid snapping to outdated start transforms
	_apply_team_camera()
