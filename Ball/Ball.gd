extends RigidBody3D

func _ready():
	sleeping = false  # Ball schläft nie (sonst werden Tore nicht erkannt)
	can_sleep = false
	linear_damp = 0.1  # Luftwiderstand
	angular_damp = 0.05  # Rotationswiderstand
	gravity_scale = 1.0
	continuous_cd = true 
	mass = 0.45

	if linear_velocity.y < -50:
		linear_velocity.y = -10
