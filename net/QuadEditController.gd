extends Node
class_name QuadEditController

@export var terrain_path: NodePath
@onready var terrain := get_node(terrain_path)
@onready var turn: TurnManager = get_parent().get_node("TurnManager")

# Optional: nur 1 Edit pro Turn
var turn_action_used := false

func _ready():
	turn.turn_changed.connect(_on_turn_changed)

func _on_turn_changed(_active: int):
	turn_action_used = false

func client_try_edit_quad(quad_id: int, delta: float) -> void:
	# ✅ Wenn kein Multiplayer läuft -> direkt lokal editieren
	if multiplayer.multiplayer_peer == null:
		terrain.edit_quad(quad_id, delta)
		return

	# ✅ Wenn wir der Server/Host sind -> direkt serverseitig anwenden (kein rpc nötig)
	if multiplayer.is_server():
		_server_apply_edit(multiplayer.get_unique_id(), quad_id, delta)
		return

	# ✅ Sonst: Client -> Request an Host (peer 1)
	rpc_id(1, "_rpc_request_edit", quad_id, delta)


@rpc("any_peer", "reliable")
func _rpc_request_edit(quad_id: int, delta: float) -> void:
	if !multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	_server_apply_edit(sender, quad_id, delta)

@rpc("authority", "reliable", "call_local")
func _rpc_apply_edit(quad_id: int, delta: float) -> void:
	terrain.edit_quad(quad_id, delta)



func _server_apply_edit(sender_id: int, quad_id: int, delta: float) -> void:
	# Optional: Turn check
	if sender_id != turn.active_peer_id:
		return

	# Optional: blocked check
	if terrain.is_quad_blocked(quad_id):
		return

	terrain.edit_quad(quad_id, delta)
	_rpc_apply_edit(quad_id, delta)
	turn.server_next_turn()


