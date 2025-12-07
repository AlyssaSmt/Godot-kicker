extends RigidBody3D

func _ready() -> void:
	sleeping = false
	can_sleep = false
	gravity_scale = 1.0
	continuous_cd = true
	mass = 0.45

	linear_damp = 0.02       # Weniger Luftwiderstand → schneller
	angular_damp = 0.01      # Weniger Rotationsbremsung → rollt länger

	# PhysicsMaterial direkt auf dem Ball
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.55         # Leichteres Abprallen
	mat.friction = 0.05       # Wenig Haftung → viel Speed
	physics_material_override = mat



# Wenn du die Fallgeschwindigkeit begrenzen willst, mach das hier:
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if state.linear_velocity.y < -50.0:
		state.linear_velocity.y = -10.0
