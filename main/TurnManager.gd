extends Node
class_name TurnManager

signal turn_changed(active_peer_id: int)

var active_peer_id: int = 1
var order: Array[int] = []

func is_my_turn() -> bool:
	return multiplayer.get_unique_id() == active_peer_id

func server_rebuild_order():
	if !multiplayer.is_server(): return
	order.clear()
	order.append(1) # host
	for id in multiplayer.get_peers():
		order.append(id)
	order.sort()
	active_peer_id = order[0]
	_rpc_set_turn(active_peer_id)

func server_next_turn():
	if !multiplayer.is_server(): return
	if order.is_empty():
		server_rebuild_order()
		return
	var idx := order.find(active_peer_id)
	active_peer_id = order[(idx + 1) % order.size()]
	_rpc_set_turn(active_peer_id)

@rpc("authority", "reliable", "call_local")
func _rpc_set_turn(new_active: int):
	active_peer_id = new_active
	emit_signal("turn_changed", active_peer_id)
