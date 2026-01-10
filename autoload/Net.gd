extends Node

signal players_changed
signal lobby_started
signal start_game

var peer: ENetMultiplayerPeer
var players := {} # peer_id -> {name, team}
var host_id := -1

const MAX_PLAYERS := 4

func is_online() -> bool:
	return multiplayer.multiplayer_peer != null

func is_host() -> bool:
	return is_online() and multiplayer.is_server()

func host(port: int, my_name: String) -> int:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS)
	if err != OK: return err

	multiplayer.multiplayer_peer = peer
	players.clear()

	# host add self
	var id := multiplayer.get_unique_id()
	host_id = id
	players[id] = {"name": my_name, "team": "A"}
	emit_signal("players_changed")

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	emit_signal("lobby_started")

	# inform clients about current host id
	rpc("rpc_sync_host", host_id)
	return OK

func join(ip: String, port: int, my_name: String) -> int:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK: return err

	multiplayer.multiplayer_peer = peer

	multiplayer.connected_to_server.connect(func():
		# register on host (id 1)
		rpc_id(1, "rpc_register", multiplayer.get_unique_id(), my_name)
		emit_signal("lobby_started")
	)

	multiplayer.connection_failed.connect(func():
		# reset
		multiplayer.multiplayer_peer = null
	)

	return OK

func _on_peer_connected(id: int) -> void:
	# host only, will get name via rpc_register
	pass

func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		players.erase(id)
	emit_signal("players_changed")
	if is_host():
		rpc("rpc_sync_players", players)
		rpc("rpc_sync_host", host_id)

@rpc("any_peer", "reliable")
func rpc_register(id: int, name: String) -> void:
	if !is_host():
		return

	# ✅ Wenn der Spieler schon existiert: nur Name updaten, Team behalten
	if players.has(id):
		var old_team := str(players[id].get("team", "A"))
		players[id] = {"name": name, "team": old_team}
		emit_signal("players_changed")
		rpc("rpc_sync_players", players)
		rpc("rpc_sync_host", host_id)
		return

	# team assignment: alternate A/B (nur beim ersten Mal!)
	var count_a := 0
	var count_b := 0
	for k in players.keys():
		if str(players[k].get("team","A")) == "A":
			count_a += 1
		else:
			count_b += 1

	var team := "A" if count_a <= count_b else "B"

	players[id] = {"name": name, "team": team}
	emit_signal("players_changed")
	rpc("rpc_sync_players", players)
	rpc("rpc_sync_host", host_id)


@rpc("authority", "reliable", "call_local")
func rpc_sync_players(p: Dictionary) -> void:
	players = p
	emit_signal("players_changed")


@rpc("authority", "reliable", "call_local")
func rpc_sync_host(id: int) -> void:
	host_id = id
	emit_signal("players_changed")


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
	emit_signal("start_game")
