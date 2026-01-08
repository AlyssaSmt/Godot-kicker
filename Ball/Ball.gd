extends RigidBody3D

@export var wall_kick_strength: float = 9.5
@export var wall_kick_cooldown: float = 0.08

var _kick_timer := 0.0

func _ready() -> void:
	sleeping = false
	can_sleep = false
	gravity_scale = 1.25
	mass = 0.28

	# ✅ CCD for Godot 4.0 / 4.1
	continuous_cd = true

	linear_damp = 0.0005
	angular_damp = 0.003

	# Kontakte aktivieren
	contact_monitor = true
	max_contacts_reported = 8

	# PhysicsMaterial
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.985
	mat.friction = 0.01
	physics_material_override = mat


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
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

		# Only walls
		if not collider.is_in_group("walls"):
			continue

		# Normale vom Kontaktpunkt (von Wand weg)
		var n := state.get_contact_local_normal(i)
		n.y = 0.0
		if n.length() < 0.01:
			continue

		apply_central_impulse(n.normalized() * wall_kick_strength)
		_kick_timer = wall_kick_cooldown
		break
