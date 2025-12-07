extends Area3D

@export var team_name: String = "Team A"

signal goal_scored(team_name: String)

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	collision_layer = 1
	collision_mask = 1


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("ball"):
		print("TOR für ", team_name)
		emit_signal("goal_scored", team_name)
