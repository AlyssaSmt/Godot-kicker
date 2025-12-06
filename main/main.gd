extends Node3D

func _ready():
	# Wenn deine Feldlänge 115 ist:
	var field_length = 105

	# Tore an korrekte Position setzen
	$GoalDetectorLeft.position = Vector3(0, 1.0, -field_length/2)
	$GoalDetectorRight.position = Vector3(0, 1.0,  field_length/2)
