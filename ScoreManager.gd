extends Node

var score_team_a: int = 0
var score_team_b: int = 0

signal score_changed(team_a: int, team_b: int)

func add_goal(team: String):
	if team == "Team A":
		score_team_a += 1
	elif team == "Team B":
		score_team_b += 1

	print("Score:", score_team_a, "-", score_team_b)

	emit_signal("score_changed", score_team_a, score_team_b)

func reset_score():
	score_team_a = 0
	score_team_b = 0
	emit_signal("score_changed", score_team_a, score_team_b)
