extends Node3D

# Offizielle Spielfeldgröße (du kannst sie ändern)
const FIELD_LENGTH := 105.0    # Z-Richtung
const GOAL_DISTANCE := 35.0    # Abstand der Hockeytore von der Mitte


func _ready():
	# Referenzen holen
	var left_goal: Node3D = $HockeyGoalLeft
	var right_goal: Node3D = $HockeyGoalRight

	# Positionen setzen
	left_goal.position = Vector3(0, 0, -GOAL_DISTANCE)
	right_goal.position = Vector3(0, 0,  GOAL_DISTANCE)

	# Drehungen korrigieren:
	# ❗ Rechtes Tor muss gedreht werden, nicht das linke!
	left_goal.rotation_degrees.y = 180      # zeigt in +Z
	right_goal.rotation_degrees.y = 0   # zeigt in -Z

	print("Tore korrekt platziert & ausgerichtet.")
