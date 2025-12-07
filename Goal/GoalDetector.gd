extends Area3D

@export var team_name := "Team A"

signal goal_scored(team_name: String)

func _ready():
	connect("body_entered", _on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("ball"):
		print("TOR für ", team_name)
		emit_signal("goal_scored", team_name)
