extends Node
class_name QuadEditController

@export var terrain_path: NodePath
@export var turn_manager_path: NodePath

@onready var terrain: TerrainGeneration = get_node(terrain_path)
@onready var turn_manager: Node = get_node_or_null(turn_manager_path)

# Client calls this entry point
func client_try_edit_quad(quad_id: int, delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		# Singleplayer fallback
		_apply_edit_local(quad_id, delta)
		return

	if multiplayer.is_server():
		# Host plays locally too
		_server_handle_edit(multiplayer.get_unique_id(), quad_id, delta)
	else:
		# Client sends request to server
		rpc_id(1, "rpc_request_edit_quad", quad_id, delta)


# Server receives requests
@rpc("any_peer", "reliable")
func rpc_request_edit_quad(quad_id: int, delta: float) -> void:
	if !multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	_server_handle_edit(sender_id, quad_id, delta)

func _server_handle_edit(sender_id: int, quad_id: int, delta: float) -> void:
	if terrain == null:
		return
	if !terrain.has_quad(quad_id):
		return
	if terrain.is_quad_blocked(quad_id):
		return

	if turn_manager and turn_manager.has_method("can_player_edit"):
		if !turn_manager.call("can_player_edit", sender_id):
			return

	# Host applies terrain change
	terrain.edit_quad(quad_id, delta)

	# Broadcast to all clients (including host)
	rpc("rpc_apply_edit_quad", quad_id, delta)

	if turn_manager and turn_manager.has_method("advance_turn"):
		turn_manager.call("advance_turn")


# Clients apply the change

@rpc("authority", "reliable", "call_local")
func rpc_apply_edit_quad(quad_id: int, delta: float) -> void:
	_apply_edit_local(quad_id, delta)

func _apply_edit_local(quad_id: int, delta: float) -> void:
	if terrain == null:
		return
	terrain.edit_quad(quad_id, delta)
