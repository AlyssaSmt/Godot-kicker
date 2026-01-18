extends Control

const GAME_SCENE := "res://main/game.tscn" # Path to the game scene

@onready var nick_input: LineEdit = $MainContainer/Menu/OptionNick/NickInput

@onready var status_label: Label = $MainContainer/StatusLabel


@onready var menu := $MainContainer/Menu
@onready var lobby := $MainContainer/Lobby

@onready var ip_input: LineEdit = $MainContainer/Menu/OptionIP/AddressInput
@onready var port_input: LineEdit = $MainContainer/Menu/OptionPort/PortInput

@onready var player_list: ItemList = $MainContainer/Lobby/PlayerList
@onready var team_a_label: Label = $MainContainer/Lobby/TeamsRow/TeamABox/TeamALabel
@onready var team_b_label: Label = $MainContainer/Lobby/TeamsRow/TeamBBox/TeamBLabel
@onready var team_a_list: ItemList = $MainContainer/Lobby/TeamsRow/TeamABox/TeamAList
@onready var team_b_list: ItemList = $MainContainer/Lobby/TeamsRow/TeamBBox/TeamBList
@onready var lobby_status: Label = $MainContainer/Lobby/LobbyStatusLabel

@onready var start_btn: Button = $MainContainer/Lobby/LobbyButtons/StartGameButton
@onready var back_btn: Button = $MainContainer/Lobby/LobbyButtons/BackButton

@onready var host_btn: Button = $MainContainer/Menu/Buttons/HostButton
@onready var join_btn: Button = $MainContainer/Menu/Buttons/JoinButton

@onready var team_a_btn: Button = $MainContainer/Lobby/TeamsRow/TeamABox/TeamAButton
@onready var team_b_btn: Button = $MainContainer/Lobby/TeamsRow/TeamBBox/TeamBButton


func _ready():
	print("Net exists:", Net)
	get_tree().paused = false
	var is_standalone_menu := (get_tree().current_scene == self)
	if is_standalone_menu:
		# Always start the main menu in a clean disconnected state.
		if Net and Net.has_method("leave_local"):
			Net.leave_local()
		# Don't keep old join fields around between sessions.
		if ip_input:
			ip_input.text = ""
		if port_input:
			port_input.text = ""
	# Reset UI state
	status_label.text = ""
	if join_btn:
		join_btn.disabled = false
	if host_btn:
		host_btn.disabled = false
	menu.visible = true
	lobby.visible = false

	start_btn.pressed.connect(_on_start_game_pressed)
	back_btn.pressed.connect(_on_back_pressed)

	team_a_btn.pressed.connect(func(): Net.request_team_change("A"))
	team_b_btn.pressed.connect(func(): Net.request_team_change("B"))

	Net.players_changed.connect(_refresh_lobby)
	Net.lobby_started.connect(_open_lobby)
	Net.connect_failed.connect(func():
		status_label.text = "JOIN failed"
		join_btn.disabled = false
		if host_btn:
			host_btn.disabled = false
	)
	Net.start_game.connect(_enter_game)
	print("MENU READY")

	_force_itemlist_visible(player_list)
	_force_itemlist_visible(team_a_list)
	_force_itemlist_visible(team_b_list)

func _on_host_pressed():
	# safe port parsing, port 12345 when input empty or invalid
	var port := 12345
	if port_input and port_input.text.strip_edges() != "":
		port = int(port_input.text)
	var name := nick_input.text.strip_edges()
	if name == "": name = "Host"

	var err = Net.host(port, name)
	if err != OK:
		status_label.text = "HOST err=%s" % err
		push_error("Net.host failed with err=%s on port %d" % [err, port])
		# re-enable buttons so user can try again
		if host_btn:
			host_btn.disabled = false
		if join_btn:
			join_btn.disabled = false
		return

	status_label.text = "Hosting on %d" % port
	_open_lobby()

