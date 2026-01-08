extends Control

const GAME_SCENE := "res://main/main.tscn" # <-- ggf. anpassen
const DEFAULT_IP := "127.0.0.1"
const DEFAULT_PORT := 12345
const MAX_PLAYERS := 4

@onready var host_btn: Button = $MainContainer/Menu/Buttons/HostButton
@onready var join_btn: Button = $MainContainer/Menu/Buttons/JoinButton
@onready var quit_btn: Button = $MainContainer/Menu/BottomRow/QuitButton

@onready var nick_input: LineEdit = $MainContainer/Menu/OptionNick/NickInput
@onready var skin_input: LineEdit = $MainContainer/Menu/OptionSkin/SkinInput
@onready var ip_input: LineEdit = $MainContainer/Menu/OptionIP/AddressInput
@onready var port_input: LineEdit = $MainContainer/Menu/OptionPort/PortInput

@onready var status_label: Label = $MainContainer/StatusLabel

var peer: ENetMultiplayerPeer

func _ready() -> void:
	print("MENU READY ✅")

	# Button signals per code (egal ob in .tscn verkabelt oder nicht)
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

	# Multiplayer callbacks (für JOIN wichtig)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

	# Defaults
	if ip_input.text.strip_edges() == "":
		ip_input.text = DEFAULT_IP
	if port_input.text.strip_edges() == "":
		port_input.text = str(DEFAULT_PORT)

func _on_host_pressed() -> void:
	print("HOST PRESSED ✅")
	_save_prefs()

	var port := _read_port()
	status_label.text = "Hosting on port %d..." % port

	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	print("create_server err=", err)
	if err != OK:
		status_label.text = "Host failed: %s" % err
		return

	multiplayer.multiplayer_peer = peer
	_go_to_game()

func _on_join_pressed() -> void:
	print("JOIN PRESSED ✅")
	_save_prefs()

	var ip := ip_input.text.strip_edges()
	if ip == "":
		ip = DEFAULT_IP

	var port := _read_port()
	status_label.text = "Joining %s:%d..." % [ip, port]

	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	print("create_client err=", err)
	if err != OK:
		status_label.text = "Join failed: %s" % err
		return

	multiplayer.multiplayer_peer = peer
	# Wechsel erst nach _on_connected_to_server()

func _on_connected_to_server() -> void:
	print("CONNECTED ✅")
	status_label.text = "Connected!"
	_go_to_game()

func _on_connection_failed() -> void:
	print("CONNECTION FAILED ❌")
	status_label.text = "Connection failed."

func _on_quit_pressed() -> void:
	get_tree().quit()

func _go_to_game() -> void:
	print("GO TO GAME:", GAME_SCENE)
	var err := get_tree().change_scene_to_file(GAME_SCENE)
	print("change_scene err=", err)
	if err != OK:
		status_label.text = "Game scene not found."
		push_error("Could not load: %s" % GAME_SCENE)

func _read_port() -> int:
	var s := port_input.text.strip_edges()
	if s.is_valid_int():
		var p := int(s)
		if p > 0 and p < 65536:
			return p
	return DEFAULT_PORT

func _save_prefs() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "nickname", nick_input.text.strip_edges())
	cfg.set_value("player", "skin", skin_input.text.strip_edges())
	cfg.save("user://player.cfg")
