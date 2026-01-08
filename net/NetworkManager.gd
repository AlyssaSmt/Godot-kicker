extends Node
class_name NetworkManager

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)

const DEFAULT_PORT := 12345
var max_players := 4

func host_game(port: int = DEFAULT_PORT):
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_players)
	if err != OK:
		push_error("Server create failed: %s" % err)
		return

	multiplayer.multiplayer_peer = peer
	_connect_signals()

	print("Hosting on port", port)

func join_game(ip: String, port: int = DEFAULT_PORT):
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		push_error("Client create failed: %s" % err)
		return

	multiplayer.multiplayer_peer = peer
	_connect_signals()

	print("Joining ", ip, ":", port)

func _connect_signals():
	if !multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if !multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _on_peer_connected(id: int):
	print("Peer connected:", id)
	emit_signal("player_connected", id)

func _on_peer_disconnected(id: int):
	print("Peer disconnected:", id)
	emit_signal("player_disconnected", id)
