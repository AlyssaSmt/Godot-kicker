extends Area3D

signal goal_scored(team_name: String)

@export var team_name := "Team A"

func _ready():
	connect("body_entered", _on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("ball"):
		print("⚽ Tor für ", team_name)
		emit_signal("goal_scored", team_name)
