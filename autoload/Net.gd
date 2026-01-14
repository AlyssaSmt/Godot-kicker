extends Node

signal players_changed
signal lobby_started
signal connect_failed
signal start_game
signal server_disconnected

var peer: ENetMultiplayerPeer
var players := {} # peer_id -> {name, team}
var host_id := -1

var _join_name: String = ""
var _join_ip: String = ""
var _join_port: int = 0

var _start_game_pending: bool = false

var _is_returning_to_menu: bool = false

const MAX_PLAYERS := 4

func call_current_scene_after_frame(method_name: StringName, args: Array = []) -> void:
	# Safe helper for UI/menu scripts that might be freed during scene changes.
	# Runs after the next frame, then calls the method on the current scene if it exists.
	call_deferred("_call_current_scene_after_frame_deferred", method_name, args)

func _call_current_scene_after_frame_deferred(method_name: StringName, args: Array) -> void:
	await get_tree().process_frame
	var tree := get_tree()
	if tree == null:
		return
	var scene := tree.current_scene
	if scene and scene.has_method(method_name):
		scene.callv(method_name, args)

func is_online() -> bool:
	return multiplayer.multiplayer_peer != null

func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func leave_local() -> void:
	# Close any existing peer and reset lobby state.
	# First detach from SceneTree multiplayer to stop callbacks into a freed peer.
	multiplayer.multiplayer_peer = null

	# Avoid duplicate signal connections across reconnect attempts
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)

	if peer:
		peer.close()
	peer = null
	_join_name = ""
	_join_ip = ""
	_join_port = 0
	_start_game_pending = false
	players.clear()
	host_id = -1
	emit_signal("players_changed")

func consume_start_game_pending() -> bool:
	var v := _start_game_pending
	_start_game_pending = false
	return v

func host(port: int, my_name: String) -> int:
	leave_local()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK: return err

	multiplayer.multiplayer_peer = peer
	players.clear()

	# host add self (default to Team Blue)
	var id := multiplayer.get_unique_id()
	host_id = id
	players[id] = {"name": my_name, "team": "Blue"}
	emit_signal("players_changed")

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	emit_signal("lobby_started")

	# inform clients about current host id
	rpc("rpc_sync_host", host_id)
	print("Net.host: hosting as id=%s name=%s on port=%d" % [host_id, my_name, port])
	return OK

func join(ip: String, port: int, my_name: String) -> int:
	leave_local()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK: return err

	multiplayer.multiplayer_peer = peer
	_join_ip = ip
	_join_port = port
	_join_name = my_name

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	# If the host disappears while connected, kick client back to main menu.
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	print("Net.join: attempting to join %s:%d as %s" % [ip, port, my_name])

	return OK


func _on_connected_to_server() -> void:
	print("Net.join: connected_to_server, registering with host id=1 as name=%s" % _join_name)
	# register on host (id 1)
	rpc_id(1, "rpc_register", multiplayer.get_unique_id(), _join_name)
	emit_signal("lobby_started")


func _on_connection_failed() -> void:
	print("Net.join: connection_failed to %s:%d" % [_join_ip, _join_port])
	leave_local()
	emit_signal("connect_failed")


func _on_server_disconnected() -> void:
	print("Net: server_disconnected")
	if _is_returning_to_menu:
		return
	_is_returning_to_menu = true
	get_tree().paused = false
	leave_local()
	emit_signal("server_disconnected")
	call_deferred("_deferred_return_to_menu_scene")

func _deferred_return_to_menu_scene() -> void:
	var tree := get_tree()
	if tree == null:
		_is_returning_to_menu = false
		return
	var err2 := tree.change_scene_to_file("res://MainMenu/MultiplayerMenu.tscn")
	if err2 != OK:
		push_error("Net: Could not return to MultiplayerMenu on server disconnect: %s" % err2)
	_is_returning_to_menu = false

func _on_peer_connected(id: int) -> void:
	print("Net._on_peer_connected: peer", id)
	if players.size() > 0:
		print("Net: current players count=", players.size())

func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		players.erase(id)
	emit_signal("players_changed")
	if is_host():
		rpc("rpc_sync_players", players)
		rpc("rpc_sync_host", host_id)
	print("Net._on_peer_disconnected: peer", id, " remaining players=", players.size())

@rpc("any_peer", "reliable")
func rpc_register(id: int, name: String) -> void:
	if !is_host():
		print("Net.rpc_register: ignoring register from non-host")
		return

	print("Net.rpc_register: registering peer", id, "name=", name)
	# ✅ Wenn der Spieler schon existiert: nur Name updaten, Team behalten
	if players.has(id):
		var old_team := str(players[id].get("team", "Blue"))
		players[id] = {"name": name, "team": old_team}
		emit_signal("players_changed")
		rpc("rpc_sync_players", players)
		rpc("rpc_sync_host", host_id)
		print("Net.rpc_register: updated existing player", id, "team=", old_team)
		return

	# team assignment: alternate Blue/Red (nur beim ersten Mal!)
	var count_blue := 0
	var count_red := 0
	for k in players.keys():
		if str(players[k].get("team","Blue")) == "Blue":
			count_blue += 1
		else:
			count_red += 1

	var team := "Blue" if count_blue <= count_red else "Red"

	players[id] = {"name": name, "team": team}
	emit_signal("players_changed")
	rpc("rpc_sync_players", players)
	rpc("rpc_sync_host", host_id)
	print("Net.rpc_register: added player", id, "team=", team, "total_players=", players.size())


@rpc("authority", "reliable", "call_local")
func rpc_sync_players(p: Dictionary) -> void:
	players = p
	emit_signal("players_changed")
	print("Net.rpc_sync_players: players synced, count=", players.size())


@rpc("authority", "reliable", "call_local")
func rpc_sync_host(id: int) -> void:
	host_id = id
	emit_signal("players_changed")
	print("Net.rpc_sync_host: host_id set to", host_id)


func can_start_game() -> bool:
	return players.size() >= 2

func request_start_game() -> void:
	if !is_host():
		return
	if !can_start_game():
		return
	rpc("rpc_start_game")

@rpc("authority", "reliable", "call_local")
func rpc_start_game() -> void:
	_start_game_pending = true
	emit_signal("start_game")


func request_team_change(team: String) -> void:
	if team != "A" and team != "B":
		return

	# Wenn Host: direkt ausführen
	if is_host():
		_server_set_team(multiplayer.get_unique_id(), team)
		return

	# Wenn Client: Host fragen (id 1)
	rpc_id(1, "rpc_request_team_change", multiplayer.get_unique_id(), team)

@rpc("any_peer", "reliable")
func rpc_request_team_change(peer_id: int, team: String) -> void:
	if !is_host():
		return
	if team != "A" and team != "B":
		return

	_server_set_team(peer_id, team)

func _server_set_team(peer_id: int, team: String) -> void:
	if !players.has(peer_id):
		return

	# Optional: Team-Limit (2v2)
	var count_a := 0
	var count_b := 0
	for k in players.keys():
		var t := str(players[k].get("team", "A"))
		if t == "A": count_a += 1
		else: count_b += 1

	# Beispiel-Regel: max 2 pro Team
	if team == "A" and count_a >= 2:
		# optional: feedback an client
		return
	if team == "B" and count_b >= 2:
		return

	players[peer_id]["team"] = team

	emit_signal("players_changed")
	rpc("rpc_sync_players", players)
	rpc("rpc_sync_host", host_id)