func _on_join_pressed():
	join_btn.disabled = true
	if host_btn:
		host_btn.disabled = true
	status_label.text = "Joining..."

	var port := 12345
	if port_input and port_input.text.strip_edges() != "":
		port = int(port_input.text)
	var ip := ip_input.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	var name := nick_input.text.strip_edges()
	if name == "": name = "Client"

	var err = Net.join(ip, port, name)
	if err != OK:
		status_label.text = "JOIN err=%s" % err
		push_error("Net.join failed with err=%s to %s:%d" % [err, ip, port])
		join_btn.disabled = false
		if host_btn:
			host_btn.disabled = false
		return


func _on_quit_pressed() -> void:
	get_tree().quit()

func _start_game() -> void:
	# Disconnect multiplayer peer to avoid issues when returning to menu later
	multiplayer.multiplayer_peer = null

	visible = false
	set_process(false)
	set_physics_process(false)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var game := get_tree().current_scene
	# If the menu is running as the current scene, change to the game scene.
	if game == self:
		var err := get_tree().change_scene_to_file(GAME_SCENE)
		if err != OK:
			status_label.text = "Game scene not found."
			push_error("multiplayer_menu: Could not load game scene: %s" % GAME_SCENE)
			return
		# Defer notifying the newly loaded game scene from the Net autoload
		if Net and Net.has_method("call_current_scene_after_frame"):
			Net.call_current_scene_after_frame("on_multiplayer_menu_closed")
		return

	if game and game.has_method("on_multiplayer_menu_closed"):
		game.on_multiplayer_menu_closed()


func _save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "nickname", nick_input.text.strip_edges())
	cfg.save("user://player.cfg")


func _open_lobby():
	menu.visible = false
	lobby.visible = true
	_refresh_lobby()

func _refresh_lobby():
	player_list.visible = false
	player_list.clear()
	team_a_list.clear()
	team_b_list.clear()

	for id in Net.players.keys():
		var pid := int(id)
		var p: Dictionary = Net.players[id]
		var nick := str(p.get("name", "Player"))
		var team := str(p.get("team", "A")) 

		var display := nick
		if pid == int(Net.host_id):
			display += " (host)"

		var team_name := "Blue" if team == "A" else "Red"
		player_list.add_item("%s  (Team %s)" % [display, team_name])

		if team == "A":
			team_a_list.add_item(display)
		else:
			team_b_list.add_item(display)

	start_btn.disabled = !Net.is_host() or !Net.can_start_game()
	lobby_status.text = "Players: %d/4" % Net.players.size()



func _on_start_game_pressed():
	Net.request_start_game()

func _enter_game():
	visible = false
	set_process(false)
	set_physics_process(false)

	# If the menu is running as the current scene (standalone), change to the game scene.
	var root := get_tree().current_scene
	if root == self:
		var err := get_tree().change_scene_to_file(GAME_SCENE)
		if err != OK:
			status_label.text = "Game scene not found."
			push_error("multiplayer_menu: Could not load game scene: %s" % GAME_SCENE)
			return
		if Net and Net.has_method("call_current_scene_after_frame"):
			Net.call_current_scene_after_frame("on_multiplayer_menu_closed")
		return

	if root and root.has_method("on_multiplayer_menu_closed"):
		root.call_deferred("on_multiplayer_menu_closed")


func _on_back_pressed():
	# Disconnect/stop hosting when leaving the lobby/menu
	if Net and Net.has_method("leave_local"):
		Net.leave_local()

	var root := get_tree().current_scene
	if root != self:
		get_tree().paused = false
		var err := get_tree().change_scene_to_file("res://MainMenu/MultiplayerMenu.tscn")
		if err != OK:
			push_error("multiplayer_menu: Could not open MultiplayerMenu.tscn: %s" % err)
		return

	menu.visible = true
	lobby.visible = false
	# Reset UI state
	if join_btn:
		join_btn.disabled = false
	if host_btn:
		host_btn.disabled = false
	status_label.text = ""
	if ip_input:
		ip_input.text = ""
	if port_input:
		port_input.text = ""

func _force_itemlist_visible(list: ItemList) -> void:
	if list == null:
		return

	list.add_theme_color_override("font_color", Color(1,1,1))
	list.add_theme_color_override("font_selected_color", Color(1,1,1))
	list.add_theme_color_override("font_hover_color", Color(1,1,1))

	list.custom_minimum_size = Vector2(260, 90)

	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
