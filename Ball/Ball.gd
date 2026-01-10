extends RigidBody3D

@export var wall_kick_strength: float = 9.5
@export var wall_kick_cooldown: float = 0.08
var _kick_timer := 0.0

# --- NET SYNC ---
@export var send_rate_hz := 20.0          # 15–30 ist ok
@export var snap_pos_lerp := 22.0         # höher = schneller einrasten
@export var snap_rot_lerp := 18.0
@export var hard_snap_dist := 2.0         # wenn zu weit weg -> teleport

var _accum := 0.0
var _has_target := false
var _t_pos: Vector3
var _t_rot: Quaternion

func _ready() -> void:
	sleeping = false
	can_sleep = false
	gravity_scale = 1.25
	mass = 0.28

	continuous_cd = true

	linear_damp = 0.0005
	angular_damp = 0.003

	contact_monitor = true
	max_contacts_reported = 8

	var mat := PhysicsMaterial.new()
	mat.bounce = 0.985
	mat.friction = 0.01
	physics_material_override = mat

	# --- Networking mode: host simulates, clients follow ---
	if multiplayer.multiplayer_peer == null:
		# Singleplayer
		freeze = false
		return

	if multiplayer.is_server():
		# Host: full physics
		freeze = false
	else:
		# Client: no physics simulation, only visuals
		freeze = true
		_has_target = false
		_t_pos = global_position
		_t_rot = global_basis.get_rotation_quaternion()

func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return

	if multiplayer.is_server():
		# Host sends snapshots
		_accum += delta
		var interval: float = 1.0 / max(send_rate_hz, 1.0)
		if _accum >= interval:
			_accum = 0.0
			rpc("rpc_ball_state",
				global_position,
				global_basis.get_rotation_quaternion(),
				linear_velocity,
				angular_velocity
			)

	else:
		# Client: smooth follow
		if !_has_target:
			return

		if global_position.distance_to(_t_pos) > hard_snap_dist:
			global_position = _t_pos
			global_basis = Basis(_t_rot)
			return

		global_position = global_position.lerp(_t_pos, 1.0 - exp(-snap_pos_lerp * delta))
		var cur_q := global_basis.get_rotation_quaternion()
		var new_q := cur_q.slerp(_t_rot, 1.0 - exp(-snap_rot_lerp * delta))
		global_basis = Basis(new_q)

@rpc("authority", "unreliable", "call_local")
func rpc_ball_state(pos: Vector3, rot: Quaternion, lv: Vector3, av: Vector3) -> void:
	# Host bekommt call_local -> ignorieren
	if multiplayer.is_server():
		return

	_t_pos = pos
	_t_rot = rot
	_has_target = true

	# Optional: velocities kannst du für Effekte/Prediction nutzen.
	# Für "freeze follow" brauchen wir sie nicht zwingend.
	# linear_velocity = lv
	# angular_velocity = av

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# ✅ nur Host simuliert Kräfte & Wall-Kick
	if multiplayer.multiplayer_peer != null and !multiplayer.is_server():
		return

	# Fallgeschwindigkeit begrenzen
	if state.linear_velocity.y < -50.0:
		state.linear_velocity.y = -10.0

	# Cooldown
	_kick_timer = maxf(_kick_timer - state.step, 0.0)
	if _kick_timer > 0.0:
		return

	# Check contacts
	for i in range(state.get_contact_count()):
		var collider := state.get_contact_collider_object(i)
		if collider == null:
			continue
		if not collider.is_in_group("walls"):
			continue

		var n := state.get_contact_local_normal(i)
		n.y = 0.0
		if n.length() < 0.01:
			continue

		apply_central_impulse(n.normalized() * wall_kick_strength)
		_kick_timer = wall_kick_cooldown
		break
